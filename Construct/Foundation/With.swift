//
//  With.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 02/01/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI

func with<A, View>(_ a: A, @ViewBuilder view: (A) -> View) -> View {
    return view(a)
}

func with<A, B, View>(_ a: A, _ b: B, @ViewBuilder view: (A, B) -> View) -> View {
    return view(a, b)
}

func with<A, B, C, View>(_ a: A, _ b: B, _ c: C, @ViewBuilder view: (A, B, C) -> View) -> View {
    return view(a, b, c)
}
