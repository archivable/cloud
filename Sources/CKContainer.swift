import CloudKit

extension CKContainer: CloudContainer {
    var database: CloudDatabase {
        publicCloudDatabase
    }
}
