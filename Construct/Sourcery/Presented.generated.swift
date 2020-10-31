// Generated using Sourcery 1.0.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

protocol NavigationNode0 {
    func topNavigationItems() -> [Any]
    func navigationStackSize() -> Int
    mutating func popLastNavigationStackItem()
}

extension CombatantResourcesViewState: NavigationNode0 {
    func topNavigationItems() -> [Any] {
        return [self]
    }

    func navigationStackSize() -> Int {
        return 1
    }

    mutating func popLastNavigationStackItem() {
        // no-op
    }
}
extension CombatantTagEditViewState: NavigationNode0 {
    func topNavigationItems() -> [Any] {
        return [self]
    }

    func navigationStackSize() -> Int {
        return 1
    }

    mutating func popLastNavigationStackItem() {
        // no-op
    }
}
extension CombatantTrackerEditViewState: NavigationNode0 {
    func topNavigationItems() -> [Any] {
        return [self]
    }

    func navigationStackSize() -> Int {
        return 1
    }

    mutating func popLastNavigationStackItem() {
        // no-op
    }
}
extension CompendiumImportViewState: NavigationNode0 {
    func topNavigationItems() -> [Any] {
        return [self]
    }

    func navigationStackSize() -> Int {
        return 1
    }

    mutating func popLastNavigationStackItem() {
        // no-op
    }
}
extension CompendiumItemGroupEditState: NavigationNode0 {
    func topNavigationItems() -> [Any] {
        return [self]
    }

    func navigationStackSize() -> Int {
        return 1
    }

    mutating func popLastNavigationStackItem() {
        // no-op
    }
}
extension CreatureEditViewState: NavigationNode0 {
    func topNavigationItems() -> [Any] {
        return [self]
    }

    func navigationStackSize() -> Int {
        return 1
    }

    mutating func popLastNavigationStackItem() {
        // no-op
    }
}
extension ReferenceViewState: NavigationNode0 {
    func topNavigationItems() -> [Any] {
        return [self]
    }

    func navigationStackSize() -> Int {
        return 1
    }

    mutating func popLastNavigationStackItem() {
        // no-op
    }
}
extension RunningEncounterLogViewState: NavigationNode0 {
    func topNavigationItems() -> [Any] {
        return [self]
    }

    func navigationStackSize() -> Int {
        return 1
    }

    mutating func popLastNavigationStackItem() {
        // no-op
    }
}

extension CampaignBrowseViewState.NextScreen: NavigationNode0 {
    private var navigationNode0: NavigationNode0 {
        get {
            switch self {
            case .catalogBrowse(let s): return s
            case .encounter(let s): return s
            }
        }

        set {
            switch newValue {
            case let v as CampaignBrowseViewState: self = .catalogBrowse(v)
            case let v as EncounterDetailViewState: self = .encounter(v)
            default: break
            }
        }
    }

    func topNavigationItems() -> [Any] {
        return navigationNode0.topNavigationItems()
    }

    func navigationStackSize() -> Int {
        return navigationNode0.navigationStackSize()
    }

    mutating func popLastNavigationStackItem() {
        navigationNode0.popLastNavigationStackItem()
    }
}

extension CombatantDetailViewState.NextScreen: NavigationNode0 {
    private var navigationNode0: NavigationNode0 {
        get {
            switch self {
            case .combatantTagsView(let s): return s
            case .combatantTagEditView(let s): return s
            case .creatureEditView(let s): return s
            case .combatantResourcesView(let s): return s
            case .runningEncounterLogView(let s): return s
            }
        }

        set {
            switch newValue {
            case let v as CombatantTagsViewState: self = .combatantTagsView(v)
            case let v as CombatantTagEditViewState: self = .combatantTagEditView(v)
            case let v as CreatureEditViewState: self = .creatureEditView(v)
            case let v as CombatantResourcesViewState: self = .combatantResourcesView(v)
            case let v as RunningEncounterLogViewState: self = .runningEncounterLogView(v)
            default: break
            }
        }
    }

