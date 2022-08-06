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

public final actor Cloud<Output, Container>: Publisher where Output : Arch, Container : CloudContainer {
    public typealias Failure = Never
    
    public static func new(identifier: String) -> Self {
        let cloud = Self()
        Task {
            await cloud.load(container: Container(identifier: identifier))
        }
        return cloud
    }
    
    public var model = Output()
    nonisolated public let ready = DispatchGroup()
    nonisolated public let pull = PassthroughSubject<Void, Failure>()
    private(set) var contracts = [Contract]()
    private var loaded = false
    private var subs = Set<AnyCancellable>()
    nonisolated let url: URL
    nonisolated let push = PassthroughSubject<Void, Failure>()
    nonisolated let remote = PassthroughSubject<Wrapper<Output>?, Failure>()
    nonisolated let store = PassthroughSubject<(Output, Bool), Failure>()
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
    
    func load(container: Container) async {
        Task.detached { [url] in
            var url = url.deletingLastPathComponent()
            var resources = URLResourceValues()
            resources.isExcludedFromBackup = true
            try? url.setResourceValues(resources)
        }
        
        login(container: container)
        synch()
        
        if let data = try? Data(contentsOf: url) {
            let output = await Wrapper<Output>(data: data).archive
            update(model: output)
            await publish(model: output)
        }
        
        pull.send()
    }
    
    public func stream() async {
        model.timestamp = .now
        
        contracts = contracts
            .filter {
                $0.sub?.subscriber != nil
            }
        
        await publish(model: model)
        
        store.send((model, true))
    }
    
    public func publish(model: Output) async {
        let subscribers = contracts.compactMap(\.sub?.subscriber)
        await MainActor
            .run {
                subscribers
                    .forEach {
                        _ = $0.receive(model)
                    }
            }
    }
    
    nonisolated public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
        let sub = Sub(subscriber: .init(subscriber))
        subscriber.receive(subscription: sub)
        
        Task {
            await store(contract: .init(sub: sub))
        }
    }
    
    func update(model: Output) {
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
    
    private func login(container: Container) {
        let config = CKOperation.Configuration()
        config.timeoutIntervalForRequest = 13
        config.timeoutIntervalForResource = 13
        config.qualityOfService = .userInitiated
        
        record
            .sink { id in
                Task {
                    await container.database.configured(with: config) { base in
                        do {
                            if try await base.allSubscriptions().isEmpty {
                                let subscription = CKQuerySubscription(
                                    recordType: Type,
                                    predicate: .init(format: "recordID = %@", id),
                                    options: [.firesOnRecordUpdate, .firesOnRecordDeletion, .firesOnRecordCreation])
                                subscription.notificationInfo = .init(shouldSendContentAvailable: true)
                                _ = try await base.save(subscription)
                            }
                        } catch {
                            Swift.print(error)
                        }
                    }
                }
            }
            .store(in: &subs)
        
        pull
            .merge(with: push)
            .flatMap { [weak self] _ in
                Future { [weak self] promise in
                    Task { [weak self] in
                        guard
                            let status = try? await container.accountStatus(),
                            status == .available,
                            let user = try? await container.userRecordID()
                        else {
                            promise(.success(nil))
                            await self?.notify()
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
                    let result = await container.database.configured(with: config) { base -> Wrapper<Output>? in
                        guard
                            let record = try? await base.record(for: id),
                            let asset = record[Asset] as? CKAsset,
                            let fileURL = asset.fileURL,
                            let data = try? Data(contentsOf: fileURL)
                        else {
                            Task { [weak self] in
                                await self?.notify()
                            }
                            return nil
                        }
                        return await .init(data: data)
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
    }
    
    private func synch() {
        remote
            .compactMap { $0 }
            .flatMap { [weak self] wrapper in
                Future { [weak self] promise in
                    Task { [weak self] in
                        guard
                            let current = await self?.model.timestamp,
                            wrapper.timestamp > current
                        else {
                            promise(.success(nil))
                            await self?.notify()
                            return
                        }
                        await promise(.success(wrapper.archive))
                    }
                }
            }
            .compactMap {
                $0
            }
            .sink { [weak self] (model: Output) in
                Task { [weak self] in
                    await self?.update(model: model)
                    await self?.publish(model: model)
                    self?.store.send((model, false))
                    await self?.notify()
                }
            }
            .store(in: &subs)
        
        remote
            .filter {
                $0 == nil
            }
            .sink { [weak self] _ in
                self?.push.send()
            }
            .store(in: &subs)
        
        remote
            .compactMap { $0 }
            .flatMap { [weak self] output in
                Future { [weak self] promise in
                    Task { [weak self] in
                        guard
                            let current = await self?.model.timestamp,
                            output.timestamp < current
                        else {
                            promise(.success(false))
                            return
                        }
                        promise(.success(true))
                    }
                }
            }
            .filter {
                $0
            }
            .sink { [weak self] _ in
                self?.push.send()
            }
            .store(in: &subs)
        
        store
            .debounce(for: .milliseconds(250), scheduler: queue)
            .sink { [weak self] storing in
                Task
                    .detached(priority: .userInitiated) { [weak self] in
                        let data = await Wrapper(archive: storing.0).compressed
                        do {
                            try data.write(to: self!.url, options: .atomic)
                            if storing.1 {
                                self?.push.send()
                            }
                        } catch { }
                    }
            }
            .store(in: &subs)
    }
    
    private func notify() {
        guard !loaded else { return }
        loaded = true
        ready.leave()
    }
}
