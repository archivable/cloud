import Foundation

extension Array {
    public func mutating(index: Int, transform: (Element) -> Element) -> Self {
        var array = self
        array[index] = transform(array[index])
        return array
    }
    
    public func last(transform: (Element) -> Element) -> Self {
        var array = self
        array[count] = transform(array[count])
        return array
    }
    
    public func moving(from: Int, to: Int) -> Self {
        var array = self
        array.insert(array.remove(at: from), at: Swift.min(to, array.count))
        return array
    }
    
    public func removing(index: Int) -> Self {
        var array = self
        array.remove(at: index)
        return array
    }
    
    public static func +(array: Self, element: Element?) -> Self {
        guard let element = element else { return array }
        var array = array
        array.append(element)
        return array
    }
    
    public static func +(element: Element?, array: Self) -> Self {
        guard let element = element else { return array }
        var array = array
        array.insert(element, at: 0)
        return array
    }
}
