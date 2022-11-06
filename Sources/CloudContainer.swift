import CloudKit

protocol CloudContainer {
    associatedtype Database : CloudDatabase
    var database: Database { get }
    
    init(identifier: String)
    func accountStatus() async throws -> CKAccountStatus
    func userRecordID() async throws -> CKRecord.ID
}
