import Foundation

public protocol Memory {
    associatedtype A: Archivable
    static var shared: Self { get }
    static var debug: URL { get }
    static var production: URL { get }
}

public extension Memory {
    static var archive: A? {
        get {
            try? Data(contentsOf: url).mutating(transform: A.init(data:))
        }
        set {
            try? newValue!.data.write(to: url, options: .atomic)
        }
    }
    
    static func make(url: String) -> URL {
        var url = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask)[0].appendingPathComponent(url)
        var resources = URLResourceValues()
        resources.isExcludedFromBackup = true
        try? url.setResourceValues(resources)
        return url
    }
    
    func load() {
        local.send(FileManager.archive)
    }
    
    #if DEBUG
        private static var url: URL { debug }
    #else
        private static var url: URL { production }
    #endif
}
