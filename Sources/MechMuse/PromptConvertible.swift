//
//  PromptConvertible.swift
//  
//
//  Created by Thomas Visser on 05/12/2022.
//

import Foundation

public protocol PromptConvertible {
    func prompt(toneOfVoice: ToneOfVoice) -> String
}

public enum ToneOfVoice: String, CaseIterable {
    case comical
    case gritty
}
