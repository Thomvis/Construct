import Foundation
import SharedViews
import SwiftUI
import ComposableArchitecture
import GameModels
import Helpers
import MechMuse
import CustomDump

struct MechMuseCreatureGenerationFeature: ReducerProtocol {
    struct State: Equatable, Identifiable {
        var id: UUID = UUID()
        @BindingState var prompt: String = ""
        @BindingState var isGenerating: Bool = false
        @BindingState var error: MechMuseError?
        var base: StatBlock

        // Result to apply
        var result: SimpleStatBlock?

        // Navigate to diff view after generation
        @BindingState var isShowingDiff: Bool = false

        static let nullInstance = State(base: .default)
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case onGenerateButtonTap
        case generated(SimpleStatBlock)
        case failed(MechMuseError)
        case onApplyButtonTap
        case onClose
    }

    @Dependency(\.mechMuse) var mechMuse

    var body: some ReducerProtocolOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onGenerateButtonTap:
                guard !state.isGenerating else { return .none }
                state.error = nil
                state.isGenerating = true
                let request = GenerateStatBlockRequest(
                    instructions: state.prompt,
                    base: SimpleStatBlock(statBlock: state.base)
                )
                return .run { send in
                    do {
                        var iterator = try mechMuse.generate(statBlock: request).makeAsyncIterator()
                        while let next = try await iterator.next() {
                            await send(.generated(next))
                        }
                    } catch {
                        let mmError = (error as? MechMuseError) ?? .unspecified
                        await send(.failed(mmError))
                    }
                }
            case .generated(let simple):
                state.result = simple
                state.isGenerating = false
                state.isShowingDiff = true
                return .none
            case .failed(let err):
                state.error = err
                state.isGenerating = false
                return .none
            case .onApplyButtonTap:
                return .none
            case .onClose:
                return .none
            case .binding:
                return .none
            }
        }
    }
}

struct MechMuseCreatureGenerationSheet: View {
    let store: StoreOf<MechMuseCreatureGenerationFeature>
    @SwiftUI.Environment(\.presentationMode) private var presentationMode

    var body: some View {
        WithViewStore(store) { viewStore in
            VStack(spacing: 12) {
                if let error = viewStore.state.error {
                    NoticeView(notice: .error(error.attributedDescription))
                }

                TextEditor(text: viewStore.binding(\.$prompt))
                    .frame(minHeight: 120)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))


                Button(action: {
                    viewStore.send(.onGenerateButtonTap)
                }) {
                    if viewStore.isGenerating {
                        ProgressView()
                    } else {
                        Text("Generate")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 8)
                .disabled(viewStore.isGenerating || viewStore.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            }
            .padding()
            .navigationDestination(isPresented: viewStore.binding(\.$isShowingDiff)) {
                MechMuseCreatureDiffView(store: store)
            }
        }
        .navigationTitle("Generate stats")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}


struct MechMuseCreatureDiffView: View {
    let store: StoreOf<MechMuseCreatureGenerationFeature>

    var body: some View {
        WithViewStore(store) { viewStore in
            let baseSimple = SimpleStatBlock(statBlock: viewStore.state.base)
            let target = viewStore.state.result ?? baseSimple
            let diffText = diff(baseSimple, target) ?? ""

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(diffText.split(separator: "\n", omittingEmptySubsequences: false).enumerated().map({ ($0.offset, String($0.element)) }), id: \.0) { _, line in
                        Text(line)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(color(for: line))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            .navigationTitle("Review changes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { viewStore.send(.onApplyButtonTap) }) {
                        Text("Accept").bold()
                    }
                    .disabled(viewStore.state.result == nil)
                }
            }
        }
    }

    private func color(for line: String) -> Color {
        if line.hasPrefix("+ ") { return Color.green }
        if line.hasPrefix("- ") { return Color.red }
        if line.hasPrefix("− ") { return Color.red } // U+2212 minus
        return Color.primary
    }
}



