import Foundation

public protocol Controller {
    associatedtype A : Archived
    
    static var memory: Cloud<Self> { get }
    static var file: URL { get }
    static var container: String { get }
    static var prefix: String { get }
}
