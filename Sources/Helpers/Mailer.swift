import Foundation
import MessageUI
import UIKit
import ComposableArchitecture

public struct Mailer {
    public var canSendMail: () -> Bool
    public var sendMail: (FeedbackMailContents) -> Void
}

public struct FeedbackMailContents {
    public let subject: String
    public let attachments: [Attachment]

    public init(subject: String = "Construct Feedback", attachment: [Attachment] = []) {
        self.subject = subject
        self.attachments = attachment
    }

    public struct Attachment {
        public let data: Data
        public let mimeType: String
        public let fileName: String

        public init(data: Data, mimeType: String, fileName: String) {
            self.data = data
            self.mimeType = mimeType
            self.fileName = fileName
        }

        public init?<C>(encoding value: C) where C: Encodable {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted

            guard let data = try? encoder.encode(value) else { return nil }
            self.data = data
            self.mimeType = "application/json"
            self.fileName = "\(type(of: value)).json"
        }

        public init?(customDump value: Any) {
            var result = ""
            customDump(value, to: &result)

            guard let data = result.data(using: .utf8) else { return nil }
            self.data = data
            self.mimeType = "text/plain;charset=UTF-8"
            self.fileName = "\(type(of: value)).txt"
        }
    }
}

private class MailComposeDelegate: NSObject, MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }
}

fileprivate let mailComposeDelegate = MailComposeDelegate()
extension Mailer: DependencyKey {
    public static var liveValue: Mailer = Mailer(
        canSendMail: { MFMailComposeViewController.canSendMail() },
        sendMail: { contents in
            let composeVC = MFMailComposeViewController()
            composeVC.mailComposeDelegate = mailComposeDelegate

            // Configure the fields of the interface.
            composeVC.setToRecipients(["hello@construct5e.app"])
            composeVC.setSubject(contents.subject)

            for attachment in contents.attachments {
                composeVC.addAttachmentData(
                    attachment.data,
                    mimeType: attachment.mimeType,
                    fileName: attachment.fileName
                )
            }

            // Present the view controller modally.
            let keyWindow = {
                UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .flatMap { $0.windows }
                    .filter(\.isKeyWindow)
                    .first
            }

            keyWindow()?.rootViewController?.deepestPresentedViewController.present(composeVC, animated: true, completion:nil)
        }
    )
}

public extension DependencyValues {
    var mailer: Mailer {
        get { self[Mailer.self] }
        set { self[Mailer.self] = newValue }
    }
}

public extension UIViewController {
    var deepestPresentedViewController: UIViewController {
        presentedViewController?.deepestPresentedViewController ?? self
    }
}
