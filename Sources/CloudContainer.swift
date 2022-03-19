import CloudKit

public protocol CloudContainer {
    var database: CloudDatabase { get }
    
    init(identifier: String)
    func accountStatus() async throws -> CKAccountStatus
    func userRecordID() async throws -> CKRecord.ID
}
