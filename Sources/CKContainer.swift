import CloudKit

extension CKContainer: CloudContainer {
    public var database: CloudDatabase {
        publicCloudDatabase
    }
}
