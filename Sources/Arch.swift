import Foundation

public protocol Arch {
    var data: Data { get async }
    
    init()
    init(data: Data) async
}
