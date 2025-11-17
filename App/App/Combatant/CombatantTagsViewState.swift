//
//  CombatantTagsViewState.swift
//  Construct
//
//  Created by Thomas Visser on 22/05/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import Combine
import Tagged
import Helpers
import GameModels

struct CombatantTagsFeature: Reducer {
    let environment: Environment

    init(environment: Environment) {
        self.environment = environment
    }

    struct State: Equatable {
        var combatants: [Combatant]
        var effectContext: EffectContext?

        @PresentationState var destination: Destination.State?

        var navigationTitle: String { "Manage Tags" }
        var navigationTitleDisplayMode: NavigationBarItem.TitleDisplayMode? { .inline }

        init(
            combatants: [Combatant],
            effectContext: EffectContext?,
            destination: Destination.State? = nil
        ) {
            self.combatants = combatants
            self.effectContext = effectContext
            self._destination = PresentationState(wrappedValue: destination)
        }

        mutating func update(_ combatant: Combatant) {
            if let idx = combatants.firstIndex(where: { $0.id == combatant.id }) {
                combatants[idx] = combatant
            }
        }

        var activeSections: [ActiveSection] {
            var tags: [TagId: Set<Combatant.Id>] = [:]
            for c in combatants {
                for t in c.tags {
                    tags[TagId(t), default: Set()].insert(c.id)
                }
            }

            var reverseTags: [Set<Combatant.Id>: [TagId]] = [:]
            for (t, cs) in tags {
                reverseTags[cs, default: []].append(t)
            }

            var result: [ActiveSection] = []
            for (key, value) in reverseTags {
                let cs = key.map { combatants[id: $0]! }
                let tags = value.map { tid in cs.flatMap { $0.tags.filter { TagId($0) == tid } }}.compactMap { tags in
                    tags.first.map { f in ActiveSection.TagGroup(tag: f, allTags: tags) }
                }.sorted { $0.tag.title < $1.tag.title }

                result.append(ActiveSection(combatants: cs, tagGroups: tags))
            }

            return result.sorted { ($0.combatants.count * 100 + $0.tagGroups.count) as Int > ($1.combatants.count  * 100 + $0.tagGroups.count) as Int }
        }

        var allCombatantsSection: ActiveSection? {
            activeSections.first { $0.combatants.count == combatants.count }
        }

        var navigationStackItemStateId: String {
            "\(combatants.map { $0.id.rawValue.uuidString }.joined()):CombatantTagsViewState"
        }

        var tagEditDestinationState: CombatantTagEditFeature.State? {
            get {
                guard case .tagEdit(let state) = destination else { return nil }
                return state
            }
            set {
                if let newValue = newValue {
                    destination = .tagEdit(newValue)
                } else if case .tagEdit = destination {
                    destination = nil
                }
            }
        }

        struct TagId: Hashable {
            let definition: CombatantTagDefinition
            var note: String?

            init(_ tag: CombatantTag) {
                self.definition = tag.definition
                self.note = tag.note
            }
        }

        struct ActiveSection: Equatable {
            var combatants: [Combatant]
            var tagGroups: [TagGroup]

            var id: String {
                combatants.map { $0.id.rawValue.uuidString }.sorted().joined()
            }

            var title: String {
                ListFormatter().string(from: combatants.map { $0.discriminatedName }).nonNilString
            }

            struct TagGroup: Equatable {
                var tag: CombatantTag
                var allTags: [CombatantTag]
            }
        }

        static let nullInstance = State(combatants: [], effectContext: nil)
    }

    enum Action: Equatable {
        case addTag(CombatantTag)
        case removeTag(State.TagId, State.ActiveSection)
        case combatant(Combatant, CombatantAction) // should be handled by parent
        case setDestination(Destination.State?)
        case destination(PresentationAction<Destination.Action>)
    }

    struct Destination: Reducer {
        let environment: Environment

        enum State: Equatable {
            case tagEdit(CombatantTagEditFeature.State)
        }

        enum Action: Equatable {
            case tagEdit(CombatantTagEditFeature.Action)
        }

        var body: some ReducerOf<Self> {
            Scope(state: /State.tagEdit, action: /Action.tagEdit) {
                CombatantTagEditFeature(environment: environment)
            }
        }
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .addTag(let tag):
                return .merge(
                    state.combatants.map { c in
                        .send(
                            Action.combatant(c, .addTag(CombatantTag(
                                id: UUID().tagged(), // make sure every tag has a unique id
                                definition: tag.definition,
                                note: tag.note,
                                sourceCombatantId: tag.sourceCombatantId
                            )))
                        )
                    }
                )
            case .removeTag(let tagId, let section):
                return .merge(
                    section.combatants.compactMap { c in
                        guard let tag = c.tags.first(where: { State.TagId($0) == tagId }) else { return nil }
                        return .send(Action.combatant(c, .removeTag(tag)))
                    }
                )
            case .combatant: break // should be handled by parent
            case .setDestination(let destination):
                state.destination = destination
            case .destination(.presented(.tagEdit(.onDoneTap))):
                let tag = state.tagEditDestinationState?.tag
                state.destination = nil

                let combatants = state.combatants

                if let tag = tag {
                    return .merge(
                        combatants.map { c in
                            .send(.combatant(c, .addTag(tag)))
                        }
                    )
                }
            case .destination: break
            }
            return .none
        }
        .ifLet(\.$destination, action: /Action.destination) {
            Destination(environment: environment)
        }
    }
}

extension CombatantTagsFeature.State: NavigationTreeNode {
    var navigationNodes: [Any] {
        guard let destination else { return [self] }
        return [self] + destination.navigationNodes
    }
}

extension CombatantTagsFeature.Destination.State: NavigationTreeNode {
    var navigationNodes: [Any] {
        switch self {
        case .tagEdit(let state):
            return state.navigationNodes
        }
    }
}
