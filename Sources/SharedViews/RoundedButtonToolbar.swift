//
//  RoundedButtonToolbar.swift
//  
//
//  Created by Thomas Visser on 17/09/2022.
//

import Foundation
import SwiftUI

public struct RoundedButtonToolbar<Content>: View where Content: View {
    let content: () -> Content

    let buttonColor = Color(UIColor.systemGray4)

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        RoundedButtonToolbarLayout()
            .callAsFunction(content)
            .buttonStyle(RoundedButtonStyle(color: buttonColor, maxHeight: .infinity))
    }
}

private struct RoundedButtonToolbarLayout: Layout {

    // We cache the height
    public typealias Cache = CGFloat

    let spacing: CGFloat

    public init(spacing: CGFloat = 4) {
        self.spacing = spacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout CGFloat) -> CGSize {
        let containerWidth = proposal.replacingUnspecifiedDimensions().width
        let subviewWidth = ceil(containerWidth - CGFloat(subviews.count-1)*spacing)/CGFloat(subviews.count)
        let heights = subviews.map { $0.sizeThatFits(.init(width: subviewWidth, height: nil)).height }
        cache = heights.max() ?? proposal.replacingUnspecifiedDimensions().height
        return CGSize(width: containerWidth, height: cache)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout CGFloat) {
        let subviewWidth = (bounds.width - CGFloat(subviews.count-1)*spacing)/CGFloat(subviews.count)
        let offsetPerSubview = subviewWidth + spacing

        for (idx, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(
                    x: bounds.minX + CGFloat(idx) * offsetPerSubview,
                    y: bounds.minY
                ),
                proposal: .init(width: subviewWidth, height: cache)
            )
        }
    }

    public func makeCache(subviews: Subviews) -> CGFloat {
        return 0
    }
}
