import Foundation
import Archivable

extension Cloud where A == Archive {
    func increaseCounter() async {
        model.counter += 1
        await stream()
    }
}
