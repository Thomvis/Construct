import Foundation
import GameModels

func compendiumSourceDocumentUpdateVisitors(
    originalDocumentId: CompendiumSourceDocument.Id,
    targetDocument: CompendiumSourceDocument,
    updatedItemReference: ((CompendiumItemKey) -> CompendiumItemKey?)? = nil
) -> [KeyValueStoreEntityVisitor] {
    Array {
        AbstractKeyValueStoreEntityVisitor(gameModelsVisitor: UpdateEntryDocumentGameModelsVisitor(
            originalDocumentId: originalDocumentId,
            targetDocument: targetDocument
        ))

        if targetDocument.id != originalDocumentId {
            AbstractKeyValueStoreEntityVisitor(gameModelsVisitor: UpdateImportJobDocumentGameModelsVisitor(
                originalDocumentId: originalDocumentId,
                updatedDocumentId: targetDocument.id
            ))
        }

        if let updatedItemReference {
            AbstractKeyValueStoreEntityVisitor(gameModelsVisitor: UpdateItemReferenceGameModelsVisitor(
                updatedKey: updatedItemReference
            ))
        }
    }
}
