import Compendium
import ComposableArchitecture
import GameModels
import SwiftUI

struct DefaultContentSelectionView: View {
    @Bindable var store: StoreOf<DefaultContentSelectionFeature>
    var title: String? = "Choose rules content"
    var titleFont: Font = .headline
    var footer: String? = nil
    var primaryButtonTitle: String? = nil
    var primaryAction: (() -> Void)? = nil
    var showsValidationMessage: Bool = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let title {
                    Text(title)
                        .font(titleFont)
                }
                
                Text(prompt)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                ForEach(DefaultContentRuleset.allCases, id: \.self) { ruleset in
                    editionCard(
                        ruleset: ruleset,
                        action: { store.send(.toggleRuleset(ruleset)) }
                    )
                    .accessibilityIdentifier(accessibilityIdentifier(for: ruleset))
                }
                
                if let restoreSampleEncounter = store.restoreSampleEncounter {
                    SampleEncounterOptionRow(isEnabled: restoreSampleEncounter) {
                        store.send(.setSampleEncounterEnabled($0))
                    }
                    .padding(.top, 8)
                }
                
                if primaryButtonTitle == nil,
                   showsValidationMessage,
                   !store.isValidSelection {
                    validationMessage
                }
                
                if let error = store.applySelection.error {
                    Text(error.localizedDescription)
                        .font(.footnote)
                        .foregroundStyle(Color.red)
                }
                
                if let error = store.defaultDocumentStatus.error {
                    Text(error.localizedDescription)
                        .font(.footnote)
                        .foregroundStyle(Color.red)
                }
                
                if store.defaultDocumentStatus.isLoading {
                    ProgressView("Checking installed content...")
                        .font(.footnote)
                }
                
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            VStack {
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
                    
                    if showsValidationMessage {
                        validationMessage
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: 18, alignment: .center)
                            .opacity(store.isValidSelection ? 0 : 1)
                            .accessibilityHidden(store.isValidSelection)
                    }
                }
                
                if let footer {
                    Text(footer)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding()
        }
        .onAppear {
            store.send(.onAppear)
        }
    }

    private var validationMessage: some View {
        Text("Select content to import.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private var prompt: String {
        if store.defaultDocumentStatus.value?.hasAnyImportAvailable == true {
            "New or updated SRD / Basic Rules content is available."
        } else if store.defaultDocumentStatus.value?.importedRulesets.isEmpty == false {
            "Keep the content you use, or add another rules set."
        } else {
            "Import the SRD / Basic Rules content you want in your compendium."
        }
    }

    @ViewBuilder
    private func editionCard(
        ruleset: DefaultContentRuleset,
        action: @escaping () -> Void
    ) -> some View {
        let isSelected = store.selection.contains(ruleset)
        let status = store.defaultDocumentStatus.value

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

                if let status = editionStatus(
                    isImported: status?.isImported(ruleset) ?? false,
                    isNewContent: status?.isNewContent(ruleset) ?? false,
                    isUpdateAvailable: status?.isUpdateAvailable(ruleset) ?? false
                ) {
                    Text(status.text)
                        .font(.footnote)
                        .foregroundStyle(Color.white)
                        .padding(EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6))
                        .background(Capsule().fill(status.color))
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
        case .rules2014:
            CompendiumRealm.core.displayName
        case .rules2024:
            CompendiumRealm.core2024.displayName
        }
    }

    private func subtitle(for ruleset: DefaultContentRuleset) -> String {
        switch ruleset {
        case .rules2014:
            CompendiumSourceDocument.srd5_1.displayName
        case .rules2024:
            CompendiumSourceDocument.srd5_2.displayName
        }
    }

    private func accessibilityIdentifier(for ruleset: DefaultContentRuleset) -> String {
        switch ruleset {
        case .rules2014:
            "default-content-card-2014"
        case .rules2024:
            "default-content-card-2024"
        }
    }

    private func editionStatus(
        isImported: Bool,
        isNewContent: Bool,
        isUpdateAvailable: Bool
    ) -> (text: String, color: Color)? {
        if isUpdateAvailable {
            ("Update available", .orange)
        } else if isNewContent {
            ("New", .accentColor)
        } else if isImported {
            ("Installed", .secondary)
        } else {
            nil
        }
    }
}

struct DefaultContentSelectionPage: View {
    @Bindable var store: StoreOf<DefaultContentSelectionFeature>
    var primaryAction: () -> Void

    var body: some View {
        DefaultContentSelectionView(
            store: store,
            title: "Choose rules content",
            titleFont: .title3.weight(.semibold),
            footer: "You can change this in Settings later.",
            primaryButtonTitle: "Continue",
            primaryAction: primaryAction
        )
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
                title: nil,
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
                Text("Add sample encounter")
                    .font(titleFont)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text("Get a taste of what Construct has to offer.")
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
        .accessibilityIdentifier("default-content-sample-toggle")
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            DefaultContentSelectionView(
                store: Store(initialState: .init(selection: Set(DefaultContentRuleset.allCases))) {
                    DefaultContentSelectionFeature()
                }
            )
            .padding()
        }
    }
}
