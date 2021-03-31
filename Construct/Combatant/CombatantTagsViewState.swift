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

struct CombatantTagsViewState: Equatable, NavigationStackSourceState {
    var combatants: [Combatant]
    var effectContext: EffectContext?

    var presentedScreens: [NavigationDestination: CombatantTagEditViewState]

    var navigationTitle: String { "Manage Tags" }
    var navigationTitleDisplayMode: NavigationBarItem.TitleDisplayMode? { .inline }

    init(combatants: [Combatant], effectContext: EffectContext?, presentedScreens: [NavigationDestination: CombatantTagEditViewState] = [:]) {
        self.combatants = combatants
        self.effectContext = effectContext
        self.presentedScreens = presentedScreens
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

    private var nextCombatantTagEditViewState: CombatantTagEditViewState? {
        get { nextScreen }
        set {
            nextScreen = newValue
        }
    }

    static let reducer: Reducer<CombatantTagsViewState, CombatantTagsViewAction, Environment> = Reducer.combine(
        CombatantTagEditViewState.reducer.optional().pullback(state: \.nextCombatantTagEditViewState, action: CasePath(embed: { CombatantTagsViewAction.nextScreen($0) }, extract: { $0.nextCombatantTagEditViewAction })),
        Reducer { state, action, _ in
            switch action {
            case .addTag(let tag):
                return state.combatants.map { c in
                    CombatantTagsViewAction.combatant(c, .addTag(CombatantTag(
                        id: UUID().tagged(), // make sure every tag has a unique id
                        definition: tag.definition,
                        note: tag.note,
                        sourceCombatantId: tag.sourceCombatantId
                    )))
                }.publisher.eraseToEffect()
            case .removeTag(let tagId, let section):
                return section.combatants.compactMap { c in
                    guard let tag = c.tags.first(where: { TagId($0) == tagId }) else { return nil }
                    return CombatantTagsViewAction.combatant(c, .removeTag(tag))
                }.publisher.eraseToEffect()
            case .combatant: break // should be handled by parent
            case .setNextScreen(let s):
                state.presentedScreens[.nextInStack] = s
            case .setDetailScreen(let s):
                state.presentedScreens[.detail] = s
            case .nextScreen(.onDoneTap):
                let tag = state.nextCombatantTagEditViewState?.tag
                state.nextScreen = nil

                let combatants = state.combatants

                if let tag = tag {
                    return combatants.map { c in
                        .combatant(c, .addTag(tag))
                    }.publisher.eraseToEffect()
                }
            case .nextScreen, .detailScreen: break// handled by next screen
            }
            return .none
        }
    )

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
}

enum CombatantTagsViewAction: NavigationStackSourceAction, Equatable {
    case addTag(CombatantTag)
    case removeTag(CombatantTagsViewState.TagId, CombatantTagsViewState.ActiveSection)
    case combatant(Combatant, CombatantAction) // should be handled by parent
    case setNextScreen(CombatantTagEditViewState?)
    case nextScreen(CombatantTagEditViewAction)
    case setDetailScreen(CombatantTagEditViewState?)
    case detailScreen(CombatantTagEditViewAction)

    var nextCombatantTagEditViewAction: CombatantTagEditViewAction? {
        guard case .nextScreen(let a) = self else { return nil }
        return a
    }

    static func presentScreen(_ destination: NavigationDestination, _ screen: CombatantTagEditViewState?) -> Self {
            switch destination {
            case .nextInStack: return .setNextScreen(screen)
            case .detail: return .setDetailScreen(screen)
            }
        }

        static func presentedScreen(_ destination: NavigationDestination, _ action: CombatantTagEditViewAction) -> Self {
            switch destination {
            case .nextInStack: return .nextScreen(action)
            case .detail: return .detailScreen(action)
            }
        }
}

extension CombatantTagsViewState {
    static let nullInstance = CombatantTagsViewState(combatants: [], effectContext: nil)
}
