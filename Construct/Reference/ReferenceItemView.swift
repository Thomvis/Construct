//
//  ReferenceItemView.swift
//  Construct
//
//  Created by Thomas Visser on 24/10/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import InterposeKit

private var AssociatedObjectHandle: UInt8 = 0

struct ReferenceItemView: View {

    let store: Store<ReferenceItemViewState, ReferenceItemViewAction>

    var body: some View {
        WithViewStore(store, removeDuplicates: { $0.content.typeHash == $1.content.typeHash }) { viewStore in
            NavigationView {
                ZStack {
                    IfLetStore(store.scope(state: { $0.content.homeState }, action: { .contentHome($0) }), then: HomeView.init)

                    IfLetStore(store.scope(state: { $0.content.combatantDetailState }, action: { .contentCombatantDetail($0) }), then: CombatantDetailView.init)

                    IfLetStore(store.scope(state: { $0.content.addCombatantState }, action: { .contentAddCombatant($0) }), then: AddCombatantReferenceItemView.init)
                }
                .navigationBarTitleDisplayMode(.inline)
                .introspectNavigationController { navigationController in
                    // Because the secondary column's UINavigationController is hidden, we add a button to our own NavigationView
                    SidebarButtonInjector.attach(to: navigationController)
                }
            }
            .introspectNavigationController { navigationController in
                print("")
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .environment(\.appNavigation, .tab)
        }
    }

    struct CombatantDetailView: View {
        let store: Store<ReferenceItemViewState.Content.CombatantDetail, ReferenceItemViewAction.CombatantDetail>

        var body: some View {
            WithViewStore(store) { viewStore in
                Construct.CombatantDetailView(store: store.scope(state: { $0.detailState }, action: { .detail($0) }))
                    .id(viewStore.state.selectedCombatantId)
                    .toolbar {
                        ToolbarItemGroup(placement: .primaryAction) {
                            Button(action: {
                                viewStore.send(.previousCombatantTapped)
                            }) {
                                Image(systemName: "chevron.left")
                            }

                            Button(action: {
                                viewStore.send(.togglePinToTurnTapped)
                            }) {
                                Image(systemName: viewStore.state.pinToTurn ? "pin.fill" : "pin.slash")
                            }
                            .disabled(viewStore.state.selectedCombatantId != viewStore.state.runningEncounter?.turn?.combatantId)

                            Button(action: {
                                viewStore.send(.nextCombatantTapped)
                            }) {
                                Image(systemName: "chevron.right")
                            }
                        }
                    }
            }
        }
    }
}

class SidebarButtonInjector: NSObject {
    weak var navigationController: UINavigationController?
    var barButtonItem: UIBarButtonItem!

    var pushItemHook: InterposeKit.AnyHook?
    var viewDidLayoutHook: InterposeKit.AnyHook?

    init(navigationController: UINavigationController) {
        super.init()

        self.navigationController = navigationController
        self.barButtonItem = UIBarButtonItem(image: UIImage(systemName: "sidebar.leading"), style: .plain, target: self, action: #selector(SidebarButtonInjector.onTap))

        // Add button whenever a navigation item is added to the bar
        pushItemHook = try? navigationController.navigationBar.hook(
            #selector(UINavigationBar.pushItem(_:animated:)),
            methodSignature: (@convention(c) (AnyObject, Selector, UINavigationItem, Bool) -> Void).self,
            hookSignature: (@convention(block) (AnyObject, UINavigationItem, Bool) -> Void).self) { store in
            { [weak self] controller, item, animated in
                if let displayMode = self?.splitViewController?.displayMode,
                   let shouldAdd = self?.shouldAddButton(for: displayMode),
                   shouldAdd
                {
                    self?.addBarButton(to: item)
                }
                store.original(controller, store.selector, item, animated)
            }
        }

        // Listen in on layout changes to know when the display mode changes
        viewDidLayoutHook = try! splitViewController?.hook(
            #selector(UIViewController.viewDidLayoutSubviews),
            methodSignature: (@convention(c) (AnyObject, Selector) -> Void).self,
            hookSignature: (@convention(block) (AnyObject) -> Void).self) { store in
            { [weak self] vc in
                store.original(vc, store.selector)
                if let splitVC = vc as? UISplitViewController {
                    self?.splitViewControllerDisplayModeDidChange(splitVC.displayMode)
                }
            }
        }

        if let splitVC = splitViewController {
            splitViewControllerDisplayModeDidChange(splitVC.displayMode)
        }
    }

    deinit {
        _ = try? pushItemHook?.revert()
        _ = try? viewDidLayoutHook?.revert()
    }

    @objc func onTap() {
        splitViewController?.show(.supplementary)
    }

    var splitViewController: UISplitViewController? {
        var parent = navigationController?.parent
        while parent != nil {
            if let splitVC = parent as? UISplitViewController {
                return splitVC
            }
            parent = parent?.parent
        }
        return nil
    }

    func shouldAddButton(for displayMode: UISplitViewController.DisplayMode) -> Bool {
        [.secondaryOnly, .oneOverSecondary, .twoOverSecondary].contains(displayMode)
    }

    /// Add/remove the button from all UINavigationItems accordingly
    func splitViewControllerDisplayModeDidChange(_ displayMode: UISplitViewController.DisplayMode) {
        if shouldAddButton(for: displayMode) {
            addBarButtonItemToAllItems()
        } else {
            removeBarButonItemFromAllItems()
        }
    }

    func addBarButtonItemToAllItems() {
        guard let navigationController = navigationController else { return }
        for item in (navigationController.navigationBar.items ?? []) {
            addBarButton(to: item)
        }
    }

    func addBarButton(to item: UINavigationItem) {
        if item.leftBarButtonItem == nil {
            item.leftItemsSupplementBackButton = true
            item.leftBarButtonItem = barButtonItem
        }
    }

    func removeBarButonItemFromAllItems() {
        guard let navigationController = navigationController else { return }
        for item in (navigationController.navigationBar.items ?? []) {
            item.leftItemsSupplementBackButton = true
            if item.leftBarButtonItem == barButtonItem {
                item.leftBarButtonItem = nil
            }
        }
    }

    static func attach(to navigationController: UINavigationController) {
        let injector = SidebarButtonInjector(navigationController: navigationController)

        objc_setAssociatedObject(navigationController, &AssociatedObjectHandle, injector, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
