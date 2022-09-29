import Foundation
@testable import Archivable

extension Cloud where Output == Archive {
    func increaseCounter() async {
        await actor.increaseCounter()
        await stream()
    }
}

private extension Cloud.Actor where Output == Archive {
    func increaseCounter() async {
        model.counter += 1
    }
}