    func topNavigationItems() -> [Any] {
        return navigationNode0.topNavigationItems()
    }

    func navigationStackSize() -> Int {
        return navigationNode0.navigationStackSize()
    }

    mutating func popLastNavigationStackItem() {
        navigationNode0.popLastNavigationStackItem()
    }
}


extension CompendiumEntryDetailViewState.NextScreen: NavigationNode0 {
    private var navigationNode0: NavigationNode0 {
        get {
            switch self {
            case .creatureEdit(let s): return s
            case .groupEdit(let s): return s
            }
        }

        set {
            switch newValue {
            case let v as CreatureEditViewState: self = .creatureEdit(v)
            case let v as CompendiumItemGroupEditState: self = .groupEdit(v)
            default: break
            }
        }
    }

    func topNavigationItems() -> [Any] {
        return navigationNode0.topNavigationItems()
    }

    func navigationStackSize() -> Int {
        return navigationNode0.navigationStackSize()
    }

    mutating func popLastNavigationStackItem() {
        navigationNode0.popLastNavigationStackItem()
    }
}

extension CompendiumIndexState.NextScreen: NavigationNode0 {
    private var navigationNode0: NavigationNode0 {
        get {
            switch self {
            case .compendiumIndex(let s): return s
            case .groupEdit(let s): return s
            case .itemDetail(let s): return s
            case .creatureEdit(let s): return s
            case .`import`(let s): return s
            }
        }

        set {
            switch newValue {
            case let v as CompendiumIndexState: self = .compendiumIndex(v)
            case let v as CompendiumItemGroupEditState: self = .groupEdit(v)
            case let v as CompendiumEntryDetailViewState: self = .itemDetail(v)
            case let v as CreatureEditViewState: self = .creatureEdit(v)
            case let v as CompendiumImportViewState: self = .`import`(v)
            default: break
            }
        }
    }

    func topNavigationItems() -> [Any] {
        return navigationNode0.topNavigationItems()
    }

    func navigationStackSize() -> Int {
        return navigationNode0.navigationStackSize()
    }

    mutating func popLastNavigationStackItem() {
        navigationNode0.popLastNavigationStackItem()
    }
}

extension EncounterDetailViewState.NextScreen: NavigationNode0 {
    private var navigationNode0: NavigationNode0 {
        get {
            switch self {
            case .reference(let s): return s
            }
        }

        set {
            switch newValue {
            case let v as ReferenceViewState: self = .reference(v)
            default: break
            }
        }
    }

    func topNavigationItems() -> [Any] {
        return navigationNode0.topNavigationItems()
    }

    func navigationStackSize() -> Int {
        return navigationNode0.navigationStackSize()
    }

    mutating func popLastNavigationStackItem() {
        navigationNode0.popLastNavigationStackItem()
    }
}

extension ReferenceItemViewState.Content.Home.NextScreen: NavigationNode0 {
    private var navigationNode0: NavigationNode0 {
        get {
            switch self {
            case .compendium(let s): return s
            }
        }

        set {
            switch newValue {
            case let v as CompendiumIndexState: self = .compendium(v)
            default: break
            }
        }
    }

    func topNavigationItems() -> [Any] {
        return navigationNode0.topNavigationItems()
    }

    func navigationStackSize() -> Int {
        return navigationNode0.navigationStackSize()
    }

    mutating func popLastNavigationStackItem() {
        navigationNode0.popLastNavigationStackItem()
    }
}

extension SidebarViewState.NextScreen: NavigationNode0 {
    private var navigationNode0: NavigationNode0 {
        get {
            switch self {
            case .compendium(let s): return s
            case .encounter(let s): return s
            case .campaignBrowse(let s): return s
            }
        }

        set {
            switch newValue {
            case let v as CompendiumIndexState: self = .compendium(v)
            case let v as EncounterDetailViewState: self = .encounter(v)
            case let v as CampaignBrowseViewState: self = .campaignBrowse(v)
            default: break
            }
        }
    }

