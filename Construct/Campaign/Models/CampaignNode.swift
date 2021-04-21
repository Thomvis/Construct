//
//  CampaignNode.swift
//  Construct
//
//  Created by Thomas Visser on 10/10/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import Tagged

struct CampaignNode: Equatable, Codable {
    let id: Id
    var title: String
    let contents: Contents?
    let special: Special?

    var parentKeyPrefix: String?

    typealias Id = Tagged<CampaignNode, UUID>

    struct Contents: Equatable, Codable {
        let key: String
        let type: ContentType

        enum ContentType: String, Codable {
            case encounter
            case other // needed to work around a bug in SwiftUI that causes infinite memory to be used
        }
    }

    enum Special: String, Codable {
        case root
        case scratchPadEncounter
        case trash
    }
}

extension CampaignNode {
    static let root = CampaignNode(id: UUID(uuidString: "990EDB4B-90C7-452A-94AB-3857350B2FA6")!.tagged(), title: "ROOT", contents: nil, special: .root, parentKeyPrefix: nil)
    static let scratchPadEncounter = CampaignNode(id: UUID(uuidString: "14A7E9D3-14B8-46DF-A7F2-3B5DCE16EEA5")!.tagged(), title: "Scratch pad", contents: CampaignNode.Contents(key: Encounter.key(Encounter.scratchPadEncounterId), type: .encounter), special: .scratchPadEncounter, parentKeyPrefix: CampaignNode.root.keyPrefixForChildren)

    var key: String {
        if let parent = parentKeyPrefix {
            return "\(parent)/.\(id)"
        }
        return "cn_.\(id)"
    }

    var keyPrefixForChildren: String {
        if let parent = parentKeyPrefix {
            return "\(parent)/\(id)"
        }
        return "cn_\(id)"
    }

    var keyPrefixForFetchingDirectChildren: String {
        return "\(keyPrefixForChildren)/."
    }
}
