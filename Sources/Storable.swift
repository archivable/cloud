import Foundation

public protocol Storable: Equatable {
    var data: Data { get async }
    
    init(data: inout Data) async
}
