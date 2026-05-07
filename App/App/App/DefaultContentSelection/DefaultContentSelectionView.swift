import Compendium
import ComposableArchitecture
import SwiftUI

struct DefaultContentSelectionView: View {
    @Bindable var store: StoreOf<DefaultContentSelectionFeature>
    var showsTitle: Bool = true
    var showsValidationMessage: Bool = true
    var showsSampleEncounterOption: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if showsTitle {
                Text("Load default content")
                    .font(.headline)
            }

            Text("Choose which rules edition content to load.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            editionCard(
                title: "Core 5e (2014)",
                subtitle: "SRD 5.1 / Basic Rules",
                isSelected: store.selection.include2014,
                isLoaded: store.has2014Document,
                isUpdateAvailable: store.has2014UpdateAvailable,
                action: { store.send(.toggle2014) }
            )
            .accessibilityIdentifier("default-content-card-2014")

            editionCard(
                title: "Core 5e (2024)",
                subtitle: "SRD 5.2 / Basic Rules",
                isSelected: store.selection.include2024,
                isLoaded: store.has2024Document,
                isUpdateAvailable: store.has2024UpdateAvailable,
                action: { store.send(.toggle2024) }
            )
            .accessibilityIdentifier("default-content-card-2024")

            if showsSampleEncounterOption, let sampleEncounterOption = store.sampleEncounterOption {
                HStack(spacing: 12) {
                    Text(sampleEncounterOption.title)
                        .font(.body.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Spacer(minLength: 8)

                    Toggle(
                        "",
                        isOn: Binding(
                            get: { sampleEncounterOption.isEnabled },
                            set: { store.send(.setSampleEncounterEnabled($0)) }
                        )
                    )
                    .labelsHidden()
                }
                .padding(12)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.top, 8)
                .accessibilityIdentifier("default-content-sample-toggle")
            }

            if showsValidationMessage && !store.isValidSelection {
                Text("Select at least one edition.")
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
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(subtitle)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                }

                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if isLoaded {
                    Text(isUpdateAvailable ? "Update available" : "Latest content loaded")
                        .font(.footnote)
                        .foregroundStyle(isUpdateAvailable ? Color.orange : .secondary)
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
