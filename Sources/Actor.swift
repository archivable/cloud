import Foundation
import Combine

actor Actor {
    var acted: Acted {
        didSet {
            update()
        }
    }
    
    nonisolated let stream = PassthroughSubject<Acted, Never>()
    
    init() async {
        acted = await Task.detached(priority: .utility) {
            await load()
        }.value
        update()
    }
    
    private func update() {
        Task.detached {
            await self.stream.send(self.acted)
        }
    }
}

struct Acted {
    let value = 100
}

private func load() async -> Acted {
    await withUnsafeContinuation { continuation in
        DispatchQueue.global(qos: .utility).async {
            continuation.resume(returning: .init())
        }
    }
}
