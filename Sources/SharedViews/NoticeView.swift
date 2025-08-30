import Foundation
import SwiftUI
import UIKit

public struct Notice: Equatable {
    public let icon: String
    public let message: String
    public let foregroundColor: Color
    public let isDismissible: Bool

    public init(icon: String, message: String, foregroundColor: Color, isDismissible: Bool) {
        self.icon = icon
        self.message = message
        self.foregroundColor = foregroundColor
        self.isDismissible = isDismissible
    }

    public static func error(_ error: Error, isDismissible: Bool = true) -> Notice {
        Notice(
            icon: "exclamationmark.octagon",
            message: error.localizedDescription,
            foregroundColor: Color(UIColor.systemRed),
            isDismissible: isDismissible
        )
    }

    public static func error(_ message: String, isDismissible: Bool = true) -> Notice {
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
    var onDismiss: (() -> Void)?

    public init(notice: Notice, onDismiss: (() -> Void)? = nil) {
        self.notice = notice
        self.onDismiss = onDismiss
    }

    public var body: some View {
        SectionContainer {
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

                if notice.isDismissible {
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
