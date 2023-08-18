//
//  CompendiumMetadata.swift
//  Construct
//
//  Created by Thomas Visser on 26/07/2023.
//  Copyright © 2023 Thomas Visser. All rights reserved.
//

import Foundation
import GameModels

public struct CompendiumMetadata {
    public let sourceDocuments: () throws -> [CompendiumSourceDocument]
    public let realms: () throws -> [CompendiumRealm]

    public let putRealm: (CompendiumRealm) throws -> Void
    public let putDocument: (CompendiumSourceDocument) throws -> Void
    public let putJob: (CompendiumImportJob) throws -> Void

    public init(
        sourceDocuments: @escaping () throws -> [CompendiumSourceDocument],
        realms: @escaping () throws -> [CompendiumRealm],
        putRealm: @escaping (CompendiumRealm) throws -> Void,
        putDocument: @escaping (CompendiumSourceDocument) throws -> Void,
        putJob: @escaping (CompendiumImportJob) throws -> Void
    ) {
        self.sourceDocuments = sourceDocuments
        self.realms = realms
        self.putRealm = putRealm
        self.putDocument = putDocument
        self.putJob = putJob
    }
}
