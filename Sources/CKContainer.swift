import CloudKit

extension CKContainer: CloudContainer {
    public var database: CKDatabase {
        publicCloudDatabase
    }
}
