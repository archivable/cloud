import CloudKit
import Combine

public struct Cloud<A> where A : Archived {
    public let archive = CurrentValueSubject<A, Never>(.new)
    public let pull = PassthroughSubject<Void, Never>()
    let save = PassthroughSubject<A, Never>()
    private var subs = Set<AnyCancellable>()
    private let local = PassthroughSubject<A?, Never>()
    private let queue = DispatchQueue(label: "", qos: .utility)
    
    public init(manifest: Manifest?) {
        save
            .subscribe(archive)
            .store(in: &subs)
        
        guard let manifest = manifest else { return }
        
        let push = PassthroughSubject<Void, Never>()
        let store = PassthroughSubject<(A, Bool), Never>()
        let remote = PassthroughSubject<A?, Never>()
        let record = CurrentValueSubject<CKRecord.ID?, Never>(nil)
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
                                ($0, $0.date)
                            }
                            .merge(with: save
                                            .map { _ -> (A?, Date) in
                                                (nil, .init())
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
                                record.send(.init(recordName: manifest.prefix + $0.recordName))
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
                operation.qualityOfService = .userInitiated
                operation.configuration.timeoutIntervalForRequest = 20
                operation.configuration.timeoutIntervalForResource = 20
                operation.fetchRecordsCompletionBlock = { records, _ in
                    remote.send(records?.values.first.flatMap {
                        ($0[asset] as? CKAsset).flatMap {
                            $0.fileURL.flatMap {
                                (try? Data(contentsOf: $0)).map {
                                    $0.prototype()
                                }
                            }
                        }
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
                let subscription = CKQuerySubscription(
                    recordType: type,
                    predicate: .init(format: "recordID = %@", $0),
                    options: [.firesOnRecordUpdate])
                let notification = CKSubscription.NotificationInfo(alertLocalizationKey: manifest.title)
                notification.shouldSendContentAvailable = true
                subscription.notificationInfo = notification
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
                operation.qualityOfService = .userInitiated
                operation.configuration.timeoutIntervalForRequest = 20
                operation.configuration.timeoutIntervalForResource = 20
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
            .filter { (item: ((A?, Date),  A)) -> Bool in
                item.0.0 == nil ? true : item.0.0! < item.1
            }
            .map { (remote: (A?, Date), _: A) -> Date in
                remote.1
            }
            .removeDuplicates()
            .map { _ in }
            .subscribe(push)
            .store(in: &subs)
        
        store
            .debounce(for: .seconds(1), scheduler: queue)
            .removeDuplicates {
                $0.0 >= $1.0
            }
            .sink {
                do {
                    try $0.0.data.write(to: manifest.url, options: .atomic)
                    if $0.1 {
                        push.send()
                    }
                } catch { }
            }
            .store(in: &subs)
        
        local.send(try? Data(contentsOf: manifest.url)
                    .prototype())
    }
    
    
    public func mutating(transform: @escaping (inout A) -> Void) {
        mutating(transform: transform) { }
    }
    
    public func mutating<T>(transform: @escaping (inout A) -> T?, completion: @escaping (T) -> Void) {
        DispatchQueue.main.async {
            let current = self.archive.value
            var archive = current
            let result = transform(&archive)
            if archive != current {
                archive.date = .init()
                save.send(archive)
            }
            result.map(completion)
        }
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
}
