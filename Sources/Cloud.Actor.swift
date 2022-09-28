import Foundation

private let Prefix = "i"
private let Type = "Model"
private let Asset = "payload"

#if DEBUG
private let Suffix = ".debug.data"
#else
private let Suffix = ".data"
#endif

extension Cloud {
    final actor Actor {
        var model = Output()
        private var loaded = false
    }
}
