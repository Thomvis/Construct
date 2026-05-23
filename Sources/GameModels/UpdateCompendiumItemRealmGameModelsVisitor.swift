import Foundation
import Helpers

public class UpdateCompendiumItemRealmGameModelsVisitor: AbstractGameModelsVisitor {

    let updatedRealm: (CompendiumItemKey.Realm) -> CompendiumItemKey.Realm?

    public init(updatedRealm: @escaping (CompendiumItemKey.Realm) -> CompendiumItemKey.Realm?) {
        self.updatedRealm = updatedRealm
        super.init()
    }

    @VisitorBuilder
    override public func visit(entry: inout CompendiumEntry) -> Bool {
        super.visit(entry: &entry)

        if !(entry.item is CompendiumItemGroup), let realm = updatedRealm(entry.item.realm) {
            visitValue(&entry, keyPath: \.item.realm, value: realm)
        }
    }
}
