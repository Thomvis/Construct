//
//  Models.swift
//  
//
//  Created by Thomas Visser on 04/12/2022.
//

import Foundation

public enum Model: String, Codable {
    /// Current standard GPT-4 model
    case gpt4o = "gpt-4o"
    /// Current standard GPT-3.5 model
    case gpt35Turbo = "gpt-3.5-turbo"
}
