//
//  Environment.swift
//  
//
//  Created by Thomas Visser on 30/10/2022.
//

import Foundation
import CombineSchedulers
import CustomDump

/// These protocols are only used in a couple of spaces as this was a late-stage idea.
/// I expect these to not really gain momentum, since the latest TCA release has a whole
/// different way of working with environments.

public protocol EnvironmentWithModifierFormatter {
    var modifierFormatter: NumberFormatter { get }
}

public protocol EnvironmentWithMainQueue {
    var mainQueue: AnySchedulerOf<DispatchQueue> { get }
}

public protocol EnvironmentWithSendMail {
    var canSendMail: () -> Bool { get }
    var sendMail: (FeedbackMailContents) -> Void { get }
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

