//
//  File.swift
//  
//
//  Created by Thomas Visser on 12/12/2023.
//

import Foundation
import Compendium
import GameModels
import IdentifiedCollections
import Helpers

public protocol KeyValueStoreEntityVisitor {
    /// Returns true if the visitor made a change
    func visit(entity: inout any KeyValueStoreEntity) -> Bool
}

//public class UpdateCompendiumSourceDocumentVisitor: AbstractKeyValueStoreEntityVisitor {
//    public init(updatedDocument: CompendiumSourceDocument, originalRealmId: CompendiumRealm.Id, originalDocumentId: CompendiumSourceDocument.Id, moving: Set<CompendiumItemKey>?) {
//        super.init(gameModelsVisitor: UpdateCompendiumSourceDocumentGameModelsVisitor(
//            updatedDocument: updatedDocument,
//            originalRealmId: originalRealmId,
//            originalDocumentId: originalDocumentId,
//            moving: moving
//        ))
//    }
//}

public class ParseableEntityVisitor: AbstractKeyValueStoreEntityVisitor {
    public static let shared = ParseableEntityVisitor()

    public init() {
        super.init(gameModelsVisitor: ParseableGameModelsVisitor())
    }
}

public class AbstractKeyValueStoreEntityVisitor: KeyValueStoreEntityVisitor {

    public let gameModelsVisitor: any GameModelsVisitor

    public init(gameModelsVisitor: any GameModelsVisitor = AbstractGameModelsVisitor()) {
        self.gameModelsVisitor = gameModelsVisitor
    }

    public func visit(entity: inout any KeyValueStoreEntity) -> Bool {
        switch entity {
        case var encounter as Encounter:
            defer { entity = encounter }
            return gameModelsVisitor.visit(encounter: &encounter)
        case var encounter as RunningEncounter:
            defer { entity = encounter }
            return gameModelsVisitor.visit(runningEncounter: &encounter)
        case var entry as CompendiumEntry:
            defer { entity = entry }
            return gameModelsVisitor.visit(entry: &entry)
        case var job as CompendiumImportJob:
            defer { entity = job }
            return gameModelsVisitor.visit(job: &job)
        default:
            return false
        }
    }

}
