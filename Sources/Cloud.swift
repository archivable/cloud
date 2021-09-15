import CloudKit
import Combine

public final actor Cloud<A> where A : Arch {
    public static var new: Self {
        let cloud = Self()
        Task
            .detached(priority: .userInitiated) {
                await cloud.load()
            }
        return cloud
    }
    
    public static var emphemeral: Self {
        .init()
    }
    
    public var _archive = A.new
    
    nonisolated public var archive: AnyPublisher<A, Never> {
        publish.eraseToAnyPublisher()
    }
    
    nonisolated public let pull = PassthroughSubject<Void, Never>()
    nonisolated let save = PassthroughSubject<A, Never>()    
    private var subs = Set<AnyCancellable>()
    nonisolated private let queue = DispatchQueue(label: "", qos: .userInitiated)
    nonisolated private let publish = CurrentValueSubject<A, Never>(.new)
    
    public var notified: Bool {
        get async {
            await withUnsafeContinuation { continuation in
                var sub: AnyCancellable?
                sub = publish
                    .timeout(.seconds(9), scheduler: queue)
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
            .receive(on: DispatchQueue.main)
            .subscribe(publish)
            .store(in: &subs)
        
        pull
            .merge(with: push)
            .flatMap { _ in
                Future { promise in
                    Task
                        .detached(priority: .userInitiated) {
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
                Task
                    .detached(priority: .userInitiated) {
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
                Task
                    .detached(priority: .userInitiated) {
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
                Task
                    .detached(priority: .userInitiated) {
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
                guard $0.timestamp > self._archive.timestamp else { return }
                self._archive = $0
            }
            .store(in: &subs)
        
        await Task
            .detached(priority: .userInitiated) { () -> A? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return await .prototype(data: data)
            }
            .value
            .map {
                _archive = $0
                local.send($0)
            }
    }
    
    public func stream() async {
        _archive.timestamp = .now
        
        let arch = _archive
        
        await MainActor
            .run {
                publish.send(arch)
            }
        
        save.send(arch)
    }
}

#if DEBUG
    private let suffix = ".debug.data"
#else
    private let suffix = ".data"
#endif
