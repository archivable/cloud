import Combine

extension Cloud {
    final class Sub: Subscription {
        private(set) var subscriber: AnySubscriber<A, Never>?
        
        init(subscriber: AnySubscriber<A, Never>) {
            self.subscriber = subscriber
        }
        
        func cancel() {
            subscriber = nil
        }
        
        func request(_: Subscribers.Demand) {

        }
    }
}
