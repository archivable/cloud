import CloudKit

public struct Container {
    let base: CKContainer
    let url: URL
    let configuration = CKOperation.Configuration()
    
    public init(name: String) {
        var url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(file)
        var resources = URLResourceValues()
        resources.isExcludedFromBackup = true
        try? url.setResourceValues(resources)
        
        self.url = url
        self.base = CKContainer(identifier: name)
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 10
        configuration.qualityOfService = .userInitiated
    }
}

#if DEBUG
    private let file = "Archive.debug.data"
#else
    private let file = "Archive.data"
#endif
