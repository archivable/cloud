import CloudKit
import Combine

private let Prefix = "i"
private let Type = "Model"
private let Asset = "payload"

#if DEBUG
private let Suffix = ".debug.data"
#else
private let Suffix = ".data"
#endif

public final actor Cloud<Output>: Publisher where Output : Arch {
    public typealias Failure = Never
    
    public static func new(identifier: String) -> Self {
        let cloud = Self()
        Task {
            await cloud.load(identifier)
        }
        return cloud
    }
    
    public static var ephemeral: Self {
        .init()
    }
    
    public var model = Output()
    nonisolated public let ready = DispatchGroup()
    nonisolated public let pull = PassthroughSubject<Void, Failure>()
    private(set) var contracts = [Contract]()
    private var subs = Set<AnyCancellable>()
    nonisolated let save = PassthroughSubject<Output, Failure>()
    nonisolated let push = PassthroughSubject<Void, Failure>()
    nonisolated let store = PassthroughSubject<(Output, Bool), Failure>()
    nonisolated let remote = PassthroughSubject<Output?, Failure>()
    nonisolated let local = PassthroughSubject<Output?, Failure>()
    nonisolated let record = PassthroughSubject<CKRecord.ID, Failure>()
    nonisolated private let queue = DispatchQueue(label: "", qos: .userInitiated)
    
    public var notified: Bool {
        get async {
            await withUnsafeContinuation { continuation in
                var sub: AnyCancellable?
                sub = dropFirst()
                    .first()
                    .timeout(.seconds(13), scheduler: queue)
                    .sink { _ in
                        sub?.cancel()
                        continuation
                            .resume(returning: false)
                    } receiveValue: { _ in
                        sub?.cancel()
                        continuation
                            .resume(returning: true)
                    }
                pull.send()
            }
        }
    }
    
    private init() {
        ready.enter()
    }
    
    private func load(_ identifier: String) async {
        let container = CKContainer(identifier: identifier)
        let database = container.publicCloudDatabase
        
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(Type + Suffix)
        url.exclude()
        
        let config = CKOperation.Configuration()
        config.timeoutIntervalForRequest = 13
        config.timeoutIntervalForResource = 13
        config.qualityOfService = .userInitiated
        
        record
            .sink { id in
                Task {
                    await database.configuredWith(configuration: config) { base in
                        let subscription = CKQuerySubscription(
                            recordType: Type,
                            predicate: .init(format: "recordID = %@", id),
                            options: [.firesOnRecordUpdate])
                        subscription.notificationInfo = .init(shouldSendContentAvailable: true)

                        _ = try? await base.save(subscription)
                    }
                }
            }
            .store(in: &subs)
        
        pull
            .merge(with: push)
            .flatMap { _ in
                Future { promise in
                    Task {
                        guard
                            let status = try? await container.accountStatus(),
                            status == .available,
                            let user = try? await container.userRecordID()
                        else {
                            promise(.success(nil))
                            return
                        }
                        promise(.success(.init(recordName: Prefix + user.recordName)))
                    }
                }
            }
            .compactMap {
                $0
            }
            .first()
            .subscribe(record)
            .store(in: &subs)
        
        save
            .map {
                ($0, true)
            }
            .subscribe(store)
            .store(in: &subs)
        
        local
            .compactMap {
                $0
            }
            .merge(with: remote
                    .compactMap {
                $0
            }
                    .map {
                ($0, $0.timestamp)
            }
                    .merge(with: save
                            .map { _ -> (Output?, UInt32) in
                (nil, .now)
            })
                    .removeDuplicates {
                $0.1 >= $1.1
            }
                    .compactMap {
                $0.0
            })
            .removeDuplicates {
                $0.timestamp >= $1.timestamp
            }
            .sink { model in
                Task {
                    await self.send(model: model)
                }
            }
            .store(in: &subs)
        
        record
            .combineLatest(pull)
            .map {
                ($0.0, Date())
            }
            .removeDuplicates {
                Calendar.current.dateComponents([.second], from: $0.1, to: $1.1).second! < 1
            }
            .map {
                $0.0
            }
            .sink { id in
                Task {
                    let result = await database.configuredWith(configuration: config) { base -> Output? in
                        guard
                            let record = try? await base.record(for: id),
                            let asset = record[Asset] as? CKAsset,
                            let fileURL = asset.fileURL,
                            let data = try? Data(contentsOf: fileURL)
                        else {
                            return nil
                        }
                        return await .prototype(data: data)
                    }
                    self.remote.send(result)
                }
            }
            .store(in: &subs)
        
        record
            .combineLatest(push)
            .map { id, _ in
                id
            }
            .sink { id in
                Task {
                    await database.configuredWith(configuration: config) { base in
                        let record = CKRecord(recordType: Type, recordID: id)
                        record[Asset] = CKAsset(fileURL: url)
                        _ = try? await base.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
                    }
                }
            }
            .store(in: &subs)
        
        local
            .merge(with: save
                    .map {
                $0 as Output?
            })
            .combineLatest(remote
                            .compactMap {
                $0
            }
                            .removeDuplicates {
                $0.timestamp <= $1.timestamp
            })
            .filter {
                $0.0 == nil ? true : $0.0!.timestamp < $0.1.timestamp
            }
            .map {
                ($1, false)
            }
            .subscribe(store)
            .store(in: &subs)
        
        remote
            .map {
                ($0, .now)
            }
            .combineLatest(local
                            .compactMap {
                $0
            }
                            .merge(with: save))
            .removeDuplicates {
                $0.0.1 == $1.0.1
            }
            .filter { (item: ((Output?, Date),  Output)) -> Bool in
                item.0.0 == nil ? true : item.0.0!.timestamp < item.1.timestamp
            }
            .map { _ in }
            .subscribe(push)
            .store(in: &subs)
        
        store
            .debounce(for: .milliseconds(500), scheduler: queue)
            .sink { storing in
                Task
                    .detached(priority: .userInitiated) {
                        let data = await storing
                            .0
                            .compressed
                        do {
                            try data.write(to: url, options: .atomic)
                            if storing.1 {
                                self.push.send()
                            }
                        } catch { }
                    }
            }
            .store(in: &subs)
        
        remote
            .compactMap {
                $0
            }
            .removeDuplicates {
                $0.timestamp <= $1.timestamp
            }
            .sink {
                guard $0.timestamp > self.model.timestamp else { return }
                self.model = $0
            }
            .store(in: &subs)
        
        if let data = try? Data(contentsOf: url) {
            model = await .prototype(data: data)
            local.send(model)
        } else {
            local.send(model)
        }
        
        ready.leave()
    }
    
    public func stream() async {
        model.timestamp = .now
        
        contracts = contracts
            .filter {
                $0.sub?.subscriber != nil
            }
        
        await send(model: model)
        
        save.send(model)
    }
    
    nonisolated public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
        let sub = Sub(subscriber: .init(subscriber))
        subscriber.receive(subscription: sub)
        
        Task {
            await store(contract: .init(sub: sub))
        }
    }
    
    private func store(contract: Contract) async {
        contracts.append(contract)
        let initial = model
        await MainActor
            .run {
                _ = contract.sub?.subscriber?.receive(initial)
            }
    }
    
    private func send(model: Output) async {
        let subscribers = contracts.compactMap(\.sub?.subscriber)
        await MainActor
            .run {
                subscribers
                    .forEach {
                        _ = $0.receive(model)
                    }
            }
    }
}
