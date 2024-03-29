// Generated using Sourcery 1.6.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
import Helpers

extension CombatantResourcesViewState: NavigationNode {
    var nodeId: String { 
        navigationStackItemStateId
    }

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
extension CombatantTagEditViewState: NavigationNode {
    var nodeId: String { 
        navigationStackItemStateId
    }

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
extension CombatantTrackerEditViewState: NavigationNode {
    var nodeId: String { 
        navigationStackItemStateId
    }

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
extension CompendiumImportFeature.State: NavigationNode {
    var nodeId: String { 
        navigationStackItemStateId
    }

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
extension CompendiumItemGroupEditState: NavigationNode {
    var nodeId: String { 
        navigationStackItemStateId
    }

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
extension CreatureEditViewState: NavigationNode {
    var nodeId: String { 
        navigationStackItemStateId
    }

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
extension EncounterDetailViewState: NavigationNode {
    var nodeId: String { 
        navigationStackItemStateId
    }

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
extension ReferenceViewState: NavigationNode {
    var nodeId: String { 
        navigationStackItemStateId
    }

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
extension RunningEncounterLogViewState: NavigationNode {
    var nodeId: String { 
        navigationStackItemStateId
    }

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
extension SafariViewState: NavigationNode {
    var nodeId: String { 
        navigationStackItemStateId
    }

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

extension CampaignBrowseViewState.NextScreen: NavigationNode {
    var nodeId: String {
        navigationNode.nodeId
    }

    private var navigationNode: NavigationNode {
        get {
            switch self {
            case .campaignBrowse(let s): return s
            case .encounter(let s): return s
            }
        }

        set {
            switch newValue {
            case let v as CampaignBrowseViewState: self = .campaignBrowse(v)
            case let v as EncounterDetailViewState: self = .encounter(v)
            default: break
            }
        }
    }

    func topNavigationItems() -> [Any] {
        return navigationNode.topNavigationItems()
    }

    func navigationStackSize() -> Int {
        return navigationNode.navigationStackSize()
    }

    mutating func popLastNavigationStackItem() {
        navigationNode.popLastNavigationStackItem()
    }
}

extension CombatantDetailViewState.NextScreen: NavigationNode {
    var nodeId: String {
        navigationNode.nodeId
    }

    private var navigationNode: NavigationNode {
        get {
            switch self {
            case .combatantTagsView(let s): return s
            case .combatantTagEditView(let s): return s
            case .creatureEditView(let s): return s
            case .combatantResourcesView(let s): return s
            case .runningEncounterLogView(let s): return s
            case .compendiumItemDetailView(let s): return s
            case .safariView(let s): return s
            }
        }

        set {
            switch newValue {
            case let v as CombatantTagsViewState: self = .combatantTagsView(v)
            case let v as CombatantTagEditViewState: self = .combatantTagEditView(v)
            case let v as CreatureEditViewState: self = .creatureEditView(v)
            case let v as CombatantResourcesViewState: self = .combatantResourcesView(v)
            case let v as RunningEncounterLogViewState: self = .runningEncounterLogView(v)
            case let v as CompendiumEntryDetailViewState: self = .compendiumItemDetailView(v)
            case let v as SafariViewState: self = .safariView(v)
            default: break
            }
        }
    }

    func topNavigationItems() -> [Any] {
        return navigationNode.topNavigationItems()
    }

    func navigationStackSize() -> Int {
        return navigationNode.navigationStackSize()
    }

    mutating func popLastNavigationStackItem() {
        navigationNode.popLastNavigationStackItem()
    }
}


extension CompendiumEntryDetailViewState.NextScreen: NavigationNode {
    var nodeId: String {
        navigationNode.nodeId
    }

    private var navigationNode: NavigationNode {
        get {
            switch self {
            case .compendiumItemDetailView(let s): return s
            case .safariView(let s): return s
            }
        }

        set {
            switch newValue {
            case let v as CompendiumEntryDetailViewState: self = .compendiumItemDetailView(v)
            case let v as SafariViewState: self = .safariView(v)
            default: break
            }
        }
    }

    func topNavigationItems() -> [Any] {
        return navigationNode.topNavigationItems()
    }

    func navigationStackSize() -> Int {
        return navigationNode.navigationStackSize()
    }

    mutating func popLastNavigationStackItem() {
        navigationNode.popLastNavigationStackItem()
    }
}

extension CompendiumIndexState.NextScreen: NavigationNode {
    var nodeId: String {
        navigationNode.nodeId
    }

    private var navigationNode: NavigationNode {
        get {
            switch self {
            case .compendiumIndex(let s): return s
            case .itemDetail(let s): return s
            case .compendiumImport(let s): return s
            case .safariView(let s): return s
            }
        }

        set {
            switch newValue {
            case let v as CompendiumIndexState: self = .compendiumIndex(v)
            case let v as CompendiumEntryDetailViewState: self = .itemDetail(v)
            case let v as CompendiumImportFeature.State: self = .compendiumImport(v)
            case let v as SafariViewState: self = .safariView(v)
            default: break
            }
        }
    }

