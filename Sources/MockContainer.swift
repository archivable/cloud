import Foundation
import CloudKit

class MockContainer: CloudContainer {
    var database = MockDatabase()
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
