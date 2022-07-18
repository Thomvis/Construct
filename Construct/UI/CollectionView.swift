//
//  ContentView.swift
//  FlowLayoutST
//
//  Created by Chris Eidhof on 22.08.19.
//  Copyright © 2019 Chris Eidhof. All rights reserved.
//
// Copied from https://github.com/objcio/collection-view-swiftui/blob/master/FlowLayoutST/ContentView.swift
// Updated based on https://talk.objc.io/episodes/S01E253-flow-layout-revisited
// And then some

import SwiftUI

struct FlowLayout: CollectionViewLayout {
    let spacing: CGSize
    let alignment: HorizontalAlignment

    var horizontalAlignment: HorizontalAlignment {
        alignment
    }

    init(spacing: CGSize = CGSize(width: 10, height: 10), alignment: HorizontalAlignment = .leading) {
        self.spacing = spacing
        self.alignment = alignment
    }

    func layout<Elements, ID>(for elements: Elements, id: KeyPath<Elements.Element, ID>, containerWidth: CGFloat, sizes: [ID : CGSize]) -> [ID : CGPoint] where Elements : RandomAccessCollection, ID : Hashable {

        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        var result: [ID: CGPoint] = [:]
        var line: [(ID, CGRect)] = []

        // Writes the current line to the results dictionary, aligning if needed
        func finishLine() {
            switch alignment {
            case .leading:
                for (id, rect) in line {
                    result[id] = rect.origin
                }
            case .trailing:
                let lineWidth = line.map { $0.1.width }.reduce(0, +) + CGFloat(line.count-1)*spacing.width
                let emptySpace = containerWidth - lineWidth
                for (id, rect) in line {
                    result[id] = rect.origin.offset(dx: emptySpace)
                }
            default: assertionFailure("FlowLayout does not support \(alignment) alignment")
            }

            currentX = 0
            currentY += lineHeight + spacing.height
            lineHeight = 0

            line.removeAll()
        }

        // Adds the next element
        func add(element: Elements.Element, size: CGSize) {
            if currentX + size.width > containerWidth && !line.isEmpty {
                finishLine()
            }
            defer {
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing.width
            }

            let rect = CGRect(origin: CGPoint(x: currentX, y: currentY), size: size)
            line.append((element[keyPath: id], rect))
        }

        for element in elements {
            add(element: element, size: sizes[element[keyPath: id]] ?? .zero)
        }
        finishLine()

        return result
    }
}

protocol CollectionViewLayout {
    var horizontalAlignment: HorizontalAlignment { get }

    func layout<Elements, ID>(for elements: Elements, id: KeyPath<Elements.Element, ID>, containerWidth: CGFloat, sizes: [ID: CGSize]) -> [ID: CGPoint] where Elements: RandomAccessCollection, ID: Hashable
}

private let containerWidthKey = UUID()
struct CollectionView<Element, ID, Cell>: View where ID: Hashable, Cell: View {

    let layout: CollectionViewLayout

    let data: [Element]
    let id: KeyPath<Element, ID>
    let cell: (Element) -> Cell

    @State private var sizes: [ID: CGSize] = [:]
    @State private var proposedContainerWidth: CGFloat = 0

    var body: some View {
        let itemPositions = layout.layout(for: data, id: id, containerWidth: proposedContainerWidth, sizes: sizes)

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
            .frame(minWidth: 0, maxWidth: .infinity, alignment: alignment)
        }
    }

    var alignment: SwiftUI.Alignment {
        SwiftUI.Alignment(horizontal: layout.horizontalAlignment, vertical: .top)
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
