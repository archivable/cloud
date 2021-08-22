import CloudKit

public struct Manifest {
    public let container: CKContainer
    public let url: URL
    public let prefix: String
    
    public init(file: String, container: String, prefix: String) {
        var url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(file + suffix)
        var resources = URLResourceValues()
        resources.isExcludedFromBackup = true
        try? url.setResourceValues(resources)
        
        self.url = url
        self.container = CKContainer(identifier: container)
        self.prefix = prefix
    }
}

#if DEBUG
    private let suffix = ".debug.archive"
#else
    private let suffix = ".archive"
#endif
