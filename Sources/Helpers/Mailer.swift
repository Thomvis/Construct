import Foundation
import MessageUI
import UIKit
import ComposableArchitecture

public struct Mailer {
    public var canSendMail: () -> Bool
    public var sendMail: (FeedbackMailContents) -> Void
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
