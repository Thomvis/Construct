
public final class AnyRandomNumberGenerator: RandomNumberGenerator {
    public var wrapped: RandomNumberGenerator

    public init(wrapped: RandomNumberGenerator) {
        self.wrapped = wrapped
    }

    public convenience init() {
        self.init(wrapped: SystemRandomNumberGenerator())
    }

    public func next() -> UInt64 {
        return wrapped.next()
    }
}
