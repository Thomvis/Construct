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

public func StateDrivenNavigationLink<GlobalState, GlobalAction, DestinationState, DestinationAction, Destination, Label>(store: Store<GlobalState, GlobalAction>, state: CasePath<GlobalState.NextScreenState, DestinationState>, action: CasePath<GlobalAction.NextScreenAction, DestinationAction>, navDest: NavigationDestination = .nextInStack, isActive: @escaping (DestinationState) -> Bool, initialState: @escaping () -> DestinationState, destination: @escaping (Store<DestinationState, DestinationAction>) -> Destination, label: @escaping () -> Label) -> some View where GlobalState: NavigationStackSourceState, GlobalAction: NavigationStackSourceAction, GlobalState: Equatable, GlobalState.NextScreenState == GlobalAction.NextScreenState, GlobalState.NextScreenState: Equatable, Destination: View, Label: View {
    WithViewStore(store, observe: { $0.presentedScreens[navDest] }) { viewStore in
        NavigationLink(
            destination: IfLetStore(store.scope(state: replayNonNil({ $0.presentedScreens[navDest].flatMap(state.extract) }), action: { .presentedScreen(navDest, action.embed($0)) })) { destination($0) },
            isActive: Binding(get: {
                if let nextScreen = viewStore.state, let state = state.extract(from: nextScreen) {
                    return isActive(state)
                } else {
                    return false
                }
            }, set: { active in
                let nextScreen = viewStore.state
                let destinationState = nextScreen.flatMap { state.extract(from: $0) }

                if active && !(destinationState.map(isActive) ?? false) {
                    viewStore.send(.presentScreen(navDest, state.embed(initialState())))
                } else if navDest != .detail, let nextScreen = viewStore.state, let state = state.extract(from: nextScreen), isActive(state) {
                    viewStore.send(.presentScreen(navDest, nil))
                }
            }))
        {
            label()
        }
        .isDetailLink(navDest == .detail)
    }
}

public func StateDrivenNavigationLink<GlobalState, GlobalAction, DestinationState, DestinationAction, Destination, Label>(store: Store<GlobalState, GlobalAction>, state: CasePath<GlobalState.NextScreenState, DestinationState>, action: CasePath<GlobalAction.NextScreenAction, DestinationAction>, navDest: NavigationDestination = .nextInStack, isActive: @escaping (DestinationState) -> Bool, initialState: DestinationState, destination: @escaping (Store<DestinationState, DestinationAction>) -> Destination, label: @escaping () -> Label) -> some View where GlobalState: NavigationStackSourceState, GlobalAction: NavigationStackSourceAction, GlobalState: Equatable, GlobalState.NextScreenState == GlobalAction.NextScreenState, GlobalState.NextScreenState: Equatable, Destination: View, Label: View {
    StateDrivenNavigationLink(store: store, state: state, action: action, navDest: navDest, isActive: isActive, initialState: { initialState }, destination: destination, label: label)
}

extension View {
    public func stateDrivenNavigationLink<GlobalState, GlobalAction, DestinationState, DestinationAction, Destination>(store: Store<GlobalState, GlobalAction>, state: CasePath<GlobalState.NextScreenState, DestinationState>, action: CasePath<GlobalAction.NextScreenAction, DestinationAction>, navDest: NavigationDestination = .nextInStack, destination: @escaping (Store<DestinationState, DestinationAction>) -> Destination) -> some View where GlobalState: NavigationStackSourceState, GlobalAction: NavigationStackSourceAction, GlobalState: Equatable, GlobalState.NextScreenState == GlobalAction.NextScreenState, GlobalState.NextScreenState: Equatable, DestinationState: Equatable, DestinationState: NavigationStackItemState, Destination: View {
        self.background(
            StateDrivenNavigationLink(
                store: store,
                state: state,
                action: action,
                navDest: navDest,
                isActive: { _ in true },
                initialState: { fatalError() },
                destination: { store in
                    destination(store).id(ViewStore(store).state.navigationStackItemStateId)
                },
                label: { EmptyView() }
            )
        )
    }
}

#endif
