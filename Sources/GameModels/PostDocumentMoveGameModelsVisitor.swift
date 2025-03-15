import Foundation
import Helpers

/// Updates the compendium after a document has moved
/// Updates references from other entities (e.g. a reference from an encounter to a creature) to the items that moved.
public class PostDocumentMoveGameModelsVisitor: AbstractGameModelsVisitor {
    let updatedDocument: CompendiumSourceDocument
    let originalRealmId: CompendiumRealm.Id
    let originalDocumentId: CompendiumSourceDocument.Id
    let moving: Set<CompendiumItemKey>?

    var documentIdDidChange: Bool { updatedDocument.id != originalDocumentId }
    var didMoveBetweenRealms: Bool { updatedDocument.realmId != originalRealmId }

    public init(
        updatedDocument: CompendiumSourceDocument,
        originalRealmId: CompendiumRealm.Id,
        originalDocumentId: CompendiumSourceDocument.Id,
        moving: Set<CompendiumItemKey>?
    ) {
        self.updatedDocument = updatedDocument
        self.originalRealmId = originalRealmId
        self.originalDocumentId = originalDocumentId
        self.moving = moving

        precondition(updatedDocument.realmId == originalRealmId || moving != nil, "`moving` needs to be non-nil if we're moving between realms")
    }

    @VisitorBuilder
    override public func visit(entry: inout CompendiumEntry) -> Bool {
        super.visit(entry: &entry)

        if entry.document.id == originalDocumentId {
            // Entry belongs in document
            visitValue(&entry, keyPath: \.document.displayName, value: updatedDocument.displayName)
            visitValue(&entry, keyPath: \.document.id, value: updatedDocument.id)

            if didMoveBetweenRealms {
                // The document moved between realms and this item needs to move with it.
                // We update the realm in the item. This will update the entry's key
                // in the key value store, which is handled by the visitor manager.
                visitValue(&entry, keyPath: \.item.realm, value: .init(updatedDocument.realmId))
            }
        }
    }

    @VisitorBuilder
    override public func visit(job: inout CompendiumImportJob) -> Bool {
        super.visit(job: &job)

        if job.documentId == originalDocumentId && documentIdDidChange {
            job.documentId = updatedDocument.id
            true
        }
    }

    @VisitorBuilder
    public override func visit(compendiumCombatantDefinition def: inout CompendiumCombatantDefinition) -> Bool {
        super.visit(compendiumCombatantDefinition: &def)

        if didMoveBetweenRealms, let moving, moving.contains(def.item.key) {
            let key = CompendiumItemKey(
                type: def.item.key.type,
                realm: .init(updatedDocument.realmId),
                identifier: def.item.key.identifier
            )
            switch def.item {
            case var monster as Monster:
                visitValue(&monster, keyPath: \.key, value: key)
                def.item = monster
            case var character as Character:
                visitValue(&character, keyPath: \.key, value: key)
                def.item = character
            default:
                assertionFailure("Unexpected CompendiumCombatant in visitor")
            }
        }
    }

    override public func visit(itemReference: inout CompendiumItemReference) -> Bool {
        if didMoveBetweenRealms, let moving, moving.contains(itemReference.itemKey) {
            itemReference.itemKey = CompendiumItemKey(
                type: itemReference.itemKey.type,
                realm: .init(updatedDocument.realmId),
                identifier: itemReference.itemKey.identifier
            )
            return true
        }

        return false
    }
}
