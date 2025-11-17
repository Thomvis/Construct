//
//  CompendiumImportFeature.swift
//  Construct
//
//  Created by Thomas Visser on 18/06/2023.
//  Copyright © 2023 Thomas Visser. All rights reserved.
//

import ComposableArchitecture
import Foundation
import SwiftUI
import Tagged
import Helpers
import Open5eAPI
import Combine
import GameModels
import Persistence
import Compendium
import SharedViews

struct CompendiumImportFeature: ReducerProtocol {
    struct State: Equatable {
        var phase: Phase = .dataSourcePreferences

        var dataSources: IdentifiedArrayOf<DataSource.State> = [
            .init(
                title: "Open5e",
                description: "Open5e aims to be the best open-source resource for 5e content",
                icon: .open5e,
                preferences: .open5e(.init())
            ),
            .init(
                title: "File",
                description: "Read content from a file on your device",
                icon: .file,
                preferences: .file(.init())
            ),
            .init(
                title: "Network",
                description: "Load content from the network",
                icon: .network,
                preferences: .network(.init())
            )
        ]
        var selectedDataSourceId: DataSource.State.Id? = nil
        var selectedDataSource: DataSource.State? {
            selectedDataSourceId.flatMap { dataSources[id: $0] }
        }

        @BindingState var importSettings = ImportSettings.State()

        // we use Async just for state storage, not its reducer
        var importResult: Async<CompendiumImporter.Result, Error>.State = .initial
        @PresentationState var alert: AlertState<Never>?
        var dismiss = false

        var isValid: Bool {
            (selectedDataSource?.preferences.isValid).orFalse && importSettings.isValid
        }

        enum Phase: Equatable {
            case dataSourcePreferences
            case importSettings
        }
    }

    enum Action: Equatable, BindableAction {
        case onAppear
        case didSelectDataSource(DataSource.State.Id)
        case dataSource(DataSource.State.Id, DataSource.Action)
        case didTapNextButton
        case didTapClearDataSourceSelectionButton
        case importSettings(ImportSettings.Action)
        case didTapImportButton
        case importDidFinish(CompendiumImporter.Result?)
        case alert(PresentationAction<Never>)

        case binding(BindingAction<State>)
    }

    enum Error: Swift.Error {
        case importTaskCreationFailed
        case importFailed
    }

