import Foundation
import CloudKit
@testable import Archivable

struct DatabaseMock: CloudDatabase {
    func configured<R>(with: CKOperation.Configuration, body: (CloudDatabase) async -> R) async -> R {
        await body(self)
    }
    
    func save(_ subscription: CKSubscription) async throws -> CKSubscription {
        fatalError()
    }
    
    func record(for recordID: CKRecord.ID) async throws -> CKRecord {
        .init(recordType: .init())
    }
    
    func modifyRecords(saving recordsToSave: [CKRecord], deleting recordIDsToDelete: [CKRecord.ID], savePolicy: CKModifyRecordsOperation.RecordSavePolicy, atomically: Bool) async throws -> (saveResults: [CKRecord.ID : Result<CKRecord, Error>], deleteResults: [CKRecord.ID : Result<Void, Error>]) {
        ([:], [:])
    }
    
    func configuredWith<R>(configuration: CKOperation.Configuration?, group: CKOperationGroup?, body: (CKDatabase) async throws -> R) async rethrows -> R {
        fatalError()
    }
}
