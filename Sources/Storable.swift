import Foundation

public protocol Storable {
    var data: Data { get async }
    
    init(data: inout Data) async
}
