//
//  Models.swift
//  
//
//  Created by Thomas Visser on 04/12/2022.
//

import Foundation

public enum Model: String, Codable {
    case gpt4 = "gpt-4"
    case gpt35Turbo = "gpt-3.5-turbo"
    case Davinci3 = "text-davinci-003"
    case Curie1 = "text-curie-001"
}
