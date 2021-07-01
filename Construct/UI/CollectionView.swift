//
//  ContentView.swift
//  FlowLayoutST
//
//  Created by Chris Eidhof on 22.08.19.
//  Copyright © 2019 Chris Eidhof. All rights reserved.
//
// Copied from https://github.com/objcio/collection-view-swiftui/blob/master/FlowLayoutST/ContentView.swift
// Updated based on https://talk.objc.io/episodes/S01E253-flow-layout-revisited

import SwiftUI

struct FlowLayout {
    let spacing: UIOffset
    let containerWidth: CGFloat

    init(containerWidth: CGFloat, spacing: UIOffset = UIOffset(horizontal: 10, vertical: 10)) {
        self.spacing = spacing
        self.containerWidth = containerWidth
    }

    var currentX = 0 as CGFloat
    var currentY = 0 as CGFloat
    var lineHeight = 0 as CGFloat

    mutating func add(element size: CGSize) -> CGRect {
        if currentX + size.width > containerWidth {
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
        return CGSize(width: containerWidth, height: currentY + lineHeight)
    }
}

func flowLayout<Elements, ID>(for elements: Elements, id: KeyPath<Elements.Element, ID>, containerWidth: CGFloat, sizes: [ID: CGSize]) -> [ID: CGPoint] where Elements: RandomAccessCollection, ID: Hashable {
    var state = FlowLayout(containerWidth: containerWidth)
    var result: [ID: CGPoint] = [:]
    for element in elements {
        let rect = state.add(element: sizes[element[keyPath: id]] ?? .zero)
        result[element[keyPath: id]] = rect.origin
    }
    return result
}

private let containerWidthKey = UUID()
struct CollectionView<Element, ID, Cell>: View where ID: Hashable, Cell: View {

    let data: [Element]
    let id: KeyPath<Element, ID>
    let cell: (Element) -> Cell

    let layout: ([Element], KeyPath<Element, ID>, CGFloat, [ID: CGSize]) -> [ID: CGPoint] = flowLayout

    @State private var sizes: [ID: CGSize] = [:]
    @State private var proposedContainerWidth: CGFloat = 0

    var body: some View {
        let itemPositions = layout(data, id, proposedContainerWidth, sizes)

        return VStack(alignment: .leading, spacing: 0) {
            GeometryReader { proxy in
                Color.clear.preference(key: CollectionViewSizeKey<UUID>.self, value: [containerWidthKey: proxy.size])
            }
            .onPreferenceChange(CollectionViewSizeKey<UUID>.self) {
                self.proposedContainerWidth = $0[containerWidthKey]?.width ?? 0
            }
            .frame(height: 0)

            ZStack(alignment: .topLeading) {
                ForEach(data, id: id) { item in
                    PropagateSize(content: cell(item), id: item[keyPath: id])
                        .alignmentGuide(.leading, computeValue: { dimension in
                            guard let position = itemPositions[item[keyPath: id]] else { return 0 }
                            return -position.x
                        })
                        .alignmentGuide(.top, computeValue: { dimension in
                            guard let position = itemPositions[item[keyPath: id]] else { return 0 }
                            return -position.y
                        })
                }
            }
            .onPreferenceChange(CollectionViewSizeKey<ID>.self) {
                self.sizes = $0
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
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
