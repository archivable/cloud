import Foundation
import CloudKit
@testable import Archivable

struct ContainerMock: CloudContainer {
    func accountStatus() async throws -> CKAccountStatus {
        .available
    }
    
    func userRecordID() async throws -> CKRecord.ID {
        .init()
    }
    
    var database: CloudDatabase {
        DatabaseMock()
    }
}
