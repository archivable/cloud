import Foundation
import CloudKit
import Combine

class MockDatabase: CloudDatabase {
    var record: CKRecord?
    let saved = PassthroughSubject<CKSubscription, Never>()
    let pushed = PassthroughSubject<Void, Never>()
    let pulled = PassthroughSubject<Void, Never>()
    
    func configured<R>(with: CKOperation.Configuration, body: (CloudDatabase) async -> R) async -> R {
        await body(self)
    }
    
    func save(_ subscription: CKSubscription) async throws -> CKSubscription {
        saved.send(subscription)
        return subscription
    }
    
    func record(for recordID: CKRecord.ID) async throws -> CKRecord {
        pulled.send()
        guard let record = record else { throw NSError(domain: "", code: 1) }
        return record
    }
    
    func modifyRecords(saving recordsToSave: [CKRecord], deleting recordIDsToDelete: [CKRecord.ID], savePolicy: CKModifyRecordsOperation.RecordSavePolicy, atomically: Bool) async throws -> (saveResults: [CKRecord.ID : Result<CKRecord, Error>], deleteResults: [CKRecord.ID : Result<Void, Error>]) {
        pushed.send()
        return ([:], [:])
    }
}
