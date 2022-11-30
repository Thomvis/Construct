//
//  Navigation.swift
//  Construct
//
//  Created by Thomas Visser on 29/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

#if os(iOS)

import Foundation
import SwiftUI
import ComposableArchitecture
import SwiftUINavigation

public protocol NavigationStackItemState {
    var navigationStackItemStateId: String { get }

    // We use this to set the initial title of a screen when it is first presented
    // in a StateDrivenNavigationView
    // The title set through .navigationBarTitle comes in a fraction too late :(
    var navigationTitle: String { get }
    var navigationTitleDisplayMode: NavigationBarItem.TitleDisplayMode? { get }
}

public extension NavigationStackItemState {
    var navigationTitleDisplayMode: NavigationBarItem.TitleDisplayMode? { nil }
}

public protocol NavigationStackSourceState: NavigationStackItemState {
    associatedtype NextScreenState

    var presentedScreens: [NavigationDestination: NextScreenState] { get set }
}

public enum NavigationDestination: Int {
    case nextInStack
    case detail
}

public extension NavigationStackSourceState {
    var nextScreen: NextScreenState? {
        get { presentedScreens[.nextInStack] }
        set { presentedScreens[.nextInStack] = newValue }
    }

    var detailScreen: NextScreenState? {
        get { presentedScreens[.detail] }
        set { presentedScreens[.detail] = newValue }
    }
}

public protocol NavigationStackSourceAction {
    associatedtype NextScreenState
    associatedtype NextScreenAction

    // BUG: these cannot have the same name as cases in the enum that conforms
    // to this protocol or else CasePaths will have undefined behavior and cause crashes
    static func presentScreen(_ destination: NavigationDestination, _ screen: NextScreenState?) -> Self
    static func presentedScreen(_ destination: NavigationDestination, _ action: NextScreenAction) -> Self

}

extension View {
    public func stateDrivenNavigationLink<GlobalState, GlobalAction, DestinationState, DestinationAction, Destination>(
        store: Store<GlobalState, GlobalAction>,
        state: CasePath<GlobalState.NextScreenState, DestinationState>,
        action: CasePath<GlobalAction.NextScreenAction, DestinationAction>,
        destination: @escaping (Store<DestinationState, DestinationAction>) -> Destination
    ) -> some View where GlobalState: NavigationStackSourceState,
                            GlobalAction: NavigationStackSourceAction,
                            GlobalState: Equatable,
                            GlobalState.NextScreenState == GlobalAction.NextScreenState,
                            GlobalState.NextScreenState: Equatable,
                            DestinationState: Equatable,
                            DestinationState: NavigationStackItemState,
                            Destination: View
    {
        WithViewStore(store, observe: { $0.presentedScreens[.nextInStack] }) { viewStore in
            self.navigationDestination(
                unwrapping: Binding(
                    get: {
                        viewStore.state.flatMap(state.extract)
                    },
                    set: { v, t in
                        viewStore.send(.presentScreen(.nextInStack, v.map(state.embed)))
                    }
                )) { b in
                    let destinationStore = store.scope(
                        state: replayNonNil({ $0.presentedScreens[.nextInStack].flatMap(state.extract) }),
                        action: { .presentedScreen(.nextInStack, action.embed($0)) }
                    )

                    IfLetStore(destinationStore, then: destination)
                }
//            self.navigationDestination(
//                isPresented: Binding(get: {
//                    if let nextScreen = viewStore.state, state.extract(from: nextScreen) != nil {
//                        return true
//                    } else {
//                        return false
//                    }
//                }, set: { active, transaction in
//                    if active {
//                        assertionFailure("This navigationDestination cannot be triggered by the framework")
//                    } else if !active, let nextScreen = viewStore.state, state.extract(from: nextScreen) != nil {
//                        viewStore.send(.presentScreen(.nextInStack, nil))
//                    }
//                }),
//                destination: {
//                    let destinationStore = store.scope(
//                        state: replayNonNil({ $0.presentedScreens[.nextInStack].flatMap(state.extract) }),
//                        action: { .presentedScreen(.nextInStack, action.embed($0)) }
//                    )
//
//                    IfLetStore(destinationStore, then: destination)
//                }
//            )
        }
    }
}

#endif
