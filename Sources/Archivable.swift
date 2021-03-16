import Foundation

public protocol Archivable {
    var data: Data { get }
    
    init(data: inout Data)
}
