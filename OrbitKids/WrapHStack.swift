import SwiftUI

struct WrapLayout: Layout {

    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize,
                      subviews: Subviews,
                      cache: inout ()) -> CGSize {

        let maxWidth = proposal.width ?? .infinity
        var width: CGFloat = 0
        var height: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            let proposedWidth = width == 0 ? size.width : width + spacing + size.width

            if proposedWidth > maxWidth {
                width = size.width
                height += rowHeight + spacing
                rowHeight = size.height
            } else {
                width = proposedWidth
                rowHeight = max(rowHeight, size.height)
            }
        }

        height += rowHeight
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect,
                       proposal: ProposedViewSize,
                       subviews: Subviews,
                       cache: inout ()) {

        let maxWidth = bounds.width
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            let proposedX = x == 0 ? size.width : x + spacing + size.width

            if proposedX > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            view.place(
                at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                proposal: ProposedViewSize(size)
            )

            x += x == 0 ? size.width : spacing + size.width
            rowHeight = max(rowHeight, size.height)
        }
    }
}

