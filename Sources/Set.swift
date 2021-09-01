import Foundation

extension Set {
    func inserting(_ element: Element) -> Self {
        var set = self
        set.insert(element)
        return set
    }
}
