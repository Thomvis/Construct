//
//  Located.swift
//  Construct
//
//  Created by Thomas Visser on 09/11/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation

struct Located<V> {
    var value: V
    var range: Range<Int>
}

extension Located: Codable where V: Codable { }

extension Located: Equatable where V: Equatable { }
extension Located: Hashable where V: Hashable { }
