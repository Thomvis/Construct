//
//  AnyCodingKey.swift
//  
//
//  Created by Thomas Visser on 03/11/2022.
//

import Foundation

public struct AnyCodingKey: CodingKey, Equatable {
    public var stringValue: String
    public var intValue: Int?

    public init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    public init(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }    
}
