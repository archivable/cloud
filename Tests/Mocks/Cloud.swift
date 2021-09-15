import Foundation
import Archivable

extension Cloud where A == Archive {
    func increaseCounter() async {
        _archive.counter += 1
        await stream()
    }
}
