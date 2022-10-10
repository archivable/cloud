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

public final class Cloud<Output, Container>: Publisher where Output : Arch, Container : CloudContainer {
    public typealias Failure = Never
    
    public static func new(identifier: String) -> Self {
        let cloud = Self()
        Task {
            await cloud.load(container: Container(identifier: identifier))
        }
        return cloud
    }
    
    public let ready = DispatchGroup()
    public let pull = PassthroughSubject<Void, Failure>()
    let url: URL
    let actor = Actor()
    let push = PassthroughSubject<Void, Failure>()
    let remote = PassthroughSubject<Wrapper<Output>?, Failure>()
    let store = PassthroughSubject<(Output, Bool), Failure>()
    let record = PassthroughSubject<CKRecord.ID, Failure>()
    private var subs = Set<AnyCancellable>()
    private let queue = DispatchQueue(label: "", qos: .userInitiated)
    
    public var model: Output {
        get async {
            await actor.model
        }
    }
    
    public var backgroundFetch: Bool {
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
    
    public func update(model: Output) async {
        var model = model
        model.timestamp = .now
        await actor.update(model: model)
        await publish(model: model)
        store.send((model, true))
    }
    
    public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
        let sub = Sub(subscriber: .init(subscriber))
        subscriber.receive(subscription: sub)
        
        Task {
            await actor.store(contract: .init(sub: sub))
            let model = await actor.model
            
            await MainActor
                .run {
                    _ = subscriber.receive(model)
                }
        }
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
            await actor.update(model: output)
            await publish(model: output)
        }
        
        pull.send()
    }
    
    private func publish(model: Output) async {
        let subscribers = await actor.subscribers
        await MainActor
            .run {
                subscribers
                    .forEach {
                        _ = $0.receive(model)
                    }
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
                            let current = await self?.actor.model.timestamp,
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
                    await self?.actor.update(model: model)
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
                            let current = await self?.actor.model.timestamp,
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
    
    private func notify() async {
        guard await !actor.loaded else { return }
        await actor.ready()
        ready.leave()
    }
}
