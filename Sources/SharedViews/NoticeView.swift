import Foundation
import SwiftUI
import UIKit

public struct Notice: Equatable {
    public let icon: String
    public let message: AttributedString
    public let foregroundColor: Color
    public let isDismissible: Bool

    public init(icon: String, message: AttributedString, foregroundColor: Color, isDismissible: Bool) {
        self.icon = icon
        self.message = message
        self.foregroundColor = foregroundColor
        self.isDismissible = isDismissible
    }

    public static func error(_ error: Error, isDismissible: Bool = true) -> Notice {
        .error(AttributedString(error.localizedDescription), isDismissible: isDismissible)
    }

    public static func error(_ message: String, isDismissible: Bool = true) -> Notice {
        .error(AttributedString(message), isDismissible: isDismissible)
    }

    public static func error(_ message: AttributedString, isDismissible: Bool = true) -> Notice {
        Notice(
            icon: "exclamationmark.octagon",
            message: message,
            foregroundColor: Color(UIColor.systemRed),
            isDismissible: isDismissible
        )
    }
}

public struct NoticeView: View {
    let notice: Notice
    let backgroundColor: Color
    var onDismiss: (() -> Void)?

    public init(
        notice: Notice,
        backgroundColor: Color = Color(UIColor.secondarySystemBackground),
        onDismiss: (() -> Void)? = nil
    ) {
        self.notice = notice
        self.backgroundColor = backgroundColor
        self.onDismiss = onDismiss
    }

    public var body: some View {
        SectionContainer(backgroundColor: backgroundColor) {
            VStack(alignment: notice.isDismissible ? .trailing : .leading) {
                HStack(spacing: 12) {
                    Text(Image(systemName: notice.icon))
                    Text(notice.message)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(8)
                .foregroundStyle(notice.foregroundColor)
                .symbolRenderingMode(.monochrome)
                .symbolVariant(.fill)

                if notice.isDismissible && onDismiss != nil {
                    Text("Tap to dismiss")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .transition(.scale.combined(with: .opacity))
        .onTapGesture {
            if notice.isDismissible {
                onDismiss?()
            }
        }
    }
}
