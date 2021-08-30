import CloudKit
import Combine

public struct Cloud<A> where A : Archived {
    public let archive = CurrentValueSubject<A, Never>(.new)
    public let pull = PassthroughSubject<Void, Never>()
    let save = PassthroughSubject<A, Never>()
    private var subs = Set<AnyCancellable>()
    private let queue = DispatchQueue(label: "", qos: .utility)
    
    public init(manifest: Container?) {
        save
            .subscribe(archive)
            .store(in: &subs)
        
        guard let manifest = manifest else { return }
        
        let push = PassthroughSubject<Void, Never>()
        let store = PassthroughSubject<(A, Bool), Never>()
        let remote = PassthroughSubject<A?, Never>()
        let record = CurrentValueSubject<CKRecord.ID?, Never>(nil)
        let local = PassthroughSubject<A?, Never>()
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
            .combineLatest(record)
            .filter {
                $1 == nil
            }
            .map { _, _ in }
            .sink {
                manifest.container.accountStatus { status, _ in
                    if status == .available {
                        manifest.container.fetchUserRecordID { user, _ in
                            user.map {
                                record.send(.init(recordName: type + $0.recordName))
                            }
                        }
                    }
                }
            }
            .store(in: &subs)
        
        record
            .compactMap {
                $0
            }
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
                operation.qualityOfService = .userInteractive
                operation.configuration.timeoutIntervalForRequest = 10
                operation.configuration.timeoutIntervalForResource = 10
                operation.perRecordResultBlock = { _, result in
                    remote.send((try? result.get())
                                    .flatMap {
                                        $0[asset] as? CKAsset
                                    }
                                    .flatMap {
                                        $0
                                            .fileURL
                                            .flatMap(Data.prototype(url:))
                                    })
                }
                manifest.container.publicCloudDatabase.add(operation)
            }
            .store(in: &subs)
        
        record
            .compactMap {
                $0
            }
            .sink {
                manifest
                    .container
                    .publicCloudDatabase
                    .fetchAllSubscriptions { subs, _ in
                        subs?
                            .forEach {
                                manifest.container.publicCloudDatabase.delete(withSubscriptionID: $0.subscriptionID) { _, _ in }
                            }
                    }
                
                let subscription = CKQuerySubscription(
                    recordType: type,
                    predicate: .init(format: "recordID = %@", $0),
                    options: [.firesOnRecordUpdate])
                subscription.notificationInfo = .init(shouldSendContentAvailable: true)
                manifest.container.publicCloudDatabase.save(subscription) { _, _ in }
            }
            .store(in: &subs)
        
        record
            .compactMap {
                $0
            }
            .combineLatest(push)
            .map { id, _ in
                id
            }
            .sink {
                let record = CKRecord(recordType: type, recordID: $0)
                record[asset] = CKAsset(fileURL: manifest.url)
                let operation = CKModifyRecordsOperation(recordsToSave: [record])
                operation.qualityOfService = .userInteractive
                operation.configuration.timeoutIntervalForRequest = 15
                operation.configuration.timeoutIntervalForResource = 15
                operation.savePolicy = .allKeys
                manifest.container.publicCloudDatabase.add(operation)
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
            .debounce(for: .seconds(1), scheduler: queue)
            .sink {
                do {
                    try $0.0.data.write(to: manifest.url, options: .atomic)
                    if $0.1 {
                        push.send()
                    }
                } catch { }
            }
            .store(in: &subs)
        
        Task.detached(priority: .utility) {
            local.send(Data.prototype(url: manifest.url))
        }
    }
    
    public func mutating(transform: @escaping (inout A) -> Void) {
        mutating(save: true, transform: transform) { }
    }
    
    public func mutating<T>(transform: @escaping (inout A) -> T?, completion: @escaping (T) -> Void) {
        mutating(save: true, transform: transform, completion: completion)
    }
    
    public func mutating(transform: @escaping (inout A) -> Void, completion: @escaping () -> Void) {
        mutating(save: true, transform: transform, completion: completion)
    }
    
    public func ephemeral(transform: @escaping (inout A) -> Void) {
        mutating(save: false, transform: transform) { }
    }
    
    public func ephemeral<T>(transform: @escaping (inout A) -> T?, completion: @escaping (T) -> Void) {
        mutating(save: false, transform: transform, completion: completion)
    }
    
    public func receipt(completion: @escaping (Bool) -> Void) {
        var sub: AnyCancellable?
        sub = archive
            .dropFirst()
            .map { _ in }
            .timeout(.seconds(6), scheduler: queue)
            .sink { _ in
                sub?.cancel()
                completion(false)
            } receiveValue: {
                sub?.cancel()
                completion(true)
            }
        pull.send()
    }
    
    public func transform<T>(transforming: @escaping (A) -> T?, completion: @escaping (T) -> Void) {
        DispatchQueue
            .main
            .async {
                let archive = self.archive.value
                queue
                    .async {
                        let result = transforming(archive)
                        DispatchQueue
                            .main
                            .async {
                                result.map(completion)
                            }
                    }
            }
    }
    
    private func mutating<T>(save: Bool, transform: @escaping (inout A) -> T?, completion: @escaping (T) -> Void) {
        DispatchQueue.main.async {
            let current = self.archive.value
            var archive = current
            let result = transform(&archive)
            if archive != current {
                if save {
                    archive.timestamp = Date().timestamp
                    self.save.send(archive)
                } else {
                    self.archive.send(archive)
                }
            }
            result.map(completion)
        }
    }
}
