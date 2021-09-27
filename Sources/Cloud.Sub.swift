import Combine

extension Cloud {
    final class Sub: Subscription {
        private(set) var subscriber: AnySubscriber<Output, Never>?
        
        init(subscriber: AnySubscriber<Output, Never>) {
            self.subscriber = subscriber
        }
        
        func cancel() {
            subscriber = nil
        }
        
        func request(_: Subscribers.Demand) {

        }
    }
}
