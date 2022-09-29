import Foundation
//
//private let Prefix = "i"
//private let Type = "Model"
//private let Asset = "payload"
//
//#if DEBUG
//private let Suffix = ".debug.data"
//#else
//private let Suffix = ".data"
//#endif

extension Cloud {
    final actor Actor {
        var model = Output()
        private(set) var contracts = [Contract]()
        
        func stream() -> Output {
            model.timestamp = .now
            
            contracts = contracts
                .filter {
                    $0.sub?.subscriber != nil
                }
            
            return model
        }
        
        func update(model: Output) {
            self.model = model
        }
        
        func store(contract: Contract) -> Output {
            contracts.append(contract)
            return model
        }
    }
}
