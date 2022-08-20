//
//  DDBCharacterSheetURLParser.swift
//  Construct
//
//  Created by Thomas Visser on 25/09/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Helpers

class DDBCharacterSheetURLParser {
    // Returns the character id for a given dndbeyond url
    static func parse(_ url: String) -> String? {

        let id = any(character { $0.isWholeNumber })

        let shareUrl = string("https://").optional().followed(by: string("ddb.ac/characters/")).followed(by: id).map { $0.1 }.joined()

        let profileUrl = string("https://").optional().followed(by: string("www.dndbeyond.com/profile/"))
            .followed(by: any(character { $0 != "/" })).followed(by: string("/characters/"))
            .followed(by: id).map { $0.1 }.joined()

        return shareUrl.or(profileUrl).run(url)
    }

}