    func topNavigationItems() -> [Any] {
        return navigationNode0.topNavigationItems()
    }

    func navigationStackSize() -> Int {
        return navigationNode0.navigationStackSize()
    }

    mutating func popLastNavigationStackItem() {
        navigationNode0.popLastNavigationStackItem()
    }
}


extension CampaignBrowseViewState: NavigationNode0 {

    func topNavigationItems() -> [Any] {
        var result: [Any] = []
        if let next = presentedScreens[.nextInStack] {
            result.append(contentsOf: next.topNavigationItems())
        } else {
            result.append(self)
        }

        if let detail = presentedScreens[.detail] {
            result.append(contentsOf: detail.topNavigationItems())
        }
        return result
    }

    func navigationStackSize() -> Int {
        if let next = presentedScreens[.nextInStack] {
            return 1 + next.navigationStackSize()
        }
        return 1
    }

    mutating func popLastNavigationStackItem() {
        if navigationStackSize() <= 2 {
            presentedScreens[.nextInStack] = nil
        } else {
            presentedScreens[.nextInStack]?.popLastNavigationStackItem()
        }
    }

    var presentedNextCampaignBrowseViewState: CampaignBrowseViewState? {
        get { 
            if case .catalogBrowse(let s) = presentedScreens[.nextInStack] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.nextInStack] = .catalogBrowse(value) 
            }
        }
    }

    var presentedDetailCampaignBrowseViewState: CampaignBrowseViewState? {
        get { 
            if case .catalogBrowse(let s) = presentedScreens[.detail] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.detail] = .catalogBrowse(value) 
            }
        }
    }
    var presentedNextEncounterDetailViewState: EncounterDetailViewState? {
        get { 
            if case .encounter(let s) = presentedScreens[.nextInStack] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.nextInStack] = .encounter(value) 
            }
        }
    }

    var presentedDetailEncounterDetailViewState: EncounterDetailViewState? {
        get { 
            if case .encounter(let s) = presentedScreens[.detail] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.detail] = .encounter(value) 
            }
        }
    }
}
extension CombatantDetailViewState: NavigationNode0 {

    func topNavigationItems() -> [Any] {
        var result: [Any] = []
        if let next = presentedScreens[.nextInStack] {
            result.append(contentsOf: next.topNavigationItems())
        } else {
            result.append(self)
        }

        if let detail = presentedScreens[.detail] {
            result.append(contentsOf: detail.topNavigationItems())
        }
        return result
    }

    func navigationStackSize() -> Int {
        if let next = presentedScreens[.nextInStack] {
            return 1 + next.navigationStackSize()
        }
        return 1
    }

    mutating func popLastNavigationStackItem() {
        if navigationStackSize() <= 2 {
            presentedScreens[.nextInStack] = nil
        } else {
            presentedScreens[.nextInStack]?.popLastNavigationStackItem()
        }
    }

