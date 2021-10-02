import Foundation

extension Array {
    public mutating func mutate(where element: (Self) -> Int?, transform: (Element) -> Element?) {
        element(self)
            .map { index in
                transform(self[index])
                    .map {
                        self[index] = $0
                    }
            }
    }
    
    public mutating func mutate(index: Int, transform: (Element) -> Element?) {
        transform(self[index])
            .map {
                self[index] = $0
            }
    }
    
    @discardableResult public mutating func remove(where element: (Element) -> Bool) -> Element? {
        firstIndex(where: element)
            .map {
                remove(at: $0)
            }
    }
    
    public func mutating(criteria: (Self) -> Int?, transform: (Element) -> Element?) -> Self {
        var array = self
        criteria(self)
            .map { index in
                transform(array[index])
                    .map {
                        array[index] = $0
                    }
            }
        return array
    }
    
    public func mutating(criteria: (Element) -> Bool, transform: (Element) -> Element?) -> Self {
        var array = self
        array
            .firstIndex(where: criteria)
            .map { index in
                transform(array[index])
                    .map {
                        array[index] = $0
                    }
            }
        return array
    }
    
    public func mutating(index: Int, transform: (Element) -> Element?) -> Self {
        var array = self
        transform(array[index])
            .map {
                array[index] = $0
            }
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
    
    public func moving(criteria: (Element) -> Bool, to: Int) -> Self {
        var array = self
        array
            .remove(where: criteria)
            .map {
                array.insert($0, at: Swift.min(to, array.count))
            }
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