    func topNavigationItems() -> [Any] {
        return navigationNode.topNavigationItems()
    }

    func navigationStackSize() -> Int {
        return navigationNode.navigationStackSize()
    }

    mutating func popLastNavigationStackItem() {
        navigationNode.popLastNavigationStackItem()
    }
}


extension CampaignBrowseViewState: NavigationNode {

    var nodeId: String { 
        navigationStackItemStateId
    }

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

    var presentedNextCampaignBrowse: CampaignBrowseViewState? {
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

    var presentedDetailCampaignBrowse: CampaignBrowseViewState? {
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
    var presentedNextEncounter: EncounterDetailViewState? {
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

    var presentedDetailEncounter: EncounterDetailViewState? {
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
extension CombatantDetailViewState: NavigationNode {

    var nodeId: String { 
        navigationStackItemStateId
    }

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

    var presentedNextCombatantTagsView: CombatantTagsViewState? {
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

    var presentedDetailCombatantTagsView: CombatantTagsViewState? {
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
    var presentedNextCombatantTagEditView: CombatantTagEditViewState? {
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

    var presentedDetailCombatantTagEditView: CombatantTagEditViewState? {
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
    var presentedNextCreatureEditView: CreatureEditViewState? {
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

    var presentedDetailCreatureEditView: CreatureEditViewState? {
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
    var presentedNextCombatantResourcesView: CombatantResourcesViewState? {
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

    var presentedDetailCombatantResourcesView: CombatantResourcesViewState? {
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
    var presentedNextRunningEncounterLogView: RunningEncounterLogViewState? {
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

    var presentedDetailRunningEncounterLogView: RunningEncounterLogViewState? {
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
    var presentedNextCompendiumItemDetailView: CompendiumEntryDetailViewState? {
        get { 
            if case .compendiumItemDetailView(let s) = presentedScreens[.nextInStack] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.nextInStack] = .compendiumItemDetailView(value) 
            }
        }
    }

    var presentedDetailCompendiumItemDetailView: CompendiumEntryDetailViewState? {
        get { 
            if case .compendiumItemDetailView(let s) = presentedScreens[.detail] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.detail] = .compendiumItemDetailView(value) 
            }
        }
    }
    var presentedNextSafariView: SafariViewState? {
        get { 
            if case .safariView(let s) = presentedScreens[.nextInStack] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.nextInStack] = .safariView(value) 
            }
        }
    }

    var presentedDetailSafariView: SafariViewState? {
        get { 
            if case .safariView(let s) = presentedScreens[.detail] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.detail] = .safariView(value) 
            }
        }
    }
}
extension CombatantTagsViewState: NavigationNode {

    var nodeId: String { 
        navigationStackItemStateId
    }

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
extension CompendiumEntryDetailViewState: NavigationNode {

    var nodeId: String { 
        navigationStackItemStateId
    }

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

    var presentedNextCompendiumItemDetailView: CompendiumEntryDetailViewState? {
        get { 
            if case .compendiumItemDetailView(let s) = presentedScreens[.nextInStack] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.nextInStack] = .compendiumItemDetailView(value) 
            }
        }
    }

    var presentedDetailCompendiumItemDetailView: CompendiumEntryDetailViewState? {
        get { 
            if case .compendiumItemDetailView(let s) = presentedScreens[.detail] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.detail] = .compendiumItemDetailView(value) 
            }
        }
    }
    var presentedNextSafariView: SafariViewState? {
        get { 
            if case .safariView(let s) = presentedScreens[.nextInStack] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.nextInStack] = .safariView(value) 
            }
        }
    }

    var presentedDetailSafariView: SafariViewState? {
        get { 
            if case .safariView(let s) = presentedScreens[.detail] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.detail] = .safariView(value) 
            }
        }
    }
}
extension CompendiumIndexState: NavigationNode {

    var nodeId: String { 
        navigationStackItemStateId
    }

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

    var presentedNextCompendiumIndex: CompendiumIndexState? {
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

    var presentedDetailCompendiumIndex: CompendiumIndexState? {
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
    var presentedNextItemDetail: CompendiumEntryDetailViewState? {
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

    var presentedDetailItemDetail: CompendiumEntryDetailViewState? {
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
    var presentedNextCompendiumImport: CompendiumImportFeature.State? {
        get { 
            if case .compendiumImport(let s) = presentedScreens[.nextInStack] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.nextInStack] = .compendiumImport(value) 
            }
        }
    }

    var presentedDetailCompendiumImport: CompendiumImportFeature.State? {
        get { 
            if case .compendiumImport(let s) = presentedScreens[.detail] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.detail] = .compendiumImport(value) 
            }
        }
    }
    var presentedNextSafariView: SafariViewState? {
        get { 
            if case .safariView(let s) = presentedScreens[.nextInStack] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.nextInStack] = .safariView(value) 
            }
        }
    }

    var presentedDetailSafariView: SafariViewState? {
        get { 
            if case .safariView(let s) = presentedScreens[.detail] {
                return s
            }
            return nil
        }
        set { 
            if let value = newValue {
                presentedScreens[.detail] = .safariView(value) 
            }
        }
    }
}
