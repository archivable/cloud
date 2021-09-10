import CloudKit
import Combine

public final actor Cloud<A> where A : Arch {
    public var arch = A.new
    nonisolated public let archive = PassthroughSubject<A, Never>()
    nonisolated public let pull = PassthroughSubject<Void, Never>()
    
    nonisolated let save = PassthroughSubject<A, Never>()    
    private var subs = Set<AnyCancellable>()
    nonisolated private let queue = DispatchQueue(label: "", qos: .utility)
    
    public init() {  }
    
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
    
    public func load(container: Container) async {
        let push = PassthroughSubject<Void, Never>()
        let store = PassthroughSubject<(A, Bool), Never>()
        let remote = PassthroughSubject<A?, Never>()
        let local = PassthroughSubject<A?, Never>()
        let record = PassthroughSubject<CKRecord.ID, Never>()
        let type = "Model"
        let asset = "archive"
        
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
            .sink { id in
                Task
                    .detached(priority: .utility) {
                        let result = await container.base.publicCloudDatabase.configuredWith(configuration: container.configuration) { base -> A? in
                            guard
                                let record = try? await base.record(for: id),
                                let asset = record[asset] as? CKAsset,
                                let url = asset.fileURL,
                                let data = try? Data(contentsOf: url)
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
                    .detached(priority: .utility) {
                        await container.base.publicCloudDatabase.configuredWith(configuration: container.configuration) { base in
//                            let old = try? await base.allSu§bscriptions()

                            let subscription = CKQuerySubscription(
                                recordType: type,
                                predicate: .init(format: "recordID = %@", id),
                                options: [.firesOnRecordUpdate])
                            subscription.notificationInfo = .init(shouldSendContentAvailable: true)
//
//                            _ = try? await base.modifySubscriptions(saving: [subscription],
//                                                                    deleting: old?
//                                                                        .map(\.subscriptionID)
//                                                                    ?? [])
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
                    .detached(priority: .utility) {
                        await container.base.publicCloudDatabase.configuredWith(configuration: container.configuration) { base in
                            let record = CKRecord(recordType: type, recordID: id)
                            record[asset] = CKAsset(fileURL: container.url)
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
                    .detached(priority: .utility) {
                        let data = await storing
                            .0
                            .compressed
                        do {
                            try data.write(to: container.url, options: .atomic)
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
                guard $0.timestamp > self.arch.timestamp else { return }
                self.arch = $0
            }
            .store(in: &subs)
        
        arch = await Task
            .detached(priority: .utility) {
                guard let data = try? Data(contentsOf: container.url) else { return nil }
                return await .prototype(data: data)
            }
            .value
            ?? .new
        
        local.send(arch)
    }
    
    public func stream() async {
        arch.timestamp = .now
        
        let arch = arch
        
        await MainActor
            .run {
                self.archive.send(arch)
            }
        
        save.send(arch)
    }
}
