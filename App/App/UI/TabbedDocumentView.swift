//
//  TabbedDocumentView.swift
//  Construct
//
//  Created by Thomas Visser on 24/10/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import Introspect
import Tagged

struct TabbedDocumentView<Content>: View where Content: View {

    var items: [TabbedDocumentViewContentItem]
    var content: (TabbedDocumentViewContentItem) -> Content
    @Binding var selection: TabbedDocumentViewContentItem.Id?

    var onAdd: (() -> Void)?
    var onDelete: ((TabbedDocumentViewContentItem.Id) -> Void)?
    var onMove: ((Int, Int) -> Void)?

    var body: some View {

        return VStack(spacing: 0) {
            PageView(itemIds: items.map(\.id), selectedId: $selection.wrappedValue) { id in
                if let item = items.first(where: { $0.id == id }) {
                    content(item)
                }
            }
            .ignoresSafeArea()

            if items.count > 0 {
                Divider()

                TabBar(items: items, selection: $selection) {
                    onAdd?()
                } onDelete: { id in
                    onDelete?(id)
                } onMove: { from, to in
                    onMove?(from, to)
                }
            }

        }.onAppear {
            selection = items.first?.id
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    struct TabBar: View {

        var items: [TabbedDocumentViewContentItem]
        @Binding var selection: TabbedDocumentViewContentItem.Id?

        let onAdd: () -> Void
        let onDelete: (TabbedDocumentViewContentItem.Id) -> Void
        let onMove: (Int, Int) -> Void

        @State private var frames: [TabbedDocumentViewContentItem.Id: CGRect] = [:]

        // Tab dragging
        @State private var dragTarget: TabbedDocumentViewContentItem.Id? = nil
        @State private var dragLocation: CGPoint = .zero
        @State private var dragOffset: CGFloat = 0 // horizontal offset

        @State private var lastDragTarget: TabbedDocumentViewContentItem.Id? = nil

        var body: some View {
            HStack(spacing: 0) {
                ForEach(items, id: \.id) { item in
                    TabBarItemView(label: item.label, selected: Binding(get: {
                        item.id == selection
                    }, set: {
                        if $0 {
                            selection = item.id
                        }
                    }), onDelete: {
                        onDelete(item.id)
                    })
                    .offset(self.offset(for: item))
                    .propagateFrame(id: item.id, coordinateSpace: .named("TabbedDocumentView.TabBar"))
                    .zIndex((item.id == dragTarget || item.id == lastDragTarget) ? 10 : 0)
                    .onTapGesture {
                        selection = item.id
                    }
                    .gesture(item.id != selection
                                ? nil
                                : DragGesture(coordinateSpace: .named("TabbedDocumentView.TabBar"))
                                    .onChanged { value in
                                        withAnimation(.interactiveSpring()) {
                                            dragTarget = item.id
                                            dragOffset = value.translation.width
                                            dragLocation = value.location
                                            lastDragTarget = nil
                                        }
                                    }.onEnded { _ in
                                        withAnimation {
                                            commitDrag()
                                            dragTarget = nil
                                            lastDragTarget = item.id
                                        }
                                    }
                    )
                    .overlay(
                        HStack {
                            Spacer()
                            Divider().ignoresSafeArea(.all, edges: .bottom)
                        }.opacity(addDivider(after: item.id) ? 1.0 : 0.0)
                    )
                }

                Button(action: {
                    onAdd()
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(Color(UIColor.secondaryLabel))
                        .padding(4)
                        .frame(minWidth: 44)
                }
            }
            .coordinateSpace(name: "TabbedDocumentView.TabBar")
            .onPreferenceChange(PropagatedFramesKey<TabbedDocumentViewContentItem.Id>.self) {
                self.frames = $0
            }
            .background(Color(UIColor.systemGray5).ignoresSafeArea(.all, edges: .bottom))
        }

        private func offset(for item: TabbedDocumentViewContentItem) -> CGSize {
            // Early exit if we are not dragging
            guard let dragTarget = self.dragTarget else { return .zero }

            // Early exit for the drag target
            if item.id == dragTarget {
                return CGSize(width: dragOffset, height: 0)
            }

            guard let draggedItemIdx = items.firstIndex(where: { $0.id == dragTarget }),
                  let itemIdx = items.firstIndex(where: { $0.id == item.id }) else {
                assertionFailure("Cannot find involved items in array")
                return .zero
            }

            guard let itemFrame = frames[item.id], let draggedItemFrame = frames[dragTarget] else { return .zero }

            if draggedItemIdx < itemIdx && dragLocation.x > itemFrame.minX {
                return CGSize(width: -draggedItemFrame.width, height:0)
            } else if draggedItemIdx > itemIdx && dragLocation.x < itemFrame.maxX {
                return CGSize(width: draggedItemFrame.width, height: 0)
            }

            return .zero
        }

        /// Calls onMove if needed
        private func commitDrag() {
            guard let dragTarget = dragTarget,
                  let dragTargetIdx = items.firstIndex(where: { $0.id == dragTarget }) else {
                assertionFailure("commitDrag() called outside of the scope of a drag")
                return
            }

            for (idx, item) in items.enumerated().reversed() {
                guard let frame = frames[item.id] else {
                    assertionFailure("Could not find frame for item")
                    continue
                }

                if dragLocation.x > frame.minX {
                    if idx > dragTargetIdx {
                        onMove(dragTargetIdx, idx+1)
                        return
                    } else if idx < dragTargetIdx {
                        onMove(dragTargetIdx, idx)
                        return
                    } else {
                        return // idx == dragTargetIdx, so no move needed
                    }
                }
            }
        }

        private func addDivider(after id: TabbedDocumentViewContentItem.Id) -> Bool {
            guard selection != id,
                  let idx = items.firstIndex(where: { $0.id == id }),
                  idx == items.count-1 || items[idx+1].id != selection else { return false }
            return true
        }
    }

    struct TabBarItemView: View {
        let label: Label<Text, Image>
        @Binding var selected: Bool

        let onDelete: () -> Void

        var body: some View {
            let deleteButton = Button(action: {
                onDelete()
            }) {
                Image(systemName: "xmark.square.fill")
            }

            HStack(spacing: 2) {
                deleteButton.opacity(selected ? 1 : 0)

                label.labelStyle(LabelStyle(selected: selected))
                    .font(.footnote)
                    .frame(maxWidth: .infinity)

                deleteButton.opacity(0)
            }
            .padding(10)
            .frame(minHeight: 32)
            .background(Color(selected ? UIColor.systemGray6 : UIColor.systemGray5).ignoresSafeArea(.all, edges: .bottom))
            .accentColor(Color(UIColor.gray))
        }

        struct LabelStyle: SwiftUI.LabelStyle {
            let selected: Bool

            func makeBody(configuration: Configuration) -> some View {
                HStack {
//                    configuration.icon
//                        .foregroundColor(Color(UIColor.gray))

                    configuration.title
                        .lineLimit(1)
                        .if(selected) { $0.font(Font.footnote.weight(.bold)) }
                        .foregroundColor(Color(selected ? UIColor.label : UIColor.gray))
                }
            }
        }
    }
}

struct TabbedDocumentViewContentItem {
    let id: Id
    let label: Label<Text, Image>

    typealias Id = Tagged<TabbedDocumentViewContentItem, UUID>
}

struct PropagatedFramesKey<ID: Hashable>: PreferenceKey {
    typealias Value = [ID: CGRect]

    static var defaultValue: [ID: CGRect] { [:] }
    static func reduce(value: inout [ID:CGRect], nextValue: () -> [ID:CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct PropagateFrame<V: View, ID: Hashable>: View {
    var content: V
    var id: ID
    var coordinateSpace: CoordinateSpace
    var body: some View {
        content.background(GeometryReader { proxy in
            Color.clear.preference(key: PropagatedFramesKey<ID>.self, value: [self.id: proxy.frame(in: coordinateSpace)])
        })
    }
}

extension View {
    func propagateFrame<ID: Hashable>(id: ID, coordinateSpace: CoordinateSpace) -> some View {
        PropagateFrame(content: self, id: id, coordinateSpace: coordinateSpace)
    }
}

private struct PageView<ID, Content>: UIViewControllerRepresentable where ID: Hashable, Content: View {
    let itemIds: [ID]
    let selectedId: ID?
    let content: (ID) -> Content

    init(itemIds: [ID], selectedId id: ID, @ViewBuilder content: @escaping (ID) -> Content) {
        self.itemIds = itemIds
        self.selectedId = id
        self.content = content
    }

    func makeUIViewController(context: Context) -> VC {
        let vc = VC()
        vc.update(itemIds: itemIds, selection: selectedId.map { ($0, content($0)) })
        return vc
    }

    func updateUIViewController(_ uiViewController: VC, context: Context) {
        uiViewController.update(itemIds: itemIds, selection: selectedId.map { ($0, content($0)) })
    }

    final class VC: UIViewController {
        var cache: [ID: UIHostingController<Content>] = [:] // we cache the vc's to ensure their state is maintained
        var selectedId: ID? // the id of the content view controller currently visible

        func update(itemIds: [ID], selection: (ID, Content)?) {
            // remove cached items that are no longer in the itemIds array
            let cacheKeys = Array(cache.keys)
            for key in cacheKeys where !itemIds.contains(key) {
                cache.removeValue(forKey: key)
            }

            if let (id, contentView) = selection {
                let vc: UIHostingController<Content>
                if let cachedVc = cache[id] {
                    vc = cachedVc
                    vc.rootView = contentView
                } else {
                    vc = UIHostingController(rootView: contentView)
                    cache[id] = vc
                }

                if selectedId != id {
                    removeSelectedViewController()

                    // add view controller
                    addChild(vc)

                    view.addSubview(vc.view)
                    vc.view.translatesAutoresizingMaskIntoConstraints = false
                    vc.view.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
                    vc.view.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
                    vc.view.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
                    vc.view.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true

                    vc.didMove(toParent: self)

                    selectedId = id
                }
            } else {
                // no selection, remove child if present
                removeSelectedViewController()
                selectedId = nil
            }
        }

        private func removeSelectedViewController() {
            if let child = children.first {
                child.willMove(toParent: nil)
                child.view.removeFromSuperview()
                child.removeFromParent()
            }
        }
    }
}