    var presentedNextCombatantTagsViewState: CombatantTagsViewState? {
        get { 
            if case .combatantTagsView(let s) = presentedScreens[.nextInStack] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.nextInStack] = .combatantTagsView(value) 
            }
        }
    }

    var presentedDetailCombatantTagsViewState: CombatantTagsViewState? {
        get { 
            if case .combatantTagsView(let s) = presentedScreens[.detail] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.detail] = .combatantTagsView(value) 
            }
        }
    }
    var presentedNextCombatantTagEditViewState: CombatantTagEditViewState? {
        get { 
            if case .combatantTagEditView(let s) = presentedScreens[.nextInStack] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.nextInStack] = .combatantTagEditView(value) 
            }
        }
    }

    var presentedDetailCombatantTagEditViewState: CombatantTagEditViewState? {
        get { 
            if case .combatantTagEditView(let s) = presentedScreens[.detail] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.detail] = .combatantTagEditView(value) 
            }
        }
    }
    var presentedNextCreatureEditViewState: CreatureEditViewState? {
        get { 
            if case .creatureEditView(let s) = presentedScreens[.nextInStack] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.nextInStack] = .creatureEditView(value) 
            }
        }
    }

    var presentedDetailCreatureEditViewState: CreatureEditViewState? {
        get { 
            if case .creatureEditView(let s) = presentedScreens[.detail] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.detail] = .creatureEditView(value) 
            }
        }
    }
    var presentedNextCombatantResourcesViewState: CombatantResourcesViewState? {
        get { 
            if case .combatantResourcesView(let s) = presentedScreens[.nextInStack] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.nextInStack] = .combatantResourcesView(value) 
            }
        }
    }

    var presentedDetailCombatantResourcesViewState: CombatantResourcesViewState? {
        get { 
            if case .combatantResourcesView(let s) = presentedScreens[.detail] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.detail] = .combatantResourcesView(value) 
            }
        }
    }
    var presentedNextRunningEncounterLogViewState: RunningEncounterLogViewState? {
        get { 
            if case .runningEncounterLogView(let s) = presentedScreens[.nextInStack] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.nextInStack] = .runningEncounterLogView(value) 
            }
        }
    }

    var presentedDetailRunningEncounterLogViewState: RunningEncounterLogViewState? {
        get { 
            if case .runningEncounterLogView(let s) = presentedScreens[.detail] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.detail] = .runningEncounterLogView(value) 
            }
        }
    }
}
extension CombatantTagsViewState: NavigationNode0 {

    func topNavigationItems() -> [Any] {
        var result: [Any] = []
        if let next = presentedScreens[.nextInStack] {
            result.append(contentsOf: next.topNavigationItems())
        } else {
            result.append(self)
        }

        if let detail = presentedScreens[.detail] {
            result.append(contentsOf: detail.topNavigationItems())
        }
        return result
    }

    func navigationStackSize() -> Int {
        if let next = presentedScreens[.nextInStack] {
            return 1 + next.navigationStackSize()
        }
        return 1
    }

    mutating func popLastNavigationStackItem() {
        if navigationStackSize() <= 2 {
            presentedScreens[.nextInStack] = nil
        } else {
            presentedScreens[.nextInStack]?.popLastNavigationStackItem()
        }
    }

}
extension CompendiumEntryDetailViewState: NavigationNode0 {

    func topNavigationItems() -> [Any] {
        var result: [Any] = []
        if let next = presentedScreens[.nextInStack] {
            result.append(contentsOf: next.topNavigationItems())
        } else {
            result.append(self)
        }

        if let detail = presentedScreens[.detail] {
            result.append(contentsOf: detail.topNavigationItems())
        }
        return result
    }

    func navigationStackSize() -> Int {
        if let next = presentedScreens[.nextInStack] {
            return 1 + next.navigationStackSize()
        }
        return 1
    }

    mutating func popLastNavigationStackItem() {
        if navigationStackSize() <= 2 {
            presentedScreens[.nextInStack] = nil
        } else {
            presentedScreens[.nextInStack]?.popLastNavigationStackItem()
        }
    }

    var presentedNextCreatureEditViewState: CreatureEditViewState? {
        get { 
            if case .creatureEdit(let s) = presentedScreens[.nextInStack] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.nextInStack] = .creatureEdit(value) 
            }
        }
    }

    var presentedDetailCreatureEditViewState: CreatureEditViewState? {
        get { 
            if case .creatureEdit(let s) = presentedScreens[.detail] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.detail] = .creatureEdit(value) 
            }
        }
    }
    var presentedNextCompendiumItemGroupEditState: CompendiumItemGroupEditState? {
        get { 
            if case .groupEdit(let s) = presentedScreens[.nextInStack] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.nextInStack] = .groupEdit(value) 
            }
        }
    }

    var presentedDetailCompendiumItemGroupEditState: CompendiumItemGroupEditState? {
        get { 
            if case .groupEdit(let s) = presentedScreens[.detail] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.detail] = .groupEdit(value) 
            }
        }
    }
}
extension CompendiumIndexState: NavigationNode0 {

