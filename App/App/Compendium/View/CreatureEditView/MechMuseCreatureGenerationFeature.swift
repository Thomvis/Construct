import Foundation
import SwiftUI
import ComposableArchitecture
import GameModels
import Helpers
import MechMuse

struct MechMuseCreatureGenerationFeature: ReducerProtocol {
    struct State: Equatable, Identifiable {
        var id: UUID = UUID()
        @BindingState var prompt: String = ""
        @BindingState var isGenerating: Bool = false
        @BindingState var error: MechMuseError?
        var base: StatBlock

        // Result to apply
        var result: SimpleStatBlock?

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
            VStack(alignment: .leading, spacing: 12) {
                if let error = viewStore.state.error {
                    Text(error.attributedDescription).foregroundColor(.red)
                }

                Text("Mechanical Muse").bold()
                Text("Describe what to create or change about this creature.")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                TextEditor(text: viewStore.binding(\.$prompt))
                    .frame(minHeight: 120)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))

                HStack {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                    Spacer()
                    Button(action: { viewStore.send(.onGenerateButtonTap) }) {
                        if viewStore.isGenerating {
                            ProgressView()
                        } else {
                            Text("Generate")
                        }
                    }
                    .disabled(viewStore.isGenerating || viewStore.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
        }
    }
}


