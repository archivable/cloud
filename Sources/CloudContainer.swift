import CloudKit

protocol CloudContainer {
    var database: CloudDatabase { get }
    
    func accountStatus() async throws -> CKAccountStatus
    func userRecordID() async throws -> CKRecord.ID
}
