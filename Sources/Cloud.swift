import CloudKit
import Combine

public final actor Cloud<A>: Publisher where A : Arch {
    public typealias Output = A
    public typealias Failure = Never
    
    public static var new: Self {
        let cloud = Self()
        Task {
            await cloud.load()
        }
        return cloud
    }
    
    public static var ephemeral: Self {
        .init()
    }
    
    public var model = A.new
    nonisolated public let pull = PassthroughSubject<Void, Never>()
    nonisolated let save = PassthroughSubject<A, Never>()
    private(set) var contracts = [Contract]()
    private var subs = Set<AnyCancellable>()
    nonisolated private let queue = DispatchQueue(label: "", qos: .userInitiated)
    
    public var notified: Bool {
        get async {
            await withUnsafeContinuation { continuation in
                var sub: AnyCancellable?
                sub = timeout(.seconds(9), scheduler: queue)
                    .sink { _ in
                        sub?.cancel()
                        continuation.resume(returning: false)
                    } receiveValue: { _ in
                        sub?.cancel()
                        continuation.resume(returning: true)
                    }
                pull.send()
            }
        }
    }
    
    private init() { }
    
    public func load() async {
        let push = PassthroughSubject<Void, Never>()
        let store = PassthroughSubject<(A, Bool), Never>()
        let remote = PassthroughSubject<A?, Never>()
        let local = PassthroughSubject<A?, Never>()
        let record = PassthroughSubject<CKRecord.ID, Never>()
        
        let prefix = "i"
        let type = "Model"
        let asset = "payload"
        
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(type + suffix)
        url.exclude()
        
        let config = CKOperation.Configuration()
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 10
        config.qualityOfService = .userInitiated
        
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
                                            .map { _ -> (A?, UInt32) in
                                                (nil, .now)
                                            })
                            .removeDuplicates {
                                $0.1 >= $1.1
                            }
                            .compactMap {
                                $0.0
                            })
            .removeDuplicates {
                $0 >= $1
            }
            .sink { model in
                Task {
                    await self.send(model: model)
                }
            }
            .store(in: &subs)
        
        pull
            .merge(with: push)
            .flatMap { _ in
                Future { promise in
                    Task {
                        guard
                            let status = try? await CKContainer.default().accountStatus(),
                            status == .available,
                            let user = try? await CKContainer.default().userRecordID()
                        else {
                            promise(.success(nil))
                            return
                        }
                        promise(.success(.init(recordName: prefix + user.recordName)))
                    }
                }
            }
            .compactMap {
                $0
            }
            .first()
            .subscribe(record)
            .store(in: &subs)
        
        record
            .combineLatest(pull)
            .map {
                ($0.0, Date())
            }
            .removeDuplicates {
                Calendar.current.dateComponents([.second], from: $0.1, to: $1.1).second! < 2
            }
            .map {
                $0.0
            }
            .sink { id in
                Task {
                    let result = await CKContainer.default().publicCloudDatabase.configuredWith(configuration: config) { base -> A? in
                        guard
                            let record = try? await base.record(for: id),
                            let asset = record[asset] as? CKAsset,
                            let fileURL = asset.fileURL,
                            let data = try? Data(contentsOf: fileURL)
                        else {
                            return nil
                        }
                        return await .prototype(data: data)
                    }
                    remote.send(result)
                }
            }
            .store(in: &subs)
        
        record
            .sink { id in
                Task {
                    await CKContainer.default().publicCloudDatabase.configuredWith(configuration: config) { base in
                        let subscription = CKQuerySubscription(
                            recordType: type,
                            predicate: .init(format: "recordID = %@", id),
                            options: [.firesOnRecordUpdate])
                        subscription.notificationInfo = .init(shouldSendContentAvailable: true)
                        
                        let old = try? await base.allSubscriptions()

                        _ = try? await base.modifySubscriptions(saving: [subscription],
                                                                deleting: old?
                                                                    .map(\.subscriptionID)
                                                                ?? [])
                    }
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
                    await CKContainer.default().publicCloudDatabase.configuredWith(configuration: config) { base in
                        let record = CKRecord(recordType: type, recordID: id)
                        record[asset] = CKAsset(fileURL: url)
                        _ = try? await base.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
                    }
                }
            }
            .store(in: &subs)
        
        local
            .merge(with: save
                            .map {
                                $0 as A?
                            })
            .combineLatest(remote
                            .compactMap {
                                $0
                            }
                            .removeDuplicates())
            .filter {
                $0.0 == nil ? true : $0.0! < $0.1
            }
            .map {
                ($1, false)
            }
            .subscribe(store)
            .store(in: &subs)
        
        remote
            .map {
                ($0, .init())
            }
            .combineLatest(local
                            .compactMap {
                                $0
                            }
                            .merge(with: save))
            .removeDuplicates {
                $0.0.1 == $1.0.1
            }
            .filter { (item: ((A?, Date),  A)) -> Bool in
                item.0.0 == nil ? true : item.0.0! < item.1
            }
            .map { _ in }
            .subscribe(push)
            .store(in: &subs)
        
        store
            .removeDuplicates {
                $0.0 >= $1.0
            }
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
                                push.send()
                            }
                        } catch { }
                    }
            }
            .store(in: &subs)
        
        remote
            .compactMap {
                $0
            }
            .removeDuplicates()
            .sink {
                guard $0.timestamp > self.model.timestamp else { return }
                self.model = $0
            }
            .store(in: &subs)
        
        if let stored = (await Task
            .detached(priority: .userInitiated) { () -> A? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return await .prototype(data: data)
            }
            .value) {
            model = stored
            local.send(stored)
        } else {
            local.send(model)
        }
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
    
    nonisolated public func receive<S>(subscriber: S) where S : Subscriber, Never == S.Failure, A == S.Input {
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
    
    private func send(model: A) async {
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

#if DEBUG
    private let suffix = ".debug.data"
#else
    private let suffix = ".data"
#endif
