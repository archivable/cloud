import Foundation

public protocol Archiving {
    var data: Data { get }
    
    init(data: inout Data)
}
