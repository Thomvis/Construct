//
//  ParseableGameModelsVisitor.swift
//
//
//  Created by Thomas Visser on 13/12/2023.
//

import Foundation
import Helpers

public class ParseableGameModelsVisitor: AbstractGameModelsVisitor {
    @VisitorBuilder
    public override func visit(statBlock: inout StatBlock) -> Bool {
        statBlock.type?.parseIfNeeded()

        for id in statBlock.features.ids {
            statBlock.features[id: id]?.parseIfNeeded()
        }

        for id in statBlock.actions.ids {
            statBlock.actions[id: id]?.parseIfNeeded()
        }

        for id in statBlock.reactions.ids {
            statBlock.reactions[id: id]?.parseIfNeeded()
        }

        for id in (statBlock.legendary?.actions ?? []).ids {
            statBlock.legendary?.actions[id: id]?.parseIfNeeded()
        }
    }

    @VisitorBuilder
    public override func visit(spell: inout Spell) -> Bool {
        super.visit(spell: &spell)
        spell.description.parseIfNeeded()
    }
}
