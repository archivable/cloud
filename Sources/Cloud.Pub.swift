import Combine

extension Cloud {
    final class Pub: Publisher {
        typealias Output = A
        typealias Failure = Never
        
        private(set) weak var sub: Sub?
        private weak var cloud: Cloud?
        
        init(cloud: Cloud) {
            self.cloud = cloud
        }
        
        func receive<S>(subscriber: S) where S : Subscriber, Never == S.Failure, A == S.Input {
            let sub = Sub(subscriber: .init(subscriber))
            subscriber.receive(subscription: sub)
            cloud?.deploy(sub: sub)
            self.sub = sub
        }
    }
}
