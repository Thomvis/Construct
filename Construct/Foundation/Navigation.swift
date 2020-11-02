//
//  Navigation.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 29/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture

protocol NavigationStackItemState {
    var navigationStackItemStateId: String { get }

    // We use this to set the initial title of a screen when it is first presented
    // in a StateDrivenNavigationView
    // The title set through .navigationBarTitle comes in a fraction too late :(
    var navigationTitle: String { get }
    var navigationTitleDisplayMode: NavigationBarItem.TitleDisplayMode? { get }
}

extension NavigationStackItemState {
    var navigationTitleDisplayMode: NavigationBarItem.TitleDisplayMode? { nil }
}

protocol NavigationStackSourceState: NavigationStackItemState {
    associatedtype NextScreenState

    var presentedScreens: [NavigationDestination: NextScreenState] { get set }
}

enum NavigationDestination: Int {
    case nextInStack
    case detail
}

extension NavigationStackSourceState {
    var nextScreen: NextScreenState? {
        get { presentedScreens[.nextInStack] }
        set { presentedScreens[.nextInStack] = newValue }
    }

    var detailScreen: NextScreenState? {
        get { presentedScreens[.detail] }
        set { presentedScreens[.detail] = newValue }
    }
}

protocol NavigationStackSourceAction {
    associatedtype NextScreenState
    associatedtype NextScreenAction

    // BUG: these cannot have the same name as cases in the enum that conforms
    // to this protocol or else CasePaths will have undefined behavior and cause crashes
    static func presentScreen(_ destination: NavigationDestination, _ screen: NextScreenState?) -> Self
    static func presentedScreen(_ destination: NavigationDestination, _ action: NextScreenAction) -> Self

}

func StateDrivenNavigationLink<GlobalState, GlobalAction, DestinationState, DestinationAction, Destination, Label>(store: Store<GlobalState, GlobalAction>, state: CasePath<GlobalState.NextScreenState, DestinationState>, action: CasePath<GlobalAction.NextScreenAction, DestinationAction>, navDest: NavigationDestination = .nextInStack, isActive: @escaping (DestinationState) -> Bool, initialState: @escaping () -> DestinationState, destination: @escaping (Store<DestinationState, DestinationAction>) -> Destination, label: () -> Label) -> some View where GlobalState: NavigationStackSourceState, GlobalAction: NavigationStackSourceAction, GlobalState: Equatable, GlobalState.NextScreenState == GlobalAction.NextScreenState, Destination: View, Label: View {
    NavigationLink(
        destination: IfLetStore(store.scope(state: { $0.presentedScreens[navDest].flatMap(state.extract) }, action: { .presentedScreen(navDest, action.embed($0)) })) { destination($0) }.navigationViewChild,
        isActive: Binding(get: {
            if let nextScreen = ViewStore(store).state.presentedScreens[navDest], let state = state.extract(from: nextScreen) {
                return isActive(state)
            } else {
                return false
            }
        }, set: { active in
            if active {
                ViewStore(store).send(.presentScreen(navDest, state.embed(initialState())))
            } else if navDest != .detail, let nextScreen = ViewStore(store).state.presentedScreens[navDest], let state = state.extract(from: nextScreen), isActive(state) {
                ViewStore(store).send(.presentScreen(navDest, nil))
            }
        }))
    {
        label()
    }
    .isDetailLink(navDest == .detail)
}

func StateDrivenNavigationLink<GlobalState, GlobalAction, DestinationState, DestinationAction, Destination, Label>(store: Store<GlobalState, GlobalAction>, state: CasePath<GlobalState.NextScreenState, DestinationState>, action: CasePath<GlobalAction.NextScreenAction, DestinationAction>, navDest: NavigationDestination = .nextInStack, isActive: @escaping (DestinationState) -> Bool, initialState: DestinationState, destination: @escaping (Store<DestinationState, DestinationAction>) -> Destination, label: () -> Label) -> some View where GlobalState: NavigationStackSourceState, GlobalAction: NavigationStackSourceAction, GlobalState: Equatable, GlobalState.NextScreenState == GlobalAction.NextScreenState, Destination: View, Label: View {
    StateDrivenNavigationLink(store: store, state: state, action: action, navDest: navDest, isActive: isActive, initialState: { initialState }, destination: destination, label: label)
}

extension View {
    func stateDrivenNavigationLink<GlobalState, GlobalAction, DestinationState, DestinationAction, Destination>(store: Store<GlobalState, GlobalAction>, state: CasePath<GlobalState.NextScreenState, DestinationState>, action: CasePath<GlobalAction.NextScreenAction, DestinationAction>, navDest: NavigationDestination = .nextInStack, isActive: @escaping (DestinationState) -> Bool, destination: @escaping (Store<DestinationState, DestinationAction>) -> Destination) -> some View where GlobalState: NavigationStackSourceState, GlobalAction: NavigationStackSourceAction, GlobalState: Equatable, GlobalState.NextScreenState == GlobalAction.NextScreenState, Destination: View {
        self.background(StateDrivenNavigationLink(store: store, state: state, action: action, navDest: navDest, isActive: isActive, initialState: { fatalError() }, destination: destination, label: { EmptyView() }))
    }
}

struct NavigationViewChild<Content>: View where Content: View {
    @SwiftUI.Environment(\.nestedNavigationViewHidesBar) private var hideBar: Bool?

    let content: Content

    var body: some View {
        content
            .if(hideBar == true) { view in
                view
                    .navigationBarTitle("sds")
                    .navigationBarHidden(true)
            }
    }
}

extension View {
    var navigationViewChild: NavigationViewChild<Self> {
        NavigationViewChild(content: self)
    }
}

struct NestedNavigationViewHidesBar: EnvironmentKey {
    static let defaultValue: Bool? = nil
}

extension EnvironmentValues {
    var nestedNavigationViewHidesBar: Bool? {
        get { self[NestedNavigationViewHidesBar.self] }
        set { self[NestedNavigationViewHidesBar.self] = newValue }
    }
}