    @Dependency(\.compendium) var compendium
    @Dependency(\.compendiumMetadata) var compendiumMetadata

    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    await send(.importSettings(.documents(.startLoading)))
                    await send(.importSettings(.realms(.startLoading)))
                }
            case .didSelectDataSource(let id):
                state.selectedDataSourceId = id
                state.phase = .dataSourcePreferences
            case .dataSource: break
            case .didTapNextButton:
                guard state.isDataSourceConfigured else { break }

                let dataSource = state.selectedDataSource

                if !state.importSettings.setSuggestedDocument(dataSource?.preferences.suggestedSourceName ?? "") {
                    _ = state.importSettings.setSuggestedRealm(dataSource?.preferences.suggestedRealmName ?? "")
                }

                state.importSettings.readerForDataSource = dataSource?.preferences.correspondingDataSourceReader

                state.phase = .importSettings
            case .didTapClearDataSourceSelectionButton:
                state.phase = .dataSourcePreferences
            case .importSettings: break
            case .didTapImportButton:
                guard let task = state.importTask else {
                    state.importResult.result = .failure(Error.importTaskCreationFailed)
                    state.importResult.isLoading = false
                    break
                }
                let newRealm = state.importSettings.newRealm
                let newDocument = state.importSettings.newDocument

                state.importResult.isLoading = true
                return .run { send in
                    do {
                        if let newRealm {
                            try compendiumMetadata.createRealm(newRealm)
                        }

                        if let newDocument {
                            try compendiumMetadata.createDocument(newDocument)
                        }

                        let importer = CompendiumImporter(compendium: compendium, metadata: compendiumMetadata)

                        let result = try await importer.run(task)
                        await send(.importDidFinish(result))
                    } catch {
                        await send(.importDidFinish(nil))
                    }
                }
            case .importDidFinish(let result?):
                state.importResult.result = .success(result)
                state.importResult.isLoading = false

                state.alert = AlertState {
                    TextState("Import completed")
                } message: {
                    TextState("\(result.newItemCount + result.overwrittenItemCount) item(s) imported (\(result.newItemCount ) new). \(result.invalidItemCount) item(s) skipped.")
                }
            case .importDidFinish(nil):
                state.importResult.result = .failure(Error.importFailed)
                state.importResult.isLoading = false
                state.alert = AlertState {
                    TextState("Import failed")
                } message: {
                    TextState(Error.importFailed.localizedDescription)
                }
            case .alert(.dismiss):
                state.alert = nil
                if state.importResult.result?.value != nil {
                    state.dismiss = true
                }
                state.importResult = .initial
            case .binding: break
            }
            return .none
        }
        .forEach(\.dataSources, action: /Action.dataSource) {
            DataSource()
        }

        Scope(state: \.importSettings, action: /Action.importSettings) {
            ImportSettings()
        }

        BindingReducer()
    }

    struct DataSource: ReducerProtocol {
        struct State: Equatable, Identifiable {
            let title: String
            let description: String
            let icon: DataSourceIcon

            var preferences: DataSourcePreferences.State

            var id: Id { Tagged(title) }

            typealias Id = Tagged<DataSource, String>
        }

        enum Action: Equatable {
            case preferences(DataSourcePreferences.Action)

            case onNextTapped
        }

        var body: some ReducerProtocol<State, Action> {
            Reduce { state, action in
                .none
            }
            Scope(state: \.preferences, action: /Action.preferences) {
                DataSourcePreferences()
            }
        }
    }

    struct ImportSettings: ReducerProtocol {
        struct State: Equatable {
            typealias AsyncDocuments = Async<[CompendiumSourceDocument], EquatableError>
            var documents: AsyncDocuments.State = .initial
            var document: SelectedCompendiumDocument? = nil
            var newDocumentName: String = ""
            var newDocumentCustomSlug: String? {
                didSet {
                    if newDocumentCustomSlug == slug(newDocumentName) {
                        newDocumentCustomSlug = nil
                    }
                }
            }

            var existingDocument: CompendiumSourceDocument? {
                guard case .existing(let id) = document else { return nil }
                return documents.value?.first(where: { $0.id == id })
            }

            var newDocument: CompendiumSourceDocument? {
                guard case .new = document,
                        let displayName = newDocumentName.nonEmptyString,
                        let slug = effectiveNewDocumentSlug.nonEmptyString,
                        let realm = effectiveRealm else { return nil }

                return CompendiumSourceDocument(
                    id: .init(slug),
                    displayName: displayName,
                    realmId: realm.id
                )
            }

            var effectiveDocument: CompendiumSourceDocument? {
                existingDocument ?? newDocument
            }

            typealias AsyncRealms = Async<[CompendiumRealm], EquatableError>
            var realms: AsyncRealms.State = .initial
            var realm: SelectedRealm? = nil
            var newRealmName: String = ""
            var newRealmCustomSlug: String? {
                didSet {
                    if newRealmCustomSlug == slug(newRealmName) {
                        newRealmCustomSlug = nil
                    }
                }
            }

            // If readerForDataSource is non-nil, customDataSourceReader is ignored
            var readerForDataSource: DataSourceReader? = nil
            var customDataSourceReader: DataSourceReader? = nil
            var effectiveDataSourceReader: DataSourceReader? { readerForDataSource ?? customDataSourceReader }

            var overwrite = false

            var documentPickerLabel: String? {
                switch document {
                case .existing(let id):
                    return documents.value?.first { $0.id == id }?.displayName
                case .new:
                    return "New document..."
                case nil:
                    return nil
                }
            }

            var effectiveNewDocumentSlug: String {
                newDocumentCustomSlug?.nonEmptyString ?? slug(newDocumentName)
            }

            var existingDocumentMatchingNewSlug: CompendiumSourceDocument? {
                guard let slug = effectiveNewDocumentSlug.nonEmptyString else { return nil }
                return documents.value?.first { $0.id.rawValue == slug }
            }

            var realmForExistingDocument: CompendiumRealm? {
                guard case let .existing(documentId) = document,
                      let doc = documents.value?.first(where: { $0.id == documentId }),
                      let realm = realms.value?.first(where: { $0.id == doc.realmId })
                else {
                    return nil
                }

                return realm
            }

            var newRealm: CompendiumRealm? {
                guard case .new = realm,
                      case .new = document,
                      let displayName = newRealmName.nonEmptyString,
                      let slug = effectiveNewRealmSlug.nonEmptyString
                else {
                    return nil
                }

                return CompendiumRealm(id: .init(slug), displayName: displayName)
            }

            var effectiveRealm: CompendiumRealm? {
                if let realmForExistingDocument {
                    return realmForExistingDocument
                }

                return switch realm {
                case .existing(let id): realms.value?.first(where: { $0.id == id })
                default: newRealm
                }
            }

            var realmPickerLabel: String? {
                switch realm {
                case .existing(let id):
                    return realms.value?.first { $0.id == id }?.displayName
                case .new:
                    return "New realm..."
                case nil:
                    return nil
                }
            }

            var effectiveNewRealmSlug: String {
                newRealmCustomSlug?.nonEmptyString ?? slug(newRealmName)
            }

            var existingRealmMatchingNewSlug: CompendiumRealm? {
                guard let slug = effectiveNewRealmSlug.nonEmptyString else { return nil }
                return realms.value?.first { $0.id.rawValue == slug }
            }

            var isValid: Bool {
                document != nil &&
                (document != .new || !newDocumentName.isEmpty) &&
                (realm != .new || !newRealmName.isEmpty) &&
                (document != .new || existingDocumentMatchingNewSlug == nil) &&
                (realm != .new || realmForExistingDocument != nil || existingRealmMatchingNewSlug == nil) &&
                effectiveDataSourceReader != nil
            }

            /// Returns true if it found an existing document
            mutating func setSuggestedDocument(_ suggestion: String) -> Bool {
                if let match = documents.value?.first(where: { $0.displayName == suggestion }) {
                    document = .existing(match.id)
                    return true
                } else {
                    document = .new
                    newDocumentName = suggestion
                    return false
                }
            }

            mutating func setSuggestedRealm(_ suggestion: String) -> Bool {
                if let match = realms.value?.first(where: { $0.displayName == suggestion }) {
                    realm = .existing(match.id)
                    return true
                } else {
                    realm = .new
                    newRealmName = suggestion
                    return false
                }
            }

            enum SelectedCompendiumDocument: Hashable {
                case existing(CompendiumSourceDocument.Id)
                case new
            }

            enum SelectedRealm: Hashable {
                case existing(CompendiumRealm.Id)
                case new
            }
        }

        enum Action: BindableAction, Equatable {
            case binding(BindingAction<State>)
            case documents(State.AsyncDocuments.Action)
            case realms(State.AsyncRealms.Action)
        }

        @Dependency(\.compendiumMetadata) var compendiumMetadata

        var body: some ReducerProtocol<State, Action> {
            Reduce { state, action in
                .none
            }

            Scope(state: \.documents, action: /Action.documents) {
                Reduce(
                    State.AsyncDocuments(compendiumMetadata: compendiumMetadata),
                )
            }

            Scope(state: \.realms, action: /Action.realms) {
                Reduce(
                    State.AsyncRealms(compendiumMetadata: compendiumMetadata),
                )
            }
        }

        private struct AsyncDocumentsAndRealmsEnvironment: EnvironmentWithCompendiumMetadata {
            var compendiumMetadata: CompendiumMetadata
        }
    }

    enum DataSourceReader: String, CaseIterable {
        case open5e
        case xml
        case improvedInitiative

        var displayName: String {
            return switch self {
            case .open5e: "Open5e JSON"
            case .xml: "Compendium XML"
            case .improvedInitiative: "Improved Initiative JSON"
            }
        }

        var supportedItemTypes: [CompendiumItemType] {
            return switch self {
            case .open5e: [.monster, .spell]
            case .xml: [.monster, .spell]
            case .improvedInitiative: [.monster]
            }
        }
    }
}

