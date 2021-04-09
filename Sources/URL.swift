import Foundation

extension URL {
    public static func manifest(_ file: String) -> Self {
        var url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(file)
        var resources = URLResourceValues()
        resources.isExcludedFromBackup = true
        try? url.setResourceValues(resources)
        return url
    }
}
