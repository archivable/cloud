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
            await cloud.load(container: CKContainer(identifier: identifier))
        }
        return cloud
    }
    
    public var model = Output()
    nonisolated public let ready = DispatchGroup()
    nonisolated public let pull = PassthroughSubject<Void, Failure>()
    private(set) var contracts = [Contract]()
    private var subs = Set<AnyCancellable>()
    nonisolated let url: URL
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
    
    init() {
        ready.enter()
        url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(Type + Suffix)
    }
    
    deinit {
        Swift.print("cloud gone")
    }
    
    func load(container: CloudContainer) async {
        
        url.exclude()
        
        let config = CKOperation.Configuration()
        config.timeoutIntervalForRequest = 13
        config.timeoutIntervalForResource = 13
        config.qualityOfService = .userInitiated
        
        record
            .sink { id in
                Task {
                    await container.database.configured(with: config) { base in
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
            .sink { [weak self] in
                self?.record.send($0)
            }
            .store(in: &subs)
        
        save
            .map {
                ($0, true)
            }
            .sink { [weak self] in
                self?.store.send($0)
            }
            .store(in: &subs)
        
        local.compactMap { $0 }
            .merge(with: remote.compactMap { $0 } )
        
            .flatMap { [weak self] received in
                Future { promise in
                    Task { [weak self] in
                        guard
                            let current = await self?.model.timestamp,
                            received.timestamp > current
                        else {
                            promise(.success(nil))
                            return
                        }
                        promise(.success(received))
                    }
                }
            }
            .compactMap {
                $0
            }
            .sink { [weak self] (model: Output) in
                Task { [weak self] in
                    await self?.upate(model: model)
                    await self?.publish(model: model)
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
            .sink { [weak self] id in
                Task { [weak self] in
                    let result = await container.database.configured(with: config) { base -> Output? in
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
                    self?.remote.send(result)
                }
            }
            .store(in: &subs)
        
        record
            .combineLatest(push)
            .map { id, _ in
                id
            }
            .sink { [weak self] id in
                Task { [weak self] in
                    await container.database.configured(with: config) { base in
                        let record = CKRecord(recordType: Type, recordID: id)
                        record[Asset] = CKAsset(fileURL: self!.url)
                        _ = try? await base.modifyRecords(saving: [record],
                                                          deleting: [],
                                                          savePolicy: .allKeys,
                                                          atomically: true)
                    }
                }
            }
            .store(in: &subs)
        
        local
            .merge(with: save.map { $0 as Output? })
            .combineLatest(remote.compactMap { $0 })
            .filter {
                $0.0 == nil ? true : $0.0!.timestamp < $0.1.timestamp
            }
            .map {
                ($1, false)
            }
            .sink { [weak self] in
                self?.store.send($0)
            }
            .store(in: &subs)
        
        remote
            .map {
                ($0, .now)
            }
            .combineLatest(local.compactMap { $0 }
                            .merge(with: save))
            .removeDuplicates {
                $0.0.1 == $1.0.1
            }
            .filter { (item: ((Output?, Date),  Output)) -> Bool in
                item.0.0 == nil ? true : item.0.0!.timestamp < item.1.timestamp
            }
            .map { _ in }
            .sink { [weak self] in
                self?.push.send()
            }
            .store(in: &subs)
        
        store
            .debounce(for: .milliseconds(500), scheduler: queue)
            .sink { [weak self] storing in
                Task
                    .detached(priority: .userInitiated) { [weak self] in
                        let data = await storing
                            .0
                            .compressed
                        do {
                            try data.write(to: self!.url, options: .atomic)
                            if storing.1 {
                                self?.push.send()
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
            .sink { [weak self] model in
                Task { [weak self] in
                    guard
                        let current = await self?.model.timestamp,
                        model.timestamp > current
                    else { return }
                    await self?.upate(model: model)
                }
            }
            .store(in: &subs)
        
        if let data = try? Data(contentsOf: url) {
            upate(model: await .prototype(data: data))
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
        
        await publish(model: model)
        
        save.send(model)
    }
    
    nonisolated public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
        let sub = Sub(subscriber: .init(subscriber))
        subscriber.receive(subscription: sub)
        
        Task {
            await store(contract: .init(sub: sub))
        }
    }
    
    func upate(model: Output) {
        self.model = model
    }
    
    private func store(contract: Contract) async {
        contracts.append(contract)
        let initial = model
        await MainActor
            .run {
                _ = contract.sub?.subscriber?.receive(initial)
            }
    }
    
    private func publish(model: Output) async {
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
