import Foundation

actor Actor {
    var number: Int
    
    init() async {
        number = await load()
    }
}

private func load() async -> Int {
    await withUnsafeContinuation { continuation in
        DispatchQueue.global(qos: .utility).async {
            continuation.resume(returning: 99)
        }
    }
}
