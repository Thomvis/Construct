//
//  ExternalCompendium.swift
//  Construct
//
//  Created by Thomas Visser on 30/11/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation

protocol ExternalCompendium {
    func url(for referenceAnnotation: CompendiumItemReferenceTextAnnotation) -> URL?

    func searchPageUrl(for query: String, types: [CompendiumItemType]?) -> URL
}
