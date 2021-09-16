import Combine

extension Cloud {
    final class Sub: Subscription {
        private(set) var subscriber: AnySubscriber<A, Never>?
        private weak var pub: Pub?
        
        init(pub: Pub, subscriber: AnySubscriber<A, Never>) {
            self.pub = pub
            self.subscriber = subscriber
        }
        
        func cancel() {
            subscriber = nil
        }
        
        func request(_ demand: Subscribers.Demand) {
            if demand == .unlimited || demand.max != 0 {
                pub?.deploy()
            }
        }
    }
}
