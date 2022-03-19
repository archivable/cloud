import Foundation
import CloudKit
@testable import Archivable

class ContainerMock: CloudContainer {
    var database = DatabaseMock()
    var status = CKAccountStatus.noAccount
    var id = "lorem"
    
    required init(identifier: String) {
        
    }
    
    func accountStatus() async throws -> CKAccountStatus {
        status
    }
    
    func userRecordID() async throws -> CKRecord.ID {
        .init(recordName: id)
    }
}
