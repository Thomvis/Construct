import ComposableArchitecture

@Reducer
public struct WithValue<ParentState, Value, ParentAction, Body: Reducer>
where Body.State == ParentState, Body.Action == ParentAction {

    @usableFromInline
    let toValue: (ParentState) -> Value
    @usableFromInline
    let reducer: (Value) -> Body

    public typealias State = ParentState
    public typealias Action = ParentAction

    @inlinable
    public init(
        value toValue: @escaping (ParentState) -> Value,
        reducer: @escaping (Value) -> Body
    ) {
        self.toValue = toValue
        self.reducer = reducer
    }

    @inlinable
    public func reduce(into state: inout ParentState, action: ParentAction) -> Effect<ParentAction> {
        reducer(toValue(state)).reduce(into: &state, action: action)
    }

}

// Note: this extension is intended to reduce the recreations of the
// inner reducer to the time when the value changed. This turned out not
// to work, because Reducer bodies are invoked again and again,
// causing the whole WithValue to be recreated.
//extension WithValue where Value: Equatable {
//    public init(
//        value toValue: @escaping (ParentState) -> Value,
//        reducer: @escaping (Value) -> Body
//    ) {
//        self.toValue = toValue
//
//        var innerReducer: Body? = nil
//        var innerReducerValue: Value? = nil
//        self.reducer = { value in
//            if let innerReducer, value == innerReducerValue {
//                return innerReducer
//            } else {
//                let r = reducer(value)
//                innerReducer = r
//                innerReducerValue = value
//                return r
//            }
//        }
//    }
//}
