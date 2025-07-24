import Foundation
import Helpers

public class UpdateEntryDocumentGameModelsVisitor: AbstractGameModelsVisitor {

    /// If non-nil, only entries from this document are updated
    let originalDocumentId: CompendiumSourceDocument.Id?
    let targetDocument: CompendiumSourceDocument

    public init(
        originalDocumentId: CompendiumSourceDocument.Id?,
        targetDocument: CompendiumSourceDocument
    ) {
        self.originalDocumentId = originalDocumentId
        self.targetDocument = targetDocument
    }

    @VisitorBuilder
    override public func visit(entry: inout CompendiumEntry) -> Bool {
        super.visit(entry: &entry)

        if !(entry.item is CompendiumItemGroup) {
            if originalDocumentId == nil || entry.document.id == originalDocumentId {
                visitValue(&entry, keyPath: \.document.displayName, value: targetDocument.displayName)
                visitValue(&entry, keyPath: \.document.id, value: targetDocument.id)
                visitValue(&entry, keyPath: \.item.realm, value: .init(targetDocument.realmId))
            }
        }
    }
} 
