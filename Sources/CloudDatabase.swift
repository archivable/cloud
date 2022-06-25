import CloudKit

public protocol CloudDatabase {
    func configured<R>(with: CKOperation.Configuration, body: (CloudDatabase) async -> R) async -> R
    func save(_ subscription: CKSubscription) async throws -> CKSubscription
    func record(for recordID: CKRecord.ID) async throws -> CKRecord
    func modifyRecords(saving recordsToSave: [CKRecord], deleting recordIDsToDelete: [CKRecord.ID], savePolicy: CKModifyRecordsOperation.RecordSavePolicy, atomically: Bool) async throws -> (saveResults: [CKRecord.ID : Result<CKRecord, Error>], deleteResults: [CKRecord.ID : Result<Void, Error>])
    func allSubscriptions() async throws -> [CKSubscription]
}
