import Foundation
import Helpers

public class UpdateItemReferenceGameModelsVisitor: AbstractGameModelsVisitor {

    let updatedKey: (CompendiumItemKey) -> CompendiumItemKey?

    public init(updatedKey: @escaping (CompendiumItemKey) -> CompendiumItemKey?) {
        self.updatedKey = updatedKey
    }

    @VisitorBuilder
    public override func visit(compendiumCombatantDefinition def: inout CompendiumCombatantDefinition) -> Bool {
        super.visit(compendiumCombatantDefinition: &def)

        if let key = updatedKey(def.item.key) {
            switch def.item {
            case var monster as Monster:
                visitValue(&monster, keyPath: \.key, value: key)
                def.item = monster
            case var character as Character:
                visitValue(&character, keyPath: \.key, value: key)
                def.item = character
            default:
                assertionFailure("Unexpected CompendiumCombatant in visitor")
            }
        }
    }

    @VisitorBuilder
    public override func visit(itemReference: inout CompendiumItemReference) -> Bool {
        super.visit(itemReference: &itemReference)

        if let key = updatedKey(itemReference.itemKey) {
            visitValue(&itemReference, keyPath: \.itemKey, value: key)
        }
    }
} 