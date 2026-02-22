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
    public let observeSourceDocuments: () -> AsyncThrowingStream<[CompendiumSourceDocument], Error>
    public let realms: () throws -> [CompendiumRealm]
    public let observeRealms: () -> AsyncThrowingStream<[CompendiumRealm], Error>

    public let putJob: (CompendiumImportJob) throws -> Void

    /// Fails when a realm with the same id already exists
    public let createRealm: (CompendiumRealm) throws -> Void
    /// Fails when the realm does not yet exist
    public let updateRealm: (CompendiumRealm.Id, String) async throws -> Void
    /// Fails when the realm does not exist or if it has any documents
    public let removeRealm: (CompendiumRealm.Id) async throws -> Void

    /// Fails when a document with the same id already exists or if the realm does not exist
    public let createDocument: (CompendiumSourceDocument) throws -> Void
    /// The second and third argument represent the original realm and document id. If they differ, the document and its
    /// content will be moved.
    ///
    /// Fails when the document does not yet exist or if the realm does not exist
    public let updateDocument: (CompendiumSourceDocument, CompendiumRealm.Id, CompendiumSourceDocument.Id) async throws -> Void
    /// Removes a document AND all its content. Fails when the document does not exist
    public let removeDocument: (CompendiumRealm.Id, CompendiumSourceDocument.Id) async throws -> Void

    public init(
        sourceDocuments: @escaping () throws -> [CompendiumSourceDocument],
        observeSourceDocuments: @escaping () -> AsyncThrowingStream<[CompendiumSourceDocument], Error>,
        realms: @escaping () throws -> [CompendiumRealm],
        observeRealms: @escaping () -> AsyncThrowingStream<[CompendiumRealm], Error>,
        putJob: @escaping (CompendiumImportJob) throws -> Void,
        createRealm: @escaping (CompendiumRealm) throws -> Void,
        updateRealm: @escaping (CompendiumRealm.Id, String) async throws -> Void,
        removeRealm: @escaping (CompendiumRealm.Id) async throws -> Void,
        createDocument: @escaping (CompendiumSourceDocument) throws -> Void,
        updateDocument: @escaping (CompendiumSourceDocument, CompendiumRealm.Id, CompendiumSourceDocument.Id) async throws -> Void,
        removeDocument: @escaping (CompendiumRealm.Id, CompendiumSourceDocument.Id) async throws -> Void
    ) {
        self.sourceDocuments = sourceDocuments
        self.observeSourceDocuments = observeSourceDocuments
        self.realms = realms
        self.observeRealms = observeRealms

        self.putJob = putJob

        self.createRealm = createRealm
        self.updateRealm = updateRealm
        self.removeRealm = removeRealm

        self.createDocument = createDocument
        self.updateDocument = updateDocument
        self.removeDocument = removeDocument
    }
}

extension CompendiumMetadata {
    func createOrUpdateRealm(_ realm: CompendiumRealm) async throws {
        do {
            try createRealm(realm)
        } catch {
            try await updateRealm(realm.id, realm.displayName)
        }
    }

    func createOrUpdateDocument(_ document: CompendiumSourceDocument) async throws {
        do {
            try createDocument(document)
        } catch {
            try await updateDocument(document, document.realmId, document.id)
        }
    }
}

public enum CompendiumMetadataError: Error {
    case resourceAlreadyExists
    case resourceNotFound
    case invalidRealmId
    case resourceNotEmpty
    case cannotMoveDefaultResource
}

public extension CompendiumMetadata {
    func importDefaultContent() async throws {
        // Documents & Realms
        try await createOrUpdateRealm(CompendiumRealm.core)
        try await createOrUpdateRealm(CompendiumRealm.core2024)
        try await createOrUpdateRealm(CompendiumRealm.homebrew)
        try await createOrUpdateDocument(CompendiumSourceDocument.srd5_1)
        try await createOrUpdateDocument(CompendiumSourceDocument.srd5_2)
        try await createOrUpdateDocument(CompendiumSourceDocument.homebrew)
    }
}
