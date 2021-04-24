import Foundation

public protocol Property {
    var data: Data { get }
    
    init(data: inout Data)
}
