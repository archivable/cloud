import CloudKit

extension CKDatabase: CloudDatabase {
    public func configured<R>(with: CKOperation.Configuration, body: (CloudDatabase) async -> R) async -> R {
        await configuredWith(configuration: with, body: body)
    }
    
    func a() {
        allSubscriptions()
    }
}