enum DataSourceIcon: Equatable {
    case open5e
    case file
    case network

    @ViewBuilder
    var view: some View {
        switch self {
        case .open5e: Open5eLogo()
        case .file: Image(systemName: "doc.fill").foregroundStyle(.secondary)
        case .network: Image(systemName: "network").foregroundStyle(.secondary)
        }
    }
}

struct DataSourcePreferences: ReducerProtocol {
    enum State: Equatable {
        case open5e(Open5e.State)
        case file(File.State)
        case network(Network.State)

        var isValid: Bool {
            switch self {
            case .open5e(let o5e):
                return /Open5e.State.SelectedOpen5eDocument.known ~= o5e.document
                    || (o5e.document == .other && !o5e.other.isEmpty)
            case .file(let file):
                return file.url != nil
            case .network(let network):
                return network.url != nil
            }
        }

        var summaryString: String? {
            switch self {
            case .open5e(let o5e):
                switch o5e.document {
                case .known(let doc):
                    return "\(o5e.itemType.localizedDisplayNamePlural.capitalized) from “\(doc.title)”"
                case .other:
                    return "\(o5e.itemType.localizedDisplayNamePlural.capitalized) from document “\(o5e.other)”"
                case .none:
                    return nil
                }
            case .file(let file):
                return file.url?.lastPathComponent
            case .network(let network):
                return network.url?.lastPathComponent.nonEmptyString ?? network.urlString
            }
        }

        var suggestedSourceName: String? {
            if case .open5e(let s) = self {
                return s.suggestedSourceName
            }
            return nil
        }

        var suggestedRealmName: String? {
            if case .open5e(let s) = self {
                return s.suggestedRealmName
            }
            return nil
        }

        var correspondingDataSourceReader: CompendiumImportFeature.DataSourceReader? {
            if case .open5e = self {
                return .open5e
            }
            return nil
        }
    }

