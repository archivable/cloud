import Foundation

public protocol Storable: Equatable {
    var data: Data { get }
    
    init(data: inout Data)
}
