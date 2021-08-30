import CloudKit
import Combine

public actor Cloud<A> where A : Arch {
    nonisolated public let archive = PassthroughSubject<A, Never>()
    nonisolated public let pull = PassthroughSubject<Void, Never>()
    
    nonisolated let save = PassthroughSubject<A, Never>()
    private var subs = Set<AnyCancellable>()
    nonisolated private let queue = DispatchQueue(label: "", qos: .utility)
    
    private var arch: A {
        didSet {
            Task {
                let arch = self.arch
                await MainActor
                    .run {
                        self.archive.send(arch)
                    }
            }
        }
    }
    
    public init(container: Container?) async {
        guard let container = container else {
            arch = .new
            return
        }
        
        let push = PassthroughSubject<Void, Never>()
        let store = PassthroughSubject<(A, Bool), Never>()
        let remote = PassthroughSubject<A?, Never>()
        let local = PassthroughSubject<A?, Never>()
        let record = PassthroughSubject<CKRecord.ID, Never>()
        let type = "Archive"
        let asset = "asset"
        
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
                                                (nil, Date().timestamp)
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
            .subscribe(archive)
            .store(in: &subs)
        
        pull
            .merge(with: push)
            .flatMap { _ in
                Future { promise in
                    Task
                        .detached(priority: .utility) {
                            guard
                                let status = try? await container.base.accountStatus(),
                                status == .available,
                                let user = try? await container.base.userRecordID()
                            else {
                                promise(.success(nil))
                                return
                            }
                            promise(.success(.init(recordName: type + user.recordName)))
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
            .sink {
                let operation = CKFetchRecordsOperation(recordIDs: [$0])
//                operation.qualityOfService = .userInteractive
//                operation.configuration.timeoutIntervalForRequest = 10
//                operation.configuration.timeoutIntervalForResource = 10
//                operation.perRecordResultBlock = { _, result in
//                    remote.send((try? result.get())
//                                    .flatMap {
//                                        $0[asset] as? CKAsset
//                                    }
//                                    .flatMap {
//                                        $0
//                                            .fileURL
//                                            .flatMap(Data.prototype(url:))
//                                    })
//                }
//                manifest.container.publicCloudDatabase.add(operation)
            }
            .store(in: &subs)
        
        record
            .sink {
                container
                    .base
                    .publicCloudDatabase
                    .fetchAllSubscriptions { subs, _ in
                        subs?
                            .forEach {
                                container.base.publicCloudDatabase.delete(withSubscriptionID: $0.subscriptionID) { _, _ in }
                            }
                    }
                
                let subscription = CKQuerySubscription(
                    recordType: type,
                    predicate: .init(format: "recordID = %@", $0),
                    options: [.firesOnRecordUpdate])
                subscription.notificationInfo = .init(shouldSendContentAvailable: true)
                container.base.publicCloudDatabase.save(subscription) { _, _ in }
            }
            .store(in: &subs)
        
        record
            .combineLatest(push)
            .map { id, _ in
                id
            }
            .sink {
                let record = CKRecord(recordType: type, recordID: $0)
                record[asset] = CKAsset(fileURL: container.url)
                let operation = CKModifyRecordsOperation(recordsToSave: [record])
                operation.qualityOfService = .userInteractive
                operation.configuration.timeoutIntervalForRequest = 15
                operation.configuration.timeoutIntervalForResource = 15
                operation.savePolicy = .allKeys
                container.base.publicCloudDatabase.add(operation)
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
        
//        store
//            .removeDuplicates {
//                $0.0 >= $1.0
//            }
//            .debounce(for: .seconds(1), scheduler: queue)
//            .sink {
//                do {
//                    try $0.0.data.write(to: manifest.url, options: .atomic)
//                    if $0.1 {
//                        push.send()
//                    }
//                } catch { }
//            }
//            .store(in: &subs)
        
        arch = await Task
            .detached(priority: .utility) {
                await Data.prototype(url: container.url)
            }
            .value
            ?? .new
        local.send(arch)
    }
    
    public var notified: Bool {
        get async {
            await withUnsafeContinuation { continuation in
                var sub: AnyCancellable?
                sub = archive
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
    
    public func persist() {
        save.send(arch)
    }
    
    public func stream() async {
        let arch = arch
        await MainActor
            .run {
                self.archive.send(arch)
            }
    }
}
