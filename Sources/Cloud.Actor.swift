import Foundation
import Combine

extension Cloud {
    final actor Actor {
        private(set) var model = Output()
        private(set) var loaded = false
        private(set) var contracts = [Contract]()
        
        var subscribers: [AnySubscriber<Output, Failure>] {
            contracts = contracts
                .filter {
                    $0.sub?.subscriber != nil
                }
            
            return contracts.compactMap(\.sub?.subscriber)
        }
        
        func ready() {
            loaded = true
        }
        
        func update(model: Output) {
            self.model = model
        }
        
        func store(contract: Contract) {
            contracts.append(contract)
        }
    }
}
