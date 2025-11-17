# Navigation → PresentationState Task Log

_Status: tree-based PresentationState navigation is now adopted across Campaign, Compendium, and Combatant flows (updated 2025-11-17)._

## Legacy helper stack (for reference)
- `Sources/Helpers/Navigation.swift` introduces `NavigationStackItemState`, `NavigationStackSourceState`, and `NavigationStackSourceAction`. Every stack source keeps a `[NavigationDestination: NextScreen]` dictionary to represent both “push” (`.nextInStack`) and “detail`” destinations, plus helpers like `nextScreen`/`detailScreen`.
- `stateDrivenNavigationLink` (same file) wraps `SwiftUINavigation.navigationDestination` to bind directly to `presentedScreens[.nextInStack]`. It scopes into the destination via `CasePath` lookups and dispatches `.presentScreen(.nextInStack, …)` and `.presentedScreen(.nextInStack, …)` actions.
- `NavigationNode` (protocol + Sourcery helpers) lets parent features inspect and mutate child stacks (`topNavigationItems()`, `navigationStackSize()`, `popLastNavigationStackItem()`). This is consumed by the tab/column navigation reducers, `ReferenceView`, and `EntityChangeObserver`.
- There is no remaining `StateDrivenNavigationView`; only `NavigationRowButton` lives in `App/App/UI/StateDrivenNavigationView.swift`.

## Sourcery-generated navigation utilities
- `SourceryTemplates/NavigationNode.stencil` + `sourcery-gen.sh` generate `App/App/Sourcery/NavigationNode.generated.swift` (~900 lines). That file adds:
  - `NavigationNode` conformances for every `NavigationStackItemState`.
  - Dozens of computed properties (`presentedNextEncounter`, `presentedDetailEncounter`, etc.) that map individual `NextScreen` enum cases into strongly-typed optional properties for both `.nextInStack` and `.detail`.
  - Recursive implementations of `topNavigationItems()`, `navigationStackSize()`, and `popLastNavigationStackItem()` for every state that participates in navigation.
- These generated accessors are used in multiple places today:
  - `App/App/App/AppState.swift` chooses the active tab and updates crash-report prompts based on whether `EncounterDetailFeature.State` appears in `topNavigationItems()`.
  - `App/App/App/ColumnNavigationFeature.swift` + `App/App/App/TabNavigationFeature.swift` rely on `campaignBrowse.topNavigationItems()` to bridge the UIKit/SwiftUI multi-column UI.
  - `ReferenceContext`, `ReferenceViewFeature`, and `ReferenceItemViewState` walk `presentedNext…` / `topNavigationItems()` to keep the reference tabs in sync with the Campaign/Compendium stacks.
  - `App/App/App/EntityChangeObserver.swift` pulls `nextScreen` and `detailScreen` to determine which entities to persist after every reducer pass.

## Inventory of `NavigationStackSourceState` conformers
### CampaignBrowseViewFeature.State (`App/App/Campaign/View/CampaignBrowseFeature.swift`)
- `NextScreen` cases: `.campaignBrowse(State)` and `.encounter(EncounterDetailFeature.State)`.
- `CampaignBrowseView` pushes nested campaign browsers and encounter detail screens via two `.stateDrivenNavigationLink` modifiers, using `NavigationRowButton` to set `.setNextScreen`.
- `ReferenceContext` consumes `presentedNextCampaignBrowse` / `presentedNextEncounter` (and their `.detail` counterparts) to propagate encounter context to the floating Reference view. Column navigation also inspects `topNavigationItems()` here.
- `detailScreen` is wired through the reducer but there are **no** call sites that ever send `.setDetailScreen` or `.presentScreen(.detail, …)`; it appears to be vestigial.

### CompendiumIndexFeature.State (`App/App/Compendium/View/CompendiumIndexFeature.swift`)
- `NextScreen` cases: `.compendiumIndex(State)`, `.itemDetail(CompendiumEntryDetailFeature.State)`, `.safariView(SafariViewState)`.
- `CompendiumIndexView` presents item detail via a single `.stateDrivenNavigationLink`, manually setting `.setNextScreen(.itemDetail(…))` when a row is tapped. `.presentedNextSafariView` powers an in-view Safari sheet.
- `CompendiumIndexFeature` recursively scopes into another Compendium index (for “stacking” compendium contexts). `ReferenceContext`, `ReferenceItemViewState`, and `ReferenceView` all rely on `presentedNextItemDetail` / `presentedNextCompendiumIndex` for tab titles and open-reference bookkeeping.
- Similar to the campaign feature, the reducer stores `.detail` screens but nothing in the tree ever calls `.setDetailScreen` or `.presentScreen(.detail, …)`.

### CompendiumEntryDetailFeature.State (`App/App/Compendium/View/CompendiumEntryDetailViewState.swift`)
- `NextScreen` cases: `.compendiumItemDetailView(State)` for nested references and `.safariView(SafariViewState)` for external links.
- `CompendiumEntryDetailView` adds a `.stateDrivenNavigationLink` for recursive pushes and uses the binding-based Safari helper to display `.presentedNextSafariView`.
- No live references send `.detailScreen` actions; the `detail` dictionary entry is never populated.

### CombatantDetailFeature.State (`App/App/Encouter/CombatantDetailViewState.swift`)
- `NextScreen` is large: `.combatantTagsView`, `.combatantTagEditView`, `.creatureEditView`, `.combatantResourcesView`, `.runningEncounterLogView`, `.compendiumItemDetailView`, `.safariView`.
- `CombatantDetailView` wires six `.stateDrivenNavigationLink` instances (one per destination) and a Safari sheet.
- The state mutates several generated `presentedNext…` properties in `combatant.didSet` to keep nested editors in sync (e.g. `presentedNextCombatantTagsView?.update(c)`), so we’ll need an equivalent mechanism when migrating.
- Again, `.detail` is unused—no caller dispatches `.setDetailScreen` or `.presentScreen(.detail, …)` anywhere in the repository.

### CombatantTagsFeature.State (`App/App/Combatant/CombatantTagsViewState.swift`)
- `NextScreen` only contains `CombatantTagEditFeature.State`.
- `CombatantTagsView` has a single `.stateDrivenNavigationLink(store: state: CasePath.self…)` to push the editor and relies on `.setNextScreen` + `.nextScreen` actions.
- No `.detail` usage beyond the default dictionary plumbing.

## Other `NavigationStackItemState` participants
- The generated file also covers every destination enum case referenced above: `EncounterDetailFeature.State`, `CreatureEditFeature.State`, `CombatantResourcesFeature.State`, `SafariViewState`, etc. Their only conformance requirements are `navigationStackItemStateId` and (optionally) `navigationTitle` / display mode.
- `AddCombatantFeature.State` and `AddCombatantState` hand-roll `topNavigationItems()` to expose their nested compendium state to the Reference view; they do **not** rely on `NavigationStackSourceState` but still expect a type-erased navigation tree they can interrogate.

## View-layer touch points
- `.stateDrivenNavigationLink` currently appears in: `CampaignBrowseView` (twice), `CombatantTagsView`, `CompendiumIndexView`, `CompendiumEntryDetailView`, and six times inside `CombatantDetailView`.
- All push-style flows go through that helper; no view calls `.presentScreen(.detail, …)` or `.setDetailScreen` directly.
- Safari presentation is still handled by the legacy dictionary: we store `.safariView` as the next screen and drive `BetterSafariView` via bindings to `presentedNextSafariView`.

## Detail-destination usage check
- Repository-wide search for `.presentScreen(.detail` or `.setDetailScreen(` yielded **zero** external call sites; only the reducers’ `switch` statements set `presentedScreens[.detail]`.
- Consumers like `ReferenceContext`, `EntityChangeObserver`, and `ReferenceItemViewState` still look at `presentedDetail…` properties, but those values are always `nil` today. This simplifies the migration because we can treat the new PresentationState stack as single-destination (`StackState`) without a special “detail” lane unless we reintroduce it later.

## Follow-ups after this audit
- Replace the dictionary-based navigation API with `@PresentationState` (stack + optional destinations) and migrate the reducers/views listed above.
- Rework `topNavigationItems()` / reference-context plumbing to read from the new `StackState` rather than the Sourcery-generated dictionary.
- Remove `Sources/Helpers/Navigation.swift`, `SwiftUINavigation` usage, the Sourcery template/generation script, and all generated accessors once every feature is on the new stack.

## PresentationState architecture (implemented)
Following TCA’s tree-based guidance (`Articles/TreeBasedNavigation.md`), every former `NavigationStackSourceState` feature now owns a single `@PresentationState var destination: Destination.State?` and optional `safari` (when needed). Each destination enum scopes into the appropriate reducer via `.ifLet(\.$destination, action: /Action.destination) { Destination() }`, and SwiftUI views drive navigation with `.navigationDestination(store:state:action:)`.

### Shared pattern
1. **Destination reducer per feature**  
   - Define `enum Destination: Equatable { case campaign(CampaignBrowseViewFeature.State), … }` alongside `struct Destination: Reducer` with matching `State`/`Action` enums.  
   - Replace `[NavigationDestination: NextScreen]` with a single `@PresentationState var destination: Destination.State?`. Keep additional `@PresentationState` properties for modals (sheets, alerts) as needed.
2. **Reducer composition**  
   - Parent reducers mutate `state.destination = .campaign(…)` (or `nil`) instead of `.setNextScreen`.  
   - Compose children via `.ifLet(\.$destination, action: /Action.destination) { Destination() }`, mirroring the “Integration” section of the tree-based doc.
3. **View integration**  
   - Swap `.stateDrivenNavigationLink` for `NavigationLinkStore`/`.navigationDestination(store:)`, e.g.:
     ```swift
     NavigationLinkStore(
       store.scope(state: \.$destination, action: { .destination($0) })
     ) { dest in
       switch dest {
       case .campaign:
         CaseLet(state: /Destination.State.campaign,
                 action: Destination.Action.campaign,
                 then: CampaignBrowseView.init)
       case .encounter:
         …
       }
     }
     ```
   - Buttons that used to call `.setNextScreen` will now populate `state.destination`.
4. **Safari & other transient destinations**  
   - Treat Safari as either its own destination case or a lightweight `@PresentationState var safari: SafariViewState?` depending on whether we need reducer composition. Either option uses the built-in `.sheet(store:)`/`.navigationDestination(store:)` overloads.

-### Replacing NavigationNode utilities
- Introduce a lightweight protocol (e.g. `NavigationTreeNode`) that exposes `var child: NavigationTreeNode?` plus `var navigationNodes: [Any]`. For each feature, implement:
  ```swift
  var navigationNodes: [Any] {
    if let destinationItems = destination?.navigationNodes { return [self] + destinationItems }
    return [self]
  }
  ```
- Update `ReferenceContext`, `ReferenceViewFeature`, `TabNavigationFeature`, `ColumnNavigationFeature`, and `EntityChangeObserver` to use the new tree helpers instead of Sourcery-generated accessors. Because we no longer track `.detail`, every consumer only needs to walk `destination`.
- Delete `NavigationNode.generated.swift` and the template after the migration.

### Features migrated
- `CombatantTagsFeature`, `CombatantDetailFeature`
- `CompendiumEntryDetailFeature`, `CompendiumIndexFeature`, and all Compendium container views
- `CampaignBrowseViewFeature` along with tab/column navigation, reference contexts, and entity observer plumbing

### Cleanup
- Removed `Sources/Helpers/Navigation.swift`, Sourcery templates, generated `NavigationNode` output, and the `swiftui-navigation` package dependency.
- Introduced `NavigationTreeNode` to keep `topNavigationItems()` introspection working for reference tabs and entity observers.
- Updated licenses/documentation to reflect the new setup.

## 2025-11-18
- Rebuilt the reverted `CombatantDetailFeature` reducer to its original shape and then re-applied the PresentationState migration so the debugging flow matches the user’s request (no extra helper reducers).
- Reconstructed `CompendiumEntryDetailFeature` without `presentedScreens`, introducing a recursive `Destination` reducer that scopes into new presentation state while keeping Safari handling as a side-car optional state.
- Updated `CompendiumItemReferenceTextAnnotation.handleTapReducer` to accept closures for the “internal” and “external” actions so call sites can drive `.setDestination` / `.setSafari` directly.
