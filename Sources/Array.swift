import Foundation

extension Array {
    public mutating func mutate(criteria: (Self) -> Int?, transform: (Element) -> Element) {
        criteria(self)
            .map {
                self[$0] = transform(self[$0])
            }
    }
    
    public mutating func mutate(index: Int, transform: (Element) -> Element) {
        self[index] = transform(self[index])
    }
    
    public func mutating(criteria: (Self) -> Int?, transform: (Element) -> Element) -> Self {
        var array = self
        criteria(self)
            .map {
                array[$0] = transform(array[$0])
            }
        return array
    }
    
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
    
    public static func +(array: Self, element: Element) -> Self {
        var array = array
        array.append(element)
        return array
    }
    
    public static func +(element: Element, array: Self) -> Self {
        var array = array
        array.insert(element, at: 0)
        return array
    }
    
    public static func +=(array: inout Self, element: Element) {
        array.append(element)
    }
}