    enum Action: Equatable {
        case open5e(Open5e.Action)
        case file(File.Action)
        case network(Network.Action)
    }

    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            .none
        }
        .ifCaseLet(/State.open5e, action: /Action.open5e) {
            Open5e()
        }
        .ifCaseLet(/State.file, action: /Action.file) {
            File()
        }
        .ifCaseLet(/State.network, action: /Action.network) {
            Network()
        }
    }

    struct Open5e: ReducerProtocol {
        struct State: Equatable {
            typealias RemoteDocuments = Async<[Open5eAPI.Document], EquatableError>
            var remoteDocuments: RemoteDocuments.State = .initial

            @BindingState var document: SelectedOpen5eDocument? = nil
            @BindingState var other: String = ""

            @BindingState var itemType = CompendiumItemType.monster

            enum SelectedOpen5eDocument: Hashable {
                case known(Open5eAPI.Document)
                case other

                var pickerLabel: String {
                    switch self {
                    case .known(let doc): return doc.title
                    case .other: return "Other..."
                    }
                }
            }

            var suggestedSourceName: String? {
                switch document {
                case .known(let doc)?:
                    // Remove OGL suffix
                    return if doc.title.hasSuffix("OGL") {
                        String(doc.title.dropLast(3)).trimmingCharacters(in: .whitespaces)
                    } else {
                        doc.title
                    }
                default: return nil
                }
            }

            var suggestedRealmName: String? {
                switch document {
                case .known(let doc)?: return doc.organization
                default: return nil
                }
            }

            var effectiveDocumentSlug: String? {
                return switch document {
                case .known(let doc): doc.slug
                case .other: other.nonEmptyString
                case nil: nil
                }
            }
        }

        enum Action: BindableAction, Equatable {
            case onAppear
            case remoteDocuments(State.RemoteDocuments.Action)
            case binding(BindingAction<State>)
        }

        @Dependency(\.open5eAPIClient) var open5eAPIClient

        var body: some ReducerProtocol<State, Action> {
            Reduce { state, action in
                switch action {
                case .onAppear:
                    if state.remoteDocuments.result == nil && !state.remoteDocuments.isLoading {
                        return .send(.remoteDocuments(.startLoading))
                    }
                case .remoteDocuments(.didFinishLoading(.failure)):
                    state.document = .other
                default: break
                }
                return .none
            }

            Scope(state: \.remoteDocuments, action: /Action.remoteDocuments) {
                State.RemoteDocuments {
                    do {
                        return try await Array(open5eAPIClient.fetchDocuments().all)
                            .sorted(by: .init(\.title))
                    } catch {
                        throw error.toEquatableError()
                    }
                }
            }

            BindingReducer()
        }
    }

    struct File: ReducerProtocol {
        struct State: Equatable {
            @BindingState var url: URL? = nil
            @BindingState var openPicker = false
        }

        enum Action: Equatable, BindableAction {
            case binding(BindingAction<State>)
        }

        var body: some ReducerProtocol<State, Action> {
            BindingReducer()
        }
    }

    struct Network: ReducerProtocol {
        struct State: Equatable {
            @BindingState var urlString: String = ""

            var url: URL? {
                URL(string: urlString)
            }
        }

        enum Action: Equatable, BindableAction {
            case binding(BindingAction<State>)
        }

        var body: some ReducerProtocol<State, Action> {
            BindingReducer()
        }
    }

}

extension StoreOf<DataSourcePreferences> {
    @ViewBuilder
    var view: some View {
        SwitchStore(self) { state in
            switch state {
            case .open5e:
                CaseLet(/DataSourcePreferences.State.open5e, action: DataSourcePreferences.Action.open5e) { store in
                    Open5ePreferencesView(store: store)
                }
            case .file:
                CaseLet(/DataSourcePreferences.State.file, action: DataSourcePreferences.Action.file) { store in
                    FilePreferencesView(store: store)
                }
            case .network:
                CaseLet(/DataSourcePreferences.State.network, action: DataSourcePreferences.Action.network) { store in
                    NetworkPreferencesView(store: store)
                }
            }
        }
    }
}

struct Open5eLogo: View, Equatable {
    var body: some View {
        Text("5e")
            .fontWeight(.bold)
            .font(.footnote)
            .padding(4)
            .foregroundColor(Color.white)
            .background(Color.red.cornerRadius(4).aspectRatio(CGSize(width: 1, height: 1), contentMode: .fill))
    }
}

extension CompendiumImportFeature.State {
    typealias DataSource = CompendiumImportFeature.DataSource

    var isDataSourceConfigured: Bool {
        selectedDataSourceId.flatMap { dataSources[id: $0]?.preferences.isValid } ?? false
    }

    var visibleDataSources: IdentifiedArrayOf<DataSource.State> {
        if phase == .dataSourcePreferences {
            return dataSources
        } else {
            return dataSources.filter { $0.id == selectedDataSourceId }
        }
    }

    func shouldShowPreferences(for dataSource: DataSource.State) -> Bool {
        return phase == .dataSourcePreferences && selectedDataSourceId == dataSource.id
    }

    func description(for dataSource: DataSource.State) -> String? {
        switch phase {
        case .dataSourcePreferences: return dataSource.description
        case .importSettings: return dataSource.preferences.summaryString
        }
    }

}

struct Open5ePreferencesView: View {
    private typealias SelectedDocument = DataSourcePreferences.Open5e.State.SelectedOpen5eDocument

