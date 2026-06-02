import Foundation
import Helpers

public class UpdateEntryDocumentGameModelsVisitor: AbstractGameModelsVisitor {

    /// If non-nil, only entries from this document are updated
    let originalDocumentKey: CompendiumSourceDocumentKey?
    let targetDocument: CompendiumSourceDocument

    public init(
        originalDocumentKey: CompendiumSourceDocumentKey?,
        targetDocument: CompendiumSourceDocument
    ) {
        self.originalDocumentKey = originalDocumentKey
        self.targetDocument = targetDocument
    }

    @VisitorBuilder
    override public func visit(entry: inout CompendiumEntry) -> Bool {
        super.visit(entry: &entry)

        if !(entry.item is CompendiumItemGroup) {
            if originalDocumentKey == nil || entry.sourceDocumentKey == originalDocumentKey {
                visitValue(&entry, keyPath: \.document.displayName, value: targetDocument.displayName)
                visitValue(&entry, keyPath: \.document.id, value: targetDocument.id)
                visitValue(&entry, keyPath: \.item.realm, value: .init(targetDocument.realmId))
            }
        }
    }
} 
