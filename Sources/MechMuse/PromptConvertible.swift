//
//  PromptConvertible.swift
//  
//
//  Created by Thomas Visser on 05/12/2022.
//

import Foundation
import OpenAIClient

public protocol PromptConvertible {
    func prompt() -> [ChatMessage]
}
