import Foundation
import GameModels

func compendiumSourceDocumentUpdateVisitors(
    originalDocumentKey: CompendiumSourceDocumentKey,
    originalImportJobIds: Set<CompendiumImportJob.Id>? = nil,
    targetDocument: CompendiumSourceDocument,
    updatedItemReference: ((CompendiumItemKey) -> CompendiumItemKey?)? = nil
) -> [KeyValueStoreEntityVisitor] {
    Array {
        AbstractKeyValueStoreEntityVisitor(gameModelsVisitor: UpdateEntryDocumentGameModelsVisitor(
            originalDocumentKey: originalDocumentKey,
            targetDocument: targetDocument
        ))

        if targetDocument.id != originalDocumentKey.documentId {
            AbstractKeyValueStoreEntityVisitor(gameModelsVisitor: UpdateImportJobDocumentGameModelsVisitor(
                originalDocumentId: originalDocumentKey.documentId,
                originalJobIds: originalImportJobIds,
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
