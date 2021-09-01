import Foundation

extension Set {
    public func inserting(_ element: Element) -> Self {
        var set = self
        set.insert(element)
        return set
    }
}
