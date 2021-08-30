import CloudKit

public struct Container {
    let container: CKContainer
    let url: URL
    
    public init(name: String) {
        var url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(file)
        var resources = URLResourceValues()
        resources.isExcludedFromBackup = true
        try? url.setResourceValues(resources)
        
        self.url = url
        self.container = CKContainer(identifier: name)
    }
}

#if DEBUG
    private let file = "Archive.debug.data"
#else
    private let file = "Archive.data"
#endif
