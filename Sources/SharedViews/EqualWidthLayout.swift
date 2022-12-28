//
//  EqualWidthLayout.swift
//  
//
//  Created by Thomas Visser on 28/12/2022.
//

import Foundation
import SwiftUI

/// Arranges the subviews by giving them the same width (equal to the widest view)
/// If it has more space than it needs, it centers the views
public struct EqualWidthLayout: Layout {

    let spacing: CGFloat

    public init(spacing: CGFloat = 4) {
        self.spacing = spacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let containerHeight = proposal.replacingUnspecifiedDimensions().height
        let widths = subviews.map { $0.sizeThatFits(.init(width: nil, height: containerHeight)).width }
        cache.maxSubviewWidth = widths.max() ?? proposal.replacingUnspecifiedDimensions().width

        let heights = subviews.map { $0.sizeThatFits(.init(width: cache.maxSubviewWidth, height: nil)).height }
        cache.maxSubviewHeight = heights.max() ?? proposal.replacingUnspecifiedDimensions().height

        return CGSize(width: (cache.maxSubviewWidth+spacing)*CGFloat(subviews.count)-spacing, height: cache.maxSubviewHeight)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        let contentAndSpacingWidth = (cache.maxSubviewWidth+spacing)*CGFloat(subviews.count)-spacing
        let leadingInset = (bounds.width-contentAndSpacingWidth)/2

        let offsetPerSubview = cache.maxSubviewWidth + spacing

        for (idx, subview) in subviews.enumerated() {
            let subviewSize = subview.sizeThatFits(.init(width: cache.maxSubviewWidth, height: nil))
            assert(subviewSize.width.distance(to: cache.maxSubviewWidth) < 1) // if the assert hits, a subview is not flexible enough to grow
            subview.place(
                at: CGPoint(
                    x: bounds.minX + leadingInset + CGFloat(idx) * offsetPerSubview,
                    y: bounds.minY + (bounds.height-subviewSize.height)/2
                ),
                proposal: .init(width: cache.maxSubviewWidth, height: subviewSize.height)
            )
        }
    }

    public func makeCache(subviews: Subviews) -> Cache {
        return Cache(maxSubviewWidth: 0, maxSubviewHeight: 0)
    }

    public struct Cache {
        var maxSubviewWidth: CGFloat
        var maxSubviewHeight: CGFloat
    }
}
