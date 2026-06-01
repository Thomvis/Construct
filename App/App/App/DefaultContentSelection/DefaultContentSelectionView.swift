import Compendium
import ComposableArchitecture
import GameModels
import SwiftUI

struct DefaultContentSelectionView: View {
    @Bindable var store: StoreOf<DefaultContentSelectionFeature>
    var prompt: String? = nil
    var footer: String? = nil
    var primaryButtonTitle: String? = nil
    var primaryAction: (() -> Void)? = nil
    var showsNewContentStatus: Bool = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let prompt {
                    Text(prompt)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                ForEach(DefaultContentRuleset.allCases, id: \.self) { ruleset in
                    editionCard(
                        ruleset: ruleset,
                        action: { store.send(.toggleRuleset(ruleset)) }
                    )
                }
                
                if let restoreSampleEncounter = store.restoreSampleEncounter {
                    SampleEncounterOptionRow(isEnabled: restoreSampleEncounter) {
                        store.send(.setSampleEncounterEnabled($0))
                    }
                    .padding(.top, 8)
                }
                
                if let error = store.applySelection.error {
                    Text(error.localizedDescription)
                        .font(.footnote)
                        .foregroundStyle(Color.red)
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .center) {
                if let primaryButtonTitle, let primaryAction {
                    Button(action: primaryAction) {
                        HStack(spacing: 6) {
                            if store.applySelection.isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            }

                            Text(store.applySelection.isLoading ? "Importing..." : primaryButtonTitle)
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!store.isValidSelection || store.applySelection.isLoading)
                }
                
                if let footer {
                    Text(footer)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
        }
        .onAppear {
            store.send(.onAppear)
        }
    }
    
    @ViewBuilder
    private func editionCard(
        ruleset: DefaultContentRuleset,
        action: @escaping () -> Void
    ) -> some View {
        let isSelected = store.selection.contains(ruleset)
        let versions = store.importedDefaultContentVersions.value

        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title(for: ruleset))
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                }

                Text(subtitle(for: ruleset))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                let isImported = versions?.rulesets.contains(ruleset) ?? false
                let isUpdateAvailable = isImported && versions.map { vs in vs.filter(on: ruleset) != DefaultContentVersions.current.filter(on: ruleset) } ?? false
                let statuses = editionStatuses(
                    ruleset: ruleset,
                    isImported: isImported,
                    isUpdateAvailable: isUpdateAvailable
                )
                
                if !statuses.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(statuses) { status in
                            statusBadge(status)
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.6) : Color(UIColor.separator), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(store.applySelection.isLoading)
    }

    private func title(for ruleset: DefaultContentRuleset) -> String {
        switch ruleset {
        case .rules2014: CompendiumSourceDocument.srd5_1.displayName
        case .rules2024: CompendiumSourceDocument.srd5_2.displayName
        }
    }

    private func subtitle(for ruleset: DefaultContentRuleset) -> String {
        switch ruleset {
        case .rules2014: "600+ monsters and spells from the original 2014 release of 5th Edition"
        case .rules2024: "600+ monsters and spells from the 2024 revision of 5th Edition"
        }
    }

    private struct EditionStatus: Identifiable {
        var text: String
        var color: Color

        var id: String { text }
    }

    private func editionStatuses(
        ruleset: DefaultContentRuleset,
        isImported: Bool,
        isUpdateAvailable: Bool
    ) -> [EditionStatus] {
        var result: [EditionStatus] = []

        if ruleset == .rules2024 {
            result.append(EditionStatus(text: "Beta", color: .purple))
        }

        if isUpdateAvailable {
            result.append(EditionStatus(text: "Update available", color: .orange))
        } else if isImported {
            result.append(EditionStatus(text: "Previously imported", color: .secondary))
        } else if showsNewContentStatus {
            result.append(EditionStatus(text: "New", color: .accentColor))
        }

        return result
    }

    private func statusBadge(_ status: EditionStatus) -> some View {
        Text(status.text)
            .font(.footnote)
            .foregroundStyle(Color.white)
            .padding(EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8))
            .background(Capsule().fill(status.color))
    }
}

struct DefaultContentSelectionPage: View {
    @Bindable var store: StoreOf<DefaultContentSelectionFeature>
    var primaryAction: () -> Void
    var skipAction: () -> Void

    var body: some View {
        NavigationStack {
            DefaultContentSelectionView(
                store: store,
                prompt: "Choose your preferred edition (or both). The monsters and spells from the Basic Rules will be imported into your compendium.",
                footer: "You can import additional content later in the compendium. Basic Rules content is managed in Settings.",
                primaryButtonTitle: "Import",
                primaryAction: primaryAction,
                showsNewContentStatus: false
            )
            .navigationTitle("Select edition")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip", action: skipAction)
                }
            }
        }
    }
}

struct DefaultContentSelectionSheet: View {
    @Bindable var store: StoreOf<DefaultContentSelectionFeature>
    var cancelButtonTitle: String?
    var cancelAction: (() -> Void)?
    var primaryButtonTitle: String

    var body: some View {
        NavigationStack {
            DefaultContentSelectionView(
                store: store,
                prompt: "There are updates available for Basic Rules content with improvements to monster stat blocks and/or spell properties. Existing items with the same name will be overwritten.",
                primaryButtonTitle: primaryButtonTitle,
                primaryAction: {
                    store.send(.applySelection)
                }
            )
            .navigationTitle("Rules content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let cancelButtonTitle, let cancelAction {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(cancelButtonTitle, action: cancelAction)
                    }
                }
            }
        }
    }
}

struct SampleEncounterOptionRow: View {
    var isEnabled: Bool
    var titleFont: Font = .body.bold()
    var setEnabled: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Sample encounter")
                    .font(titleFont)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text("Start with something ready to explore")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Toggle(
                "",
                isOn: Binding(
                    get: { isEnabled },
                    set: setEnabled
                )
            )
            .labelsHidden()
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            DefaultContentSelectionView(
                store: Store(initialState: .init()) {
                    DefaultContentSelectionFeature()
                }
            )
            .padding()
        }
    }
}
