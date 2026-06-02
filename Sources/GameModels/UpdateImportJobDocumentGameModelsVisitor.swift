import Foundation
import Helpers
import Tagged

public class UpdateImportJobDocumentGameModelsVisitor: AbstractGameModelsVisitor {
    let originalDocumentId: CompendiumSourceDocument.Id
    let originalJobIds: Set<CompendiumImportJob.Id>?
    let updatedDocumentId: CompendiumSourceDocument.Id
    
    public init(
        originalDocumentId: CompendiumSourceDocument.Id,
        originalJobIds: Set<CompendiumImportJob.Id>? = nil,
        updatedDocumentId: CompendiumSourceDocument.Id
    ) {
        self.originalDocumentId = originalDocumentId
        self.originalJobIds = originalJobIds
        self.updatedDocumentId = updatedDocumentId
    }
    
    @VisitorBuilder
    override public func visit(job: inout CompendiumImportJob) -> Bool {
        if job.documentId == originalDocumentId
            && (originalJobIds?.contains(job.id) ?? true) {
            visitValue(&job, keyPath: \.documentId, value: updatedDocumentId)
        }
    }
}
