import Foundation
import Archivable

extension Cloud where Output == Archive {
    func increaseCounter() async {
        model.counter += 1
        await stream()
    }
}
