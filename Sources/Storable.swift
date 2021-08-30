import Foundation

public protocol Storable {
    var data: Data { get }
    
    init(data: inout Data)
}
