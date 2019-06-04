//
//  ContentView.swift
//  FlowLayoutST
//
//  Created by Chris Eidhof on 22.08.19.
//  Copyright © 2019 Chris Eidhof. All rights reserved.
//
// Copied from https://github.com/objcio/collection-view-swiftui/blob/master/FlowLayoutST/ContentView.swift

import SwiftUI

struct FlowLayout {
    let spacing: UIOffset
    let containerSize: CGSize

    init(containerSize: CGSize, spacing: UIOffset = UIOffset(horizontal: 10, vertical: 10)) {
        self.spacing = spacing
        self.containerSize = containerSize
    }

    var currentX = 0 as CGFloat
    var currentY = 0 as CGFloat
    var lineHeight = 0 as CGFloat

    mutating func add(element size: CGSize) -> CGRect {
        if currentX + size.width > containerSize.width {
            currentX = 0
            currentY += lineHeight + spacing.vertical
            lineHeight = 0
        }
        defer {
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing.horizontal
        }
        return CGRect(origin: CGPoint(x: currentX, y: currentY), size: size)
    }

    var size: CGSize {
        return CGSize(width: containerSize.width, height: currentY + lineHeight)
    }
}

func flowLayout<Elements, ID>(for elements: Elements, id: KeyPath<Elements.Element, ID>, containerSize: CGSize, sizes: [ID: CGSize]) -> [ID: CGSize] where Elements: RandomAccessCollection, ID: Hashable {
    var state = FlowLayout(containerSize: containerSize)
    var result: [ID: CGSize] = [:]
    for element in elements {
        let rect = state.add(element: sizes[element[keyPath: id]] ?? .zero)
        result[element[keyPath: id]] = CGSize(width: rect.origin.x, height: rect.origin.y)
    }
    return result
}


func singleLineLayout<Elements>(for elements: Elements, containerSize: CGSize, sizes: [Elements.Element.ID: CGSize]) -> [Elements.Element.ID: CGSize] where Elements: RandomAccessCollection, Elements.Element: Identifiable {
    var result: [Elements.Element.ID: CGSize] = [:]
    var offset = CGSize.zero
    for element in elements {
        result[element.id] = offset
        let size = sizes[element.id] ?? CGSize.zero
        offset.width += size.width + 10
    }
    return result
}


struct CollectionView<Elements, ID, Content>: View where Elements: RandomAccessCollection, ID: Hashable, Content: View {
    let uuid = UUID()
    var data: Elements
    var id: KeyPath<Elements.Element, ID>
    var layout: (Elements, KeyPath<Elements.Element, ID>, CGSize, [ID: CGSize]) -> [ID: CGSize]
    var content: (Elements.Element) -> Content
    @State private var sizes: [ID: CGSize] = [:]
    @State private var contentSize: CGSize? = nil

    private func bodyHelper(containerSize: CGSize, offsets: [ID: CGSize]) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(data, id: id) {
                PropagateSize(content: self.content($0), id: $0[keyPath: self.id])
                    .offset(offsets[$0[keyPath: self.id]] ?? CGSize.zero)
            }
            Color.clear
                .frame(width: containerSize.width, height: contentSize(offsets: offsets, sizes: sizes).height)
                .fixedSize()
                .preference(key: CollectionViewSizeKey<UUID>.self, value: [uuid: contentSize(offsets: offsets, sizes: sizes)])
        }.onPreferenceChange(CollectionViewSizeKey<ID>.self) {
            self.sizes = $0
        }
    }

    func contentSize(offsets: [ID: CGSize], sizes: [ID: CGSize]) -> CGSize {
        var contentSize: CGSize = .zero
        for id in offsets.keys {
            guard let offset = offsets[id], let size = sizes[id] else { continue }
            let maxX = offset.width + size.width
            let maxY = offset.height + size.height
            if maxX > contentSize.width {
                contentSize.width = maxX
            }
            if maxY > contentSize.height {
                contentSize.height = maxY
            }
        }
        return contentSize
    }

    var body: some View {
        GeometryReader { proxy in
            self.bodyHelper(containerSize: proxy.size, offsets: self.layout(self.data, self.id, proxy.size, self.sizes))
        }.onPreferenceChange(CollectionViewSizeKey<UUID>.self) {
            self.contentSize = $0[self.uuid]
        }.frame(height: self.contentSize?.height)
    }
}

struct CollectionViewSizeKey<ID: Hashable>: PreferenceKey {
    typealias Value = [ID: CGSize]

    static var defaultValue: [ID: CGSize] { [:] }
    static func reduce(value: inout [ID:CGSize], nextValue: () -> [ID:CGSize]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct PropagateSize<V: View, ID: Hashable>: View {
    var content: V
    var id: ID
    var body: some View {
        content.background(GeometryReader { proxy in
            Color.clear.preference(key: CollectionViewSizeKey<ID>.self, value: [self.id: proxy.size])
        })
    }
}
