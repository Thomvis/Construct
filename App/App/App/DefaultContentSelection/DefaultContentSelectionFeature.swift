import Compendium
import ComposableArchitecture
import Foundation
import GameModels
import Helpers
import Persistence

enum DefaultContentSelectionError: Error {
    case emptySelection
}

@Reducer
public struct DefaultContentSelectionFeature {
    public typealias AsyncApplySelection = Async<Set<DefaultContentRuleset>, EquatableError>
    public typealias AsyncImportedDefaultContentVersions = Async<DefaultContentVersions, EquatableError>

    @ObservableState
    public struct State: Equatable {
        var selection: Set<DefaultContentRuleset> = []
        var importedDefaultContentVersions: AsyncImportedDefaultContentVersions.State

        var allowsSampleEncounterOnly = false
        var preselectImportedRulesets = false
        var restoreSampleEncounter: Bool?
        
        var applySelection: AsyncApplySelection.State

        var isValidSelection: Bool {
            !selection.isEmpty || allowsSampleEncounterOnly && restoreSampleEncounter == true
        }

        public init(
            restoreSampleEncounter: Bool? = nil,
            allowsSampleEncounterOnly: Bool = false,
            preselectImportedRulesets: Bool = false
        ) {
            @Dependency(\.uuid) var uuid
            self.applySelection = .init(identifier: uuid())
            self.importedDefaultContentVersions = .init(identifier: uuid())
            self.allowsSampleEncounterOnly = allowsSampleEncounterOnly
            self.preselectImportedRulesets = preselectImportedRulesets
            self.restoreSampleEncounter = restoreSampleEncounter
        }
    }

    public enum Action: Equatable {
        case onAppear
        case toggleRuleset(DefaultContentRuleset)
        case setSampleEncounterEnabled(Bool)
        case applySelection
        case importedDefaultContentVersions(AsyncImportedDefaultContentVersions.Action)
        case applySelectionResponse(Result<Set<DefaultContentRuleset>, EquatableError>)
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case applied(Applied)

            public struct Applied: Equatable {
                public var selection: Set<DefaultContentRuleset>
                public var restoreSampleEncounter: Bool

                public init(
                    selection: Set<DefaultContentRuleset>,
                    restoreSampleEncounter: Bool
                ) {
                    self.selection = selection
                    self.restoreSampleEncounter = restoreSampleEncounter
                }
            }
        }
    }

    @Dependency(\.compendium) var compendium
    @Dependency(\.compendiumMetadata) var compendiumMetadata

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .send(.importedDefaultContentVersions(.startLoading))

            case .toggleRuleset(let ruleset):
                state.preselectImportedRulesets = false
                if state.selection.contains(ruleset) {
                    state.selection.remove(ruleset)
                } else {
                    state.selection.insert(ruleset)
                }

            case .setSampleEncounterEnabled(let isEnabled):
                state.restoreSampleEncounter = isEnabled

            case .applySelection:
                guard state.isValidSelection else {
                    state.applySelection.result = .failure(.init(DefaultContentSelectionError.emptySelection))
                    return .none
                }

                guard !state.selection.isEmpty else {
                    return .send(.delegate(.applied(.init(
                        selection: state.selection,
                        restoreSampleEncounter: state.restoreSampleEncounter == true
                    ))))
                }

                state.applySelection.isLoading = true
                state.applySelection.result = nil
                return .run { [installedVersions = state.importedDefaultContentVersions.value, selection = state.selection] send in
                    do {
                        try await applyDefaultContentSelection(selection, installedVersions: installedVersions)
                        await send(.applySelectionResponse(.success(selection)))
                    } catch {
                        await send(.applySelectionResponse(.failure(error.toEquatableError())))
                    }
                }

            case .applySelectionResponse(.success(let selection)):
                state.applySelection.isLoading = false
                state.applySelection.result = .success(selection)
                return .send(.delegate(.applied(.init(
                    selection: selection,
                    restoreSampleEncounter: state.restoreSampleEncounter == true
                ))))

            case .applySelectionResponse(.failure(let error)):
                state.applySelection.isLoading = false
                state.applySelection.result = .failure(error)

            case .delegate:
                break

            case .importedDefaultContentVersions(.didFinishLoading(.success(let versions))):
                if state.preselectImportedRulesets {
                    state.selection = versions.rulesets.isEmpty ? [.rules2014] : versions.rulesets
                    state.preselectImportedRulesets = false
                }

            case .importedDefaultContentVersions:
                break
            }

            return .none
        }
        Scope(state: \.importedDefaultContentVersions, action: \.importedDefaultContentVersions) {
            AsyncImportedDefaultContentVersions {
                do {
                    return try importedDefaultContentVersions()
                } catch {
                    throw error.toEquatableError()
                }
            }
        }
    }
    
    func applyDefaultContentSelection(
        _ selection: Set<DefaultContentRuleset>,
        installedVersions: DefaultContentVersions?
    ) async throws {
        try await compendiumMetadata.ensureHomebrewMetadata()
        for ruleset in selection {
            try await compendiumMetadata.ensureEditionMetadata(ruleset.edition)
        }

        let sources = try DefaultContentVersions.sourcesNeedingImport(
            selection: selection,
            installed: installedVersions ?? importedDefaultContentVersions()
        )
        guard !sources.isEmpty else { return }

        let importer = CompendiumImporter(
            compendium: compendium,
            metadata: compendiumMetadata
        )
        try await importer.importDefaultContent(sources: sources)
    }

    func importedDefaultContentVersions() throws -> DefaultContentVersions {
        let versions: [(DefaultContentSource, String)] = try DefaultContentSource.allCases.compactMap { source in
            guard let version = try compendiumMetadata.latestImportJob(sourceId: source.importSourceId)?.sourceVersion else {
                return nil
            }
            return (source, version)
        }
        return DefaultContentVersions(versions: Dictionary(uniqueKeysWithValues: versions))
    }
}
