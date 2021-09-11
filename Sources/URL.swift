import Foundation

extension URL {
    func exclude() {
        var url = self
        var resources = URLResourceValues()
        resources.isExcludedFromBackup = true
        try? url.setResourceValues(resources)
    }
}