    let store: StoreOf<DataSourcePreferences.Open5e>

    var body: some View {
        WithViewStore(store, observe: \.self) { viewStore in
            SectionContainer(backgroundColor: Color(UIColor.systemBackground)) {
                VStack {
                    let remoteDocuments = viewStore.state.remoteDocuments
                    if remoteDocuments.error != nil && viewStore.document == .other {
                        Text("Failed to load document list from Open5e. You can try to specify the document slug manually.")
                    } else {
                        MenuPickerField(
                            title: "Document",
                            selection: viewStore.$document.animation()
                        ) {
                            if let docs = remoteDocuments.value {
                                ForEach(docs, id: \.slug) { doc in
                                    Text(doc.title).tag(Optional.some(SelectedDocument.known(doc)))
                                }
                            } else {
                                Text("Loading documents...")
                            }

                            Divider()

                            Text("Other...").tag(Optional.some(SelectedDocument.other))
                        }
                    }

                    if viewStore.document == .other {
                        Divider()

                        TextField("Document slug", text: viewStore.$other)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .frame(minHeight: 35)
                    }

                    Divider()

                    MenuPickerField(
                        title: "Item type",
                        selection: viewStore.$itemType.optional()
                    ) {
                        Text("Monsters").tag(Optional<CompendiumItemType>.some(.monster))
                        Text("Spells").tag(Optional<CompendiumItemType>.some(.spell))
                    }
                }
            }
            .onAppear {
                viewStore.send(.onAppear)
            }
        }
    }
}

struct FilePreferencesView: View {

    let store: StoreOf<DataSourcePreferences.File>

    var body: some View {
        WithViewStore(store, observe: \.self) { viewStore in
            SectionContainer(backgroundColor: Color(UIColor.systemBackground)) {
                VStack {
                    if let url = viewStore.state.url {
                        HStack {
                            Text(url.lastPathComponent)
                            Spacer()
                            Button("Clear", systemImage: "xmark.circle.fill") {
                                viewStore.send(.binding(.set(\.$url, nil)))
                            }
                            .labelStyle(.iconOnly)
                            .foregroundColor(Color(UIColor.systemGray))
                        }
                    } else {
                        Button("Select file...") {
                            viewStore.send(.binding(.set(\.$openPicker, true)))
                        }
                    }
                }
                .frame(minHeight: 35)
            }
            .sheet(isPresented: viewStore.$openPicker) {
                DocumentPicker { urls in
                    viewStore.send(.binding(.set(\.$url, urls.first)))
                }
            }
        }
    }
}

struct NetworkPreferencesView: View {

    let store: StoreOf<DataSourcePreferences.Network>

    var body: some View {
        WithViewStore(store, observe: \.self) { viewStore in
            SectionContainer(backgroundColor: Color(UIColor.systemBackground)) {
                VStack {
                    ClearableTextField("URL", text: viewStore.$urlString)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                .frame(minHeight: 35)
            }
        }
    }
}

struct UrlPreferencesView: View {

    let store: StoreOf<DataSourcePreferences.File>

    var body: some View {
        WithViewStore(store, observe: \.self) { viewStore in
            SectionContainer(backgroundColor: Color(UIColor.systemBackground)) {
                VStack {
                    if let url = viewStore.state.url {
                        HStack {
                            Text(url.lastPathComponent)
                            Spacer()
                            Button("Clear", systemImage: "clear") {
                                viewStore.send(.binding(.set(\.$url, nil)))
                            }
                        }
                    } else {
                        Button("Select file...") {
                            viewStore.send(.binding(.set(\.$openPicker, true)))
                        }
                    }
                }
                .frame(minHeight: 35)
            }
            .sheet(isPresented: viewStore.$openPicker) {
                DocumentPicker { urls in
                    viewStore.send(.binding(.set(\.$url, urls.first)))
                }
            }
        }
    }
}


public struct CompendiumImportView: View {
    typealias SelectedRealm = CompendiumImportFeature.ImportSettings.State.SelectedRealm
    typealias SelectedDocument = CompendiumImportFeature.ImportSettings.State.SelectedCompendiumDocument

    @SwiftUI.Environment(\.dismiss) var dismiss

    let store: StoreOf<CompendiumImportFeature>

    @ScaledMetric
    var iconWidth = 30

    @State var selected = false
    @State var saved = false

