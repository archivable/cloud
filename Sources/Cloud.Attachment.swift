import Combine

extension Cloud {
    struct Attachment {
        private(set) weak var sub: Sub?
        
        init(sub: Sub) {
            self.sub = sub
        }
    }
}
