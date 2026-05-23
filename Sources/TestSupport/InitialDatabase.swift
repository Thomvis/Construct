//
//  File.swift
//  
//
//  Created by Thomas Visser on 08/10/2022.
//

import Foundation

public enum InitialDatabase {
    public static let path = Bundle.module.path(forResource: "initial", ofType: "sqlite")
    public static let appStore302RichPath = Bundle.module.path(forResource: "appstore-3.0.2-rich", ofType: "sqlite")
}
