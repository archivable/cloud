import CloudKit
import Combine

public struct Memory<R> where R : Repo {
    public let archive = PassthroughSubject<R.A, Never>()
    public let save = PassthroughSubject<R.A, Never>()
    public let pull = PassthroughSubject<Void, Never>()
    private var subs = Set<AnyCancellable>()
    private let local = PassthroughSubject<R.A?, Never>()
    private let queue = DispatchQueue(label: "", qos: .utility)
    
    public init() {
        let container = CKContainer(identifier: R.container)
        let push = PassthroughSubject<Void, Never>()
        let store = PassthroughSubject<(R.A, Bool), Never>()
        let remote = PassthroughSubject<R.A?, Never>()
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
                                            .map { _ in
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
                container.accountStatus { status, _ in
                    if status == .available {
                        container.fetchUserRecordID { user, _ in
                            user.map {
                                record.send(.init(recordName: R.prefix + $0.recordName))
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
                                    $0.mutating(transform: R.A.init(data:))
                                }
                            }
                        }
                    })
                }
                container.publicCloudDatabase.add(operation)
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
                let notification = CKSubscription.NotificationInfo(alertLocalizationKey: "Avocado")
                notification.shouldSendContentAvailable = true
                subscription.notificationInfo = notification
                container.publicCloudDatabase.save(subscription) { _, _ in }
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
            .debounce(for: .seconds(2), scheduler: queue)
            .sink {
                let record = CKRecord(recordType: type, recordID: $0)
                record[asset] = CKAsset(fileURL: R.file)
                let operation = CKModifyRecordsOperation(recordsToSave: [record])
                operation.qualityOfService = .userInitiated
                operation.configuration.timeoutIntervalForRequest = 20
                operation.configuration.timeoutIntervalForResource = 20
                operation.savePolicy = .allKeys
                container.publicCloudDatabase.add(operation)
            }
            .store(in: &subs)
        
        local
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
            .combineLatest(local
                            .compactMap {
                                $0
                            }
                            .removeDuplicates())
            .filter {
                $0.0 == nil ? true : $0.0! < $0.1
            }
            .map { _, _ in }
            .subscribe(push)
            .store(in: &subs)
        
        store
            .debounce(for: .seconds(0.7), scheduler: queue)
            .removeDuplicates {
                $0.0 >= $1.0
            }
            .sink {
                do {
                    try $0.0.data.write(to: R.file, options: .atomic)
                    if $0.1 {
                        push.send()
                    }
                } catch { }
            }
            .store(in: &subs)
    }
    
    public var receipt: Future<Bool, Never> {
        let archive = self.archive
        let pull = self.pull
        let queue = self.queue
        return .init { promise in
            var sub: AnyCancellable?
            sub = archive
                    .map { _ in }
                    .timeout(.seconds(15), scheduler: queue)
                    .sink { _ in
                        sub?.cancel()
                        promise(.success(false))
                    } receiveValue: {
                        sub?.cancel()
                        promise(.success(true))
                    }
            pull.send()
        }
    }
    
    public func load() {
        local.send(try? Data(contentsOf: R.file)
                            .mutating(transform: R.A.init(data:)))
    }
}