    func topNavigationItems() -> [Any] {
        var result: [Any] = []
        if let next = presentedScreens[.nextInStack] {
            result.append(contentsOf: next.topNavigationItems())
        } else {
            result.append(self)
        }

        if let detail = presentedScreens[.detail] {
            result.append(contentsOf: detail.topNavigationItems())
        }
        return result
    }

    func navigationStackSize() -> Int {
        if let next = presentedScreens[.nextInStack] {
            return 1 + next.navigationStackSize()
        }
        return 1
    }

    mutating func popLastNavigationStackItem() {
        if navigationStackSize() <= 2 {
            presentedScreens[.nextInStack] = nil
        } else {
            presentedScreens[.nextInStack]?.popLastNavigationStackItem()
        }
    }

    var presentedNextCompendiumIndexState: CompendiumIndexState? {
        get { 
            if case .compendiumIndex(let s) = presentedScreens[.nextInStack] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.nextInStack] = .compendiumIndex(value) 
            }
        }
    }

    var presentedDetailCompendiumIndexState: CompendiumIndexState? {
        get { 
            if case .compendiumIndex(let s) = presentedScreens[.detail] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.detail] = .compendiumIndex(value) 
            }
        }
    }
    var presentedNextCompendiumItemGroupEditState: CompendiumItemGroupEditState? {
        get { 
            if case .groupEdit(let s) = presentedScreens[.nextInStack] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.nextInStack] = .groupEdit(value) 
            }
        }
    }

    var presentedDetailCompendiumItemGroupEditState: CompendiumItemGroupEditState? {
        get { 
            if case .groupEdit(let s) = presentedScreens[.detail] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.detail] = .groupEdit(value) 
            }
        }
    }
    var presentedNextCompendiumEntryDetailViewState: CompendiumEntryDetailViewState? {
        get { 
            if case .itemDetail(let s) = presentedScreens[.nextInStack] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.nextInStack] = .itemDetail(value) 
            }
        }
    }

    var presentedDetailCompendiumEntryDetailViewState: CompendiumEntryDetailViewState? {
        get { 
            if case .itemDetail(let s) = presentedScreens[.detail] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.detail] = .itemDetail(value) 
            }
        }
    }
    var presentedNextCreatureEditViewState: CreatureEditViewState? {
        get { 
            if case .creatureEdit(let s) = presentedScreens[.nextInStack] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.nextInStack] = .creatureEdit(value) 
            }
        }
    }

    var presentedDetailCreatureEditViewState: CreatureEditViewState? {
        get { 
            if case .creatureEdit(let s) = presentedScreens[.detail] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.detail] = .creatureEdit(value) 
            }
        }
    }
    var presentedNextCompendiumImportViewState: CompendiumImportViewState? {
        get { 
            if case .`import`(let s) = presentedScreens[.nextInStack] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.nextInStack] = .`import`(value) 
            }
        }
    }

    var presentedDetailCompendiumImportViewState: CompendiumImportViewState? {
        get { 
            if case .`import`(let s) = presentedScreens[.detail] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.detail] = .`import`(value) 
            }
        }
    }
}
extension EncounterDetailViewState: NavigationNode0 {

    func topNavigationItems() -> [Any] {
        var result: [Any] = []
        if let next = presentedScreens[.nextInStack] {
            result.append(contentsOf: next.topNavigationItems())
        } else {
            result.append(self)
        }

        if let detail = presentedScreens[.detail] {
            result.append(contentsOf: detail.topNavigationItems())
        }
        return result
    }

    func navigationStackSize() -> Int {
        if let next = presentedScreens[.nextInStack] {
            return 1 + next.navigationStackSize()
        }
        return 1
    }

    mutating func popLastNavigationStackItem() {
        if navigationStackSize() <= 2 {
            presentedScreens[.nextInStack] = nil
        } else {
            presentedScreens[.nextInStack]?.popLastNavigationStackItem()
        }
    }

