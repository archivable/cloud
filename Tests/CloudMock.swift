import Foundation
import Archivable

extension Cloud where A == ArchiveMock {
    func increaseCounterPersist() {
        arch.counter += 1
        timestamp()
        persist()
    }
    
    func increaseCounterStream() async {
        arch.counter += 1
        timestamp()
        await stream()
    }
}

