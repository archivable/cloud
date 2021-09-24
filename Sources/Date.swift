import Foundation

extension Date {
    public init(timestamp: UInt32) {
        self.init(timeIntervalSince1970: .init(timestamp))
    }
    
    public var timestamp: UInt32 {
        .init(timeIntervalSince1970)
    }
    
    public var data: Data {
        .init()
            .adding(self)
    }
}
