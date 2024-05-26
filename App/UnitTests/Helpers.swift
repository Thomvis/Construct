//
//  Helpers.swift
//  UnitTests
//
//  Created by Thomas Visser on 20/07/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import IdentifiedCollections

extension IdentifiedArray {
    public subscript(position position: Int) -> Element {
        _read { yield self[id: self.ids[position]]! }
        _modify {
            yield &self[id: self.ids[position]]!
        }
    }
}
