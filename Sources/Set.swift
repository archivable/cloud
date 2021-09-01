import Foundation

extension Set {
    public func inserting(_ element: Element) -> Self {
        var set = self
        set.insert(element)
        return set
    }
    
    public func removing(_ element: Element) -> Self {
        var set = self
        _ = set
            .firstIndex(of: element)
            .map {
                set.remove(at: $0)
            }
        return set
    }
}
