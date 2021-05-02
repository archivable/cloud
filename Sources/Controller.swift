import Foundation

public protocol Controller {
    associatedtype A : Archived
    
    static var cloud: Cloud<Self> { get }
    static var file: URL { get }
    static var container: String { get }
    static var prefix: String { get }
    static var title: String { get }
}
