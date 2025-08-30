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
        let totalSpacing = CGFloat(subviews.count - 1) * spacing
        let availableWidth = bounds.width - totalSpacing
        let equalWidth = availableWidth / CGFloat(subviews.count)
        
        // First pass: determine actual widths for each subview
        var subviewWidths: [CGFloat] = []
        var fixedWidth: CGFloat = 0
        var flexibleViewCount = 0
        
        for subview in subviews {
            let actualSize = subview.sizeThatFits(.init(width: equalWidth, height: cache))
            let actualWidth = actualSize.width
            
            subviewWidths.append(actualWidth)
            
            // If the actual width is significantly different from equal width,
            // consider it a fixed-width view
            if abs(actualWidth - equalWidth) > 1 {
                fixedWidth += actualWidth
            } else {
                flexibleViewCount += 1
            }
        }
        
        // Calculate width for flexible views
        let remainingWidth = availableWidth - fixedWidth
        let flexibleWidth = flexibleViewCount > 0 ? remainingWidth / CGFloat(flexibleViewCount) : 0
        
        // Second pass: adjust widths for flexible views
        for i in 0..<subviewWidths.count {
            if abs(subviewWidths[i] - equalWidth) <= 1 {
                subviewWidths[i] = flexibleWidth
            }
        }
        
        // Place subviews with calculated widths
        var currentX = bounds.minX
        for (idx, subview) in subviews.enumerated() {
            let width = subviewWidths[idx]
            
            subview.place(
                at: CGPoint(x: currentX, y: bounds.minY),
                proposal: .init(width: width, height: cache)
            )
            
            currentX += width + spacing
        }
    }

    public func makeCache(subviews: Subviews) -> CGFloat {
        return 0
    }
}