    var presentedNextReferenceViewState: ReferenceViewState? {
        get { 
            if case .reference(let s) = presentedScreens[.nextInStack] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.nextInStack] = .reference(value) 
            }
        }
    }

    var presentedDetailReferenceViewState: ReferenceViewState? {
        get { 
            if case .reference(let s) = presentedScreens[.detail] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.detail] = .reference(value) 
            }
        }
    }
}
extension ReferenceItemViewState.Content.Home: NavigationNode0 {

    func topNavigationItems() -> [Any] {
        var result: [Any] = []
        if let next = presentedScreens[.nextInStack] {
            result.append(contentsOf: next.topNavigationItems())
        } else {
            result.append(self)
        }

        if let detail = presentedScreens[.detail] {
            result.append(contentsOf: detail.topNavigationItems())
        }
        return result
    }

    func navigationStackSize() -> Int {
        if let next = presentedScreens[.nextInStack] {
            return 1 + next.navigationStackSize()
        }
        return 1
    }

    mutating func popLastNavigationStackItem() {
        if navigationStackSize() <= 2 {
            presentedScreens[.nextInStack] = nil
        } else {
            presentedScreens[.nextInStack]?.popLastNavigationStackItem()
        }
    }

    var presentedNextCompendiumIndexState: CompendiumIndexState? {
        get { 
            if case .compendium(let s) = presentedScreens[.nextInStack] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.nextInStack] = .compendium(value) 
            }
        }
    }

    var presentedDetailCompendiumIndexState: CompendiumIndexState? {
        get { 
            if case .compendium(let s) = presentedScreens[.detail] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.detail] = .compendium(value) 
            }
        }
    }
}
extension SidebarViewState: NavigationNode0 {

    func topNavigationItems() -> [Any] {
        var result: [Any] = []
        if let next = presentedScreens[.nextInStack] {
            result.append(contentsOf: next.topNavigationItems())
        } else {
            result.append(self)
        }

        if let detail = presentedScreens[.detail] {
            result.append(contentsOf: detail.topNavigationItems())
        }
        return result
    }

    func navigationStackSize() -> Int {
        if let next = presentedScreens[.nextInStack] {
            return 1 + next.navigationStackSize()
        }
        return 1
    }

    mutating func popLastNavigationStackItem() {
        if navigationStackSize() <= 2 {
            presentedScreens[.nextInStack] = nil
        } else {
            presentedScreens[.nextInStack]?.popLastNavigationStackItem()
        }
    }

    var presentedNextCompendiumIndexState: CompendiumIndexState? {
        get { 
            if case .compendium(let s) = presentedScreens[.nextInStack] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.nextInStack] = .compendium(value) 
            }
        }
    }

    var presentedDetailCompendiumIndexState: CompendiumIndexState? {
        get { 
            if case .compendium(let s) = presentedScreens[.detail] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.detail] = .compendium(value) 
            }
        }
    }
    var presentedNextEncounterDetailViewState: EncounterDetailViewState? {
        get { 
            if case .encounter(let s) = presentedScreens[.nextInStack] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.nextInStack] = .encounter(value) 
            }
        }
    }

    var presentedDetailEncounterDetailViewState: EncounterDetailViewState? {
        get { 
            if case .encounter(let s) = presentedScreens[.detail] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.detail] = .encounter(value) 
            }
        }
    }
    var presentedNextCampaignBrowseViewState: CampaignBrowseViewState? {
        get { 
            if case .campaignBrowse(let s) = presentedScreens[.nextInStack] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.nextInStack] = .campaignBrowse(value) 
            }
        }
    }

    var presentedDetailCampaignBrowseViewState: CampaignBrowseViewState? {
        get { 
            if case .campaignBrowse(let s) = presentedScreens[.detail] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.detail] = .campaignBrowse(value) 
            }
        }
    }
}
