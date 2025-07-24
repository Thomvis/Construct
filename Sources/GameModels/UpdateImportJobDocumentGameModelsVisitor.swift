import Foundation
import Helpers

public class UpdateImportJobDocumentGameModelsVisitor: AbstractGameModelsVisitor {
    let originalDocumentId: CompendiumSourceDocument.Id
    let updatedDocumentId: CompendiumSourceDocument.Id
    
    public init(originalDocumentId: CompendiumSourceDocument.Id, updatedDocumentId: CompendiumSourceDocument.Id) {
        self.originalDocumentId = originalDocumentId
        self.updatedDocumentId = updatedDocumentId
    }
    
    @VisitorBuilder
    override public func visit(job: inout CompendiumImportJob) -> Bool {
        if job.documentId == originalDocumentId {
            visitValue(&job, keyPath: \.documentId, value: updatedDocumentId)
        }
    }
} 