import Foundation
import CloudKit
@testable import Archivable

class ContainerMock: CloudContainer {
    var database: CloudDatabase = DatabaseMock()
    var status = CKAccountStatus.noAccount
    var id = "lorem"
    
    func accountStatus() async throws -> CKAccountStatus {
        status
    }
    
    func userRecordID() async throws -> CKRecord.ID {
        .init(recordName: id)
    }
}
