import CloudKit

extension CKDatabase: CloudDatabase {
    func configured<R>(with: CKOperation.Configuration, body: (CloudDatabase) async -> R) async -> R {
        await configuredWith(configuration: with, body: body)
    }
}
