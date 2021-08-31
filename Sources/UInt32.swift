import Foundation

extension UInt32 {
    public static var now: Self {
        Date().timestamp
    }
}