    public var body: some View {
        WithViewStore(store, observe: \.self) { viewStore in
            ScrollView {
                VStack(alignment: .leading) {
                    if viewStore.state.phase == .dataSourcePreferences {
                        Text("Select a source")
                            .font(.headline)
                    }

                    ForEachStore(store.scope(
                        state: \.visibleDataSources,
                        action: CompendiumImportFeature.Action.dataSource
                    )) { dataSourceStore in
                        WithViewStore(dataSourceStore, observe: \.self) { dataSourceViewStore in
                            let unselected = viewStore.state.selectedDataSourceId != nil && viewStore.state.selectedDataSourceId != dataSourceViewStore.state.id
                            SectionContainer {
                                VStack(alignment: .leading) {
                                    Button {
                                        viewStore.send(.didSelectDataSource(dataSourceViewStore.state.id), animation: .default)
                                    } label: {
                                        HStack {
                                            dataSourceViewStore.state.icon.view
                                                .frame(minWidth: iconWidth)

                                            VStack(alignment: .leading) {
                                                Text(dataSourceViewStore.state.title)

                                                if let description = viewStore.state.description(for: dataSourceViewStore.state) {
                                                    Text(description)
                                                        .font(.footnote)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    if viewStore.state.shouldShowPreferences(for: dataSourceViewStore.state) {
                                        Divider()

                                        dataSourceStore.scope(state: \.preferences, action: CompendiumImportFeature.DataSource.Action.preferences).view

                                        Button("Configure...") {
                                            viewStore.send(.didTapNextButton, animation: .default)
                                        }
                                        .disabled(!viewStore.state.isDataSourceConfigured)
                                        .buttonStyle(.borderedProminent)
                                        .buttonBorderShape(.roundedRectangle)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                    }
                                }
                                .padding(4)
                            }
                            .compositingGroup()
                            .opacity(unselected ? 0.5 : 1.0)
                        }
                    }

                    if viewStore.state.phase == .importSettings {
                        Button(action: {
                            viewStore.send(.didTapClearDataSourceSelectionButton, animation: .default)
                        }, label: {
                            Label("Select different source", systemImage: "chevron.up")
                        })
                        .font(.footnote)
                        .foregroundStyle(Color.accentColor)
                        .buttonStyle(.plain)
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: -15, trailing: 10))
                        .frame(maxWidth: .infinity)

                        VStack(alignment: .leading) {
                            SectionContainer {
                                VStack {
                                    MenuPickerField(
                                        title: "Document",
                                        selection: viewStore.$importSettings.document.animation()
                                    ) {
                                        if let docs = viewStore.state.importSettings.documents.value {
                                            ForEach(docs, id: \.id) { doc in
                                                Text("\(doc.displayName) (\(doc.id.rawValue))").tag(Optional.some(SelectedDocument.existing(doc.id)))
                                            }
                                        } else {
                                            Text("Loading documents...")
                                        }
                                        
                                        Divider()
                                        
                                        Text("New...").tag(Optional<SelectedDocument>.some(.new))
                                    }
                                    
                                    if viewStore.state.importSettings.document == .new {
                                        Divider()
                                        
                                        VStack {
                                            TextFieldWithSlug(
                                                title: "Document name",
                                                text: viewStore.$importSettings.newDocumentName,
                                                slug: Binding(
                                                    get: { viewStore.state.importSettings.effectiveNewDocumentSlug },
                                                    set: { viewStore.$importSettings.newDocumentCustomSlug.wrappedValue = $0 }
                                                )
                                            )
                                            .frame(minHeight: 35)

                                            if let match = viewStore.state.importSettings.existingDocumentMatchingNewSlug {
                                                
                                                SlugConflictError(
                                                    resourceName: "document",
                                                    conflictingResourceName: match.displayName
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                            .padding([.top], 32)
                            
                            let configureRealmForNewDocument = viewStore.state.importSettings.document == .new
                            let realmForExistingDocument = viewStore.state.importSettings.realmForExistingDocument
                            if configureRealmForNewDocument || realmForExistingDocument != nil {
                                SectionContainer {
                                    VStack {
                                        if configureRealmForNewDocument {
                                            MenuPickerField(
                                                title: "Realm",
                                                selection: viewStore.$importSettings.realm.animation()
                                            ) {
                                                if let realms = viewStore.state.importSettings.realms.value {
                                                    ForEach(realms, id: \.id) { realm in
                                                        Text("\(realm.displayName) (\(realm.id.rawValue))").tag(Optional.some(SelectedRealm.existing(realm.id)))
                                                    }
                                                } else {
                                                    Text("Loading realms...")
                                                }
                                                
                                                Divider()
                                                
                                                Text("New...").tag(Optional<SelectedRealm>.some(.new))
                                            }
                                            
                                            if viewStore.state.importSettings.realm == .new {
                                                Divider()
                                                
                                                TextFieldWithSlug(
                                                    title: "Realm name",
                                                    text: viewStore.$importSettings.newRealmName,
                                                    slug: Binding(
                                                        get: { viewStore.state.importSettings.effectiveNewRealmSlug },
                                                        set: { viewStore.$importSettings.newRealmCustomSlug.wrappedValue = $0 }
                                                    )
                                                )
                                                .frame(minHeight: 35)
                                                
                                                if let match = viewStore.state.importSettings.existingRealmMatchingNewSlug {
                                                    SlugConflictError(
                                                        resourceName: "realm",
                                                        conflictingResourceName: match.displayName
                                                    )
                                                }
                                            }
                                        } else if let realm = realmForExistingDocument {
                                            LabeledContent("Realm", value: "\(realm.displayName) (\(realm.id.rawValue))")
                                                .frame(minHeight: 35)
                                        }
                                    }
                                }
                                .padding([.top], 12)
                            }
                        }

                        if viewStore.state.importSettings.readerForDataSource == nil {
                            SectionContainer(footer: {
                                if let reader = viewStore.state.importSettings.effectiveDataSourceReader {
                                    let itemsList = ListFormatter().string(from: reader.supportedItemTypes.map(\.localizedDisplayNamePlural)) ?? "none"

                                    Text("Supported item types: \(itemsList)")
                                        .font(.footnote).foregroundColor(Color.secondary)
                                        .padding([.leading, .trailing], 12)
                                }
                            }) {
                                if let fixedReader = viewStore.state.importSettings.readerForDataSource {
                                    LabeledContent("Format", value: "\(fixedReader.displayName)")
                                        .frame(minHeight: 35)
                                } else {
                                    MenuPickerField(
                                        title: "Format",
                                        selection: viewStore.$importSettings.customDataSourceReader.animation()
                                    ) {
                                        ForEach(CompendiumImportFeature.DataSourceReader.allCases, id: \.rawValue) { reader in
                                            Text(reader.displayName).tag(Optional.some(reader))
                                        }
                                    }
                                }
                            }
                        }

                        SectionContainer(footer: {
                            let text = viewStore.state.importSettings.overwrite
                                ? "Existing items with the same name (within the realm) are overwritten."
                                : "Existing items with the same name (within the realm) are skipped."
                            Text(text).font(.footnote).foregroundColor(Color.secondary)
                                .padding([.leading, .trailing], 12)
                        }) {
                            Toggle(isOn: viewStore.$importSettings.overwrite) {
                                Text("Overwrite existing items")
                            }
                        }
                        .padding([.top], 12)

                        let isImporting = viewStore.state.importResult.isLoading
                        let isFinished = viewStore.state.importResult.result != nil
                        Button {
                            viewStore.send(.didTapImportButton, animation: .default)
                        } label: {
                            HStack(spacing: 2) {
                                if (isImporting) {
                                    ProgressView().scaleEffect(0.5).padding([.top, .bottom], -10)
                                }
                                Text(isImporting ? "Importing..." : "Import")
                            }
                            .padding([.leading, .trailing], 8)
                        }
                        .disabled(!viewStore.state.isValid || isImporting || isFinished)
                        .controlSize(.large)
                        .disabled(!viewStore.state.isDataSourceConfigured)
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle)
                        .padding()
                        .frame(maxWidth: .infinity)
                    }

                }
                .padding()
            }
            .onAppear {
                viewStore.send(.onAppear)
            }
            .onChange(of: viewStore.state.dismiss) { _, dismiss in
                if dismiss {
                    self.dismiss()
                }
            }
        }
        .alert(store: store.scope(state: \.$alert, action: { .alert($0) }))
        .navigationTitle(Text("Import"))
    }
}

fileprivate func SlugConflictError(resourceName: String, conflictingResourceName: String) -> some View {
    HStack(spacing: 12) {
        Text(Image(systemName: "exclamationmark.octagon"))
        Text("Existing \(resourceName) “\(conflictingResourceName)” has the same shorthand. Tap the shorthand to edit or select the existing \(resourceName).")
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    .foregroundStyle(Color(UIColor.systemRed))
    .padding(8)
    .font(.footnote)
    .symbolRenderingMode(.monochrome)
    .symbolVariant(.fill)
    .frame(maxWidth: .infinity)
    .background(Color(UIColor.systemBackground).cornerRadius(4))
    .multilineTextAlignment(.leading)
}

extension CompendiumImportFeature.DataSource.State {
    var source: (any CompendiumDataSource)? {
        switch preferences {
        case .open5e(let p):
            guard let slug = p.effectiveDocumentSlug else { return nil }
            return Open5eAPIDataSource(
                itemType: p.itemType,
                document: slug,
                urlSession: URLSession.shared // fixme
            )
        case .file(let f):
            guard let url = f.url else { return nil }
            return FileDataSource(path: url.absoluteString)
        case .network(let n):
            guard let url = n.url else { return nil }
            return URLDataSource(
                url: url.absoluteString,
                using: URLSession.shared // fixme
            )
        }
    }
}

extension CompendiumImportFeature.DataSourceReader {
    func reader(source: any CompendiumDataSource) -> (any CompendiumDataSourceReader)? {

        @Dependency(\.uuid) var uuid // is this an anti-pattern?

        switch self {
        case .open5e:
            guard let source = source as? any CompendiumDataSource<[Open5eAPIResult]> else { return nil }
            return Open5eDataSourceReader(
                dataSource: source,
                generateUUID: uuid.callAsFunction
            )
        case .xml:
            guard let source = source as? any CompendiumDataSource<Data> else { return nil }
            return XMLCompendiumDataSourceReader(
                dataSource: source,
                generateUUID: uuid.callAsFunction
            )
        case .improvedInitiative:
            guard let source = source as? any CompendiumDataSource<Data> else { return nil }
            return ImprovedInitiativeDataSourceReader(
                dataSource: source,
                generateUUID: uuid.callAsFunction
            )
        }
    }
}

extension CompendiumImportFeature.State {
    var importTask: CompendiumImportTask? {
        guard let source = selectedDataSource?.source,
              let document = importSettings.effectiveDocument,
              let format = importSettings.effectiveDataSourceReader,
              let reader = format.reader(source: source) else {
            return nil
        }

        return CompendiumImportTask(
            sourceId: source.id,
            sourceVersion: nil,
            reader: reader,
            document: document,
            overwriteExisting: importSettings.overwrite
        )
    }
}

enum Open5eAPIClientKey: DependencyKey {
    public static var liveValue: Open5eAPIClient {
        @Dependency(\.urlSession) var urlSession
        return .live(httpClient: urlSession)
    }

    public static var previewValue: Open5eAPIClient {
        return .init {
            PaginatedResource<Document>(
                response: PaginatedResponse<Document>(
                    count: 3,
                    next: nil,
                    previous: nil,
                    results: [
                        Document(title: "Tome of Beasts 1", slug: "tob1", organization: "Kobold Press"),
                        Document(title: "Tome of Beasts 2", slug: "tob2", organization: "Kobold Press"),
                        Document(title: "Heroes of Might and Magic Complete Edition", slug: "homam", organization: "BAM"),
                    ]
                ),
                fetchNext: { _ in nil }
            )
        }
    }
}

enum CompendiumMetadataKey: DependencyKey {
    public static var liveValue: CompendiumMetadata {
        @Dependency(\.database) var database
        return CompendiumMetadata.live(database)
    }

    public static var previewValue: CompendiumMetadata {
        let dummyDocuments = [
            CompendiumSourceDocument.srd5_1,
            CompendiumSourceDocument.unspecifiedCore,
            CompendiumSourceDocument.homebrew,
            .init(id: Tagged("tob1"), displayName: "Tome of Beasts 1", realmId: Tagged("kp"))
        ]
        let dummyRealms = [
            CompendiumRealm.core,
            CompendiumRealm.homebrew,
            .init(id: Tagged("kp"), displayName: "Kobold Press")
        ]

        return CompendiumMetadata {
            dummyDocuments
        } observeSourceDocuments: {
            [dummyDocuments].async.stream
        } realms: {
            dummyRealms
        } observeRealms: {
            [dummyRealms].async.stream
        } putJob: { _ in

        } createRealm: { _ in

        } updateRealm: { _, _ in

        } removeRealm: { _ in

        } createDocument: { _ in

        } updateDocument: { _, _, _ in

        } removeDocument: { _, _ in

        }
    }
}

enum CompendiumKey: DependencyKey {
    public static var liveValue: Compendium {
        @Dependency(\.database) var database
        return DatabaseCompendium(databaseAccess: database.access)
    }
}

extension DependencyValues {
    var open5eAPIClient: Open5eAPIClient {
        get { self[Open5eAPIClientKey.self] }
        set { self[Open5eAPIClientKey.self] = newValue }
    }

    var compendiumMetadata: CompendiumMetadata {
        get { self[CompendiumMetadataKey.self] }
        set { self[CompendiumMetadataKey.self] = newValue }
    }

    var compendium: Compendium {
        get { self[CompendiumKey.self] }
        set { self[CompendiumKey.self] = newValue }
    }
}

public extension Async<[CompendiumSourceDocument], EquatableError> {
    init(compendiumMetadata: CompendiumMetadata) {
        self.init {
            do {
                return try compendiumMetadata.sourceDocuments().sorted(by: .init(\.displayName))
            } catch {
                throw error.toEquatableError()
            }
        }
    }
}

public extension Async<[CompendiumRealm], EquatableError> {
    init(compendiumMetadata: CompendiumMetadata) {
        self.init {
            do {
                return try compendiumMetadata.realms().sorted(by: .init(\.displayName))
            } catch {
                throw error.toEquatableError()
            }
        }
    }
}

#if DEBUG
@available(iOS 17.0, *)
struct CompendiumImportPreview: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CompendiumImportView(
                store: Store(
                    initialState: apply(CompendiumImportFeature.State()) { state in
                        state.selectedDataSourceId = state.dataSources[0].id

                        state.phase = .importSettings
                        state.importSettings.document = .new
                        state.importSettings.newDocumentName = "Toom of the Beests 1"

                        state.importSettings.realm = .new
                        state.importSettings.newRealmName = "Kobold a Press"
                    }
                ) {
                    CompendiumImportFeature()
                }
            )
            .navigationTitle("Import")
        }
    }
}
#endif
