//
//  PromptConvertible.swift
//  
//
//  Created by Thomas Visser on 05/12/2022.
//

import Foundation
import OpenAI

public protocol PromptConvertible {
    func prompt() -> [ChatQuery.ChatCompletionMessageParam]
}
