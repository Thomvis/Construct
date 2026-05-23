import Compendium
import ComposableArchitecture
import GameModels
import SwiftUI

struct DefaultContentSelectionView: View {
    @Bindable var store: StoreOf<DefaultContentSelectionFeature>
    var showsTitle: Bool = true
    var showsValidationMessage: Bool = true
    var showsSampleEncounterOption: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if showsTitle {
                Text("Choose rules content")
                    .font(.headline)
            }

            Text(prompt)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            editionCard(
                title: CompendiumRealm.core.displayName,
                subtitle: CompendiumSourceDocument.srd5_1.displayName,
                isSelected: store.selection.include2014,
                isLoaded: store.has2014Document,
                isUpdateAvailable: store.has2014UpdateAvailable,
                action: { store.send(.toggle2014) }
            )
            .accessibilityIdentifier("default-content-card-2014")

            editionCard(
                title: CompendiumRealm.core2024.displayName,
                subtitle: CompendiumSourceDocument.srd5_2.displayName,
                isSelected: store.selection.include2024,
                isLoaded: store.has2024Document,
                isUpdateAvailable: store.has2024UpdateAvailable,
                action: { store.send(.toggle2024) }
            )
            .accessibilityIdentifier("default-content-card-2024")

            if showsSampleEncounterOption, let sampleEncounterOption = store.sampleEncounterOption {
                SampleEncounterOptionRow(option: sampleEncounterOption) {
                    store.send(.setSampleEncounterEnabled($0))
                }
                .padding(.top, 8)
            }

            if showsValidationMessage && !store.isValidSelection {
                Text("Select at least one rules set.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let error = store.error {
                Text(error.localizedDescription)
                    .font(.footnote)
                    .foregroundStyle(Color.red)
            }

            if store.isImporting {
                ProgressView("Importing content...")
                    .font(.footnote)
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
    }

    private var prompt: String {
        if store.has2014UpdateAvailable || store.has2024UpdateAvailable {
            "Updates are available for your installed Basic Rules content."
        } else if store.has2014Document || store.has2024Document {
            "Keep the content you use, or add another rules set."
        } else {
            "Import the Basic Rules/SRD content you want in the compendium."
        }
    }

    @ViewBuilder
    private func editionCard(
        title: String,
        subtitle: String,
        isSelected: Bool,
        isLoaded: Bool,
        isUpdateAvailable: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                }

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let status = editionStatus(
                    isSelected: isSelected,
                    isLoaded: isLoaded,
                    isUpdateAvailable: isUpdateAvailable
                ) {
                    Text(status.text)
                        .font(.footnote)
                        .foregroundStyle(status.color)
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
        .disabled(store.isImporting)
    }

    private func editionStatus(
        isSelected: Bool,
        isLoaded: Bool,
        isUpdateAvailable: Bool
    ) -> (text: String, color: Color)? {
        if isSelected, isUpdateAvailable {
            ("Will update", .orange)
        } else if isSelected, !isLoaded {
            ("Will import", .accentColor)
        } else if isUpdateAvailable {
            ("Update available", .orange)
        } else if isLoaded {
            ("Installed", .secondary)
        } else {
            nil
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
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    DefaultContentSelectionView(
                        store: store,
                        showsTitle: false,
                        showsValidationMessage: false
                    )

                    Button(action: {
                        store.send(.applySelection)
                    }) {
                        Text(primaryButtonTitle)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!store.isValidSelection || store.isImporting)

                    Text("Select at least one rules set.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, minHeight: 18, alignment: .center)
                        .opacity(store.isValidSelection ? 0 : 1)
                        .accessibilityHidden(store.isValidSelection)
                }
                .padding()
            }
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
    var option: DefaultContentSelectionFeature.State.SampleEncounterOption
    var titleFont: Font = .body.bold()
    var setEnabled: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(option.title)
                    .font(titleFont)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if let subtitle = option.subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            Toggle(
                "",
                isOn: Binding(
                    get: { option.isEnabled },
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
                store: Store(initialState: .init(selection: .both)) {
                    DefaultContentSelectionFeature()
                }
            )
            .padding()
        }
    }
}
