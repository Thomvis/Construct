import Foundation
import SharedViews
import SwiftUI
import ComposableArchitecture
import GameModels
import Helpers
import MechMuse
import CustomDump
import Tagged

@Reducer
struct MechMuseCreatureGenerationFeature {
    @ObservableState
    struct State: Equatable, Identifiable {
        var id: UUID = UUID()
        var prompt: String = ""
        let base: StatBlock
        var mechMuseIsConfigured = true

        var revisions: IdentifiedArrayOf<Revision> = []

        @Presents var preview: Preview.State? = nil

        var isGenerating: Bool {
            revisions.last?.result.isLoading == true
        }

        var promptIsValid: Bool {
            !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        var error: MechMuseError? {
            if !mechMuseIsConfigured {
                return MechMuseError.unconfigured
            }
            return revisions.last?.result.error
        }

        mutating func preview(_ revisionId: Revision.Id) {
            guard let revisionIdx = revisions.index(id: revisionId), let statBlock = revisions[id: revisionId]?.result.value else {
                return
            }

            let previous: SimpleStatBlock? = if revisionIdx > 0 {
                revisions[revisionIdx-1].result.value
            } else {
                nil
            }

            preview = .init(
                statBlock: statBlock,
                previous: previous,
                base: SimpleStatBlock(statBlock: base)
            )
        }

        static let nullInstance = State(base: .default)

        struct Revision: Equatable, Identifiable {
            let id: Id
            let prompt: String
            var result = Async<SimpleStatBlock, MechMuseError>.State.initial // Async is only used for state, not for its reducer

            public typealias Id = Tagged<Revision, UUID>
        }
    }

    @CasePathable
    enum Action: BindableAction, Equatable {
        case onAppear
        case binding(BindingAction<State>)
        case onGenerationResultTap(State.Revision.Id)
        case onGenerateButtonTap
        case onCancelGenerateButtonTap
        case onRestorePromptButtonTap(State.Revision.Id)
        case onGenerateDidFinish(State.Revision.Id, Result<SimpleStatBlock, MechMuseError>)
        case onGenerationResultAccepted(StatBlock)

        case preview(PresentationAction<Preview.Action>)
    }

    private enum CancelID { case load }

    @Dependency(\.mechMuse) var mechMuse

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce<State, Action> { state, action in
            switch action {
            case .onAppear:
                state.mechMuseIsConfigured = mechMuse.isConfigured
                return .none
            case .onGenerationResultTap(let revisionId):
                if let revisionIdx = state.revisions.firstIndex(where: { $0.id == revisionId }),
                   let statBlock = state.revisions[revisionIdx].result.value {
                    let previous: SimpleStatBlock? = if revisionIdx > 0 {
                        state.revisions[revisionIdx-1].result.value
                    } else {
                        nil
                    }
                    state.preview = .init(
                        statBlock: statBlock,
                        previous: previous,
                        base: SimpleStatBlock(statBlock: state.base)
                    )
                }
                return .none
            case .onGenerateButtonTap:
                guard state.promptIsValid else { return .none }

                var revision = State.Revision(
                    id: .init(),
                    prompt: state.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                revision.result.isLoading = true
                state.revisions.append(revision)

                // Build request with base statblock and revisions (prompt-generated statblock pairs)
                let request = GenerateStatBlockRequest(
                    base: SimpleStatBlock(statBlock: state.base),
                    revisions: state.revisions.compactMap { revision in
                        revision.result.value.map { statBlock in
                            (revision.prompt, statBlock)
                        }
                    },
                    instructions: state.prompt
                )

                state.prompt = ""

                return .run { [revision] send in
                    do {
                        let result = try await mechMuse.generate(statBlock: request)
                        if let result {
                            await send(.onGenerateDidFinish(revision.id, .success(result)), animation: .default)
                        } else {
                            await send(.onGenerateDidFinish(revision.id, .failure(.unspecified)), animation: .default)
                        }
                    } catch let error as MechMuseError {
                        await send(.onGenerateDidFinish(revision.id, .failure(error)))
                    } catch {
                        await send(.onGenerateDidFinish(revision.id, .failure(.unspecified)))
                    }
                }
                .cancellable(id: CancelID.load)
            case .onCancelGenerateButtonTap:
                guard let lastRevision = state.revisions.last, lastRevision.result.isLoading else {
                    return .none
                }

                state.prompt = lastRevision.prompt
                state.revisions.remove(lastRevision)
                return .cancel(id: CancelID.load)
            case .onRestorePromptButtonTap(let revisionId):
                guard !state.isGenerating else { return .none }

                if let revisionIdx = state.revisions.firstIndex(where: { $0.id == revisionId }) {
                    state.prompt = state.revisions[revisionIdx].prompt
                    state.revisions.removeSubrange(revisionIdx...)
                }
                return .none
            case .onGenerateDidFinish(let revisionId, let result):
                if let revisionIdx = state.revisions.firstIndex(where: { $0.id == revisionId }) {
                    state.revisions[revisionIdx].result.result = result
                    state.revisions[revisionIdx].result.isLoading = false

                    // redirect to preview
                    if state.preview == nil {
                        state.preview(revisionId)
                    }
                }
                return .none
            case .preview(.presented(.onAcceptButtonTap)):
                guard let statBlock = state.preview?.statBlock else { return .none }
                return .send(.onGenerationResultAccepted(statBlock))
            case .onGenerationResultAccepted: return .none // handled by parent
            case .preview: return .none // handled below
            case .binding: return .none
            }
        }
        .ifLet(\.$preview, action: \.preview) {
            Preview()
        }
    }
}

struct MechMuseCreatureGenerationSheet: View {
    @SwiftUI.Environment(\.presentationMode) private var presentationMode

    @ScaledMetric(relativeTo: .body) var placeholderPadding = 4
    @ScaledMetric(relativeTo: .callout) var ellipsisOffset = 1

    @Bindable var store: StoreOf<MechMuseCreatureGenerationFeature>

    var body: some View {
        VStack {
            ScrollView {

                // Messages
                LazyVStack(spacing: 22) {
                    ForEach(store.revisions, id: \.id) { revision in
                        // user message
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(revision.prompt)
                                .multilineTextAlignment(.leading)

                            Menu {
                                Button {
                                    store.send(.onRestorePromptButtonTap(revision.id))
                                } label: {
                                    Text("Restore prompt")
                                }
                            } label: {
                                Image(systemName: "arrow.uturn.backward")
                            }
                            .disabled(store.isGenerating)
                        }
                        .padding(8)
                        .foregroundStyle(.secondary)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3))
                                .fill(Color(UIColor.secondarySystemBackground))
                        )
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.leading, 22)

                        // model response
                        if let result = revision.result.value {
                            Button {
                                store.send(.onGenerationResultTap(revision.id))
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(result.name)
                                        Text("Generated stat block")
                                            .font(.footnote)
                                    }
                                    Image(systemName: "chevron.right")
                                }
                                .padding(6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.3))
                                        .fill(Color(UIColor.secondarySystemBackground))
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .transition(.opacity)
                        }
                    }

                    // Status
                    if store.isGenerating {
                        HStack {
                            Text("Generating")

                            Image(systemName: "ellipsis")
                                .symbolEffect(.variableColor.cumulative)
                                .offset(x: -7*ellipsisOffset, y: 4*ellipsisOffset)
                                .fontWeight(.light)
                        }
                        .foregroundStyle(.secondary)
                        .font(.callout)
                        .padding(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            .background {
                if store.revisions.isEmpty {
                    VStack(spacing: 12) {
                        Text("I can adapt, reskin and buff creatures or conjure up completely new ones. Tell me what you need.")
                            .italic()
                        Text("- Mechanical Muse")
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding()
                }
            }

            if let error = store.error {
                NoticeView(notice: .error(error.attributedDescription))
                    .padding([.leading, .trailing])
            }

            // Editor
            VStack(spacing: 12) {

                VStack {
                    TextEditor(text: $store.prompt)
                        .disabled(store.isGenerating)
                        .overlay(alignment: .topLeading) {
                            if store.prompt.isEmpty {
                                Text("Adapt, reskin, buff or conjure...")
                                    .foregroundStyle(.secondary)
                                    .padding(EdgeInsets(top: placeholderPadding*2, leading: placeholderPadding, bottom: 0, trailing: 0))
                            }
                        }
                        .frame(minHeight: 50)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        Spacer()

                        if store.isGenerating {
                            Button {
                                store.send(.onCancelGenerateButtonTap, animation: .spring)
                            } label: {
                                Image(systemName: "stop.circle.fill")
                            }
                        } else {
                            Button {
                                store.send(.onGenerateButtonTap, animation: .spring)
                            } label: {
                                Image(systemName: "arrow.up.circle.fill")
                            }
                            .disabled(store.isGenerating || !store.promptIsValid)
                        }
                    }
                    .font(.title)
                    .padding(4)
                }
                .disabled(!store.mechMuseIsConfigured)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
            }
        }
        .padding()
        .geometryGroup()
        .onAppear {
            store.send(.onAppear)
        }
        .navigationTitle("Generate stats")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(
            item: $store.scope(state: \.preview, action: \.preview)
        ) { store in
            MechMuseCreatureGenerationPreview(store: store)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

extension MechMuseCreatureGenerationFeature {
    @Reducer
    struct Preview {
        @ObservableState
        struct State: Equatable {
            let statBlock: StatBlock
            let diffWithPrevious: AttributedString?
            let diffWithBase: AttributedString?

            var mode: Mode = .statBlock

            public init(
                statBlock: SimpleStatBlock,
                previous: SimpleStatBlock?,
                base: SimpleStatBlock
            ) {
                self.statBlock = statBlock.toStatBlock()
                self.diffWithPrevious = previous.flatMap {
                    diff($0, statBlock)?.nonEmptyString?.colorizedDiffString()
                }
                self.diffWithBase = diff(base, statBlock)?.nonEmptyString?.colorizedDiffString()
            }

            func modeIsAvailable(_ mode: Mode) -> Bool {
                switch mode {
                case .statBlock: return true
                case .diffWithPrevious: return diffWithPrevious != nil
                case .diffWithBase: return diffWithBase != nil
                }
            }

            enum Mode: Int, Equatable, CaseIterable {
                case statBlock
                case diffWithPrevious
                case diffWithBase

                var localizedDisplayName: String {
                    switch self {
                    case .statBlock: return NSLocalizedString("Stat block", comment: "MechMuseCreatureGenerationFeature.Preview.State.Mode.statBlock")
                    case .diffWithPrevious: return NSLocalizedString("Diff with previous", comment: "MechMuseCreatureGenerationFeature.Preview.State.Mode.diffWithPrevious")
                    case .diffWithBase: return NSLocalizedString("Diff with base", comment: "MechMuseCreatureGenerationFeature.Preview.State.Mode.diffWithBase")
                    }
                }
            }
        }

        enum Action: Equatable, BindableAction {
            case onAcceptButtonTap

            case binding(BindingAction<State>)
        }

        var body: some ReducerOf<Self> {
            Reduce { state, action in
                return .none
            }

            BindingReducer()
        }
    }
}

extension String {
    func colorizedDiffString(_ diffFormat: DiffFormat = .default) -> AttributedString {
        // loop over each line
        var result = AttributedString(self)
        var lineStart = result.startIndex

        while lineStart < result.endIndex {
            // Find end of the current line (exclude the newline itself)
            let newlineIndex = result.characters[lineStart...].firstIndex(of: "\n")
            let lineEnd = newlineIndex ?? result.endIndex
            let lineRange = lineStart..<lineEnd

            // Find first non-whitespace character on the line
            var firstIdx = lineStart
            while firstIdx < lineEnd, result.characters[firstIdx].isWhitespace {
                firstIdx = result.index(firstIdx, offsetByCharacters: Int(1))
            }

            if firstIdx < lineEnd {
                let firstChar = result.characters[firstIdx]
                switch String(firstChar) {
                case diffFormat.second:
                    result[lineRange].foregroundColor = Color.green
                case diffFormat.first:
                    result[lineRange].foregroundColor = Color.red
                default:
                    break
                }
            }

            // Move to the start of the next line (skip the newline char if present)
            if let nl = newlineIndex {
                lineStart = result.index(nl, offsetByCharacters: Int(1))
            } else {
                break
            }
        }
        return result
    }
}

struct MechMuseCreatureGenerationPreview: View {
    @Bindable var store: StoreOf<MechMuseCreatureGenerationFeature.Preview>

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                Menu {
                    ForEach(MechMuseCreatureGenerationFeature.Preview.State.Mode.allCases, id: \.rawValue) { mode in
                        Button {
                            store.send(.set(\.mode, mode))
                        } label: {
                            Label(mode.localizedDisplayName, systemImage: store.mode == mode ? "checkmark" : "")
                        }
                        .disabled(!store.state.modeIsAvailable(mode))
                    }
                } label: {
                    Label(store.mode.localizedDisplayName, systemImage: "square.and.line.vertical.and.square.filled")
                        .labelStyle(.titleAndIcon)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)

                if store.mode == .statBlock {
                    SectionContainer {
                        StatBlockView(stats: store.statBlock)
                    }
                } else {
                    ZStack {
                        if store.mode == .diffWithPrevious, let diffWithPrevious = store.diffWithPrevious {
                            Text(diffWithPrevious)
                        } else if store.mode == .diffWithBase, let diffWithBase = store.diffWithBase {
                            Text(diffWithBase)
                        }
                    }
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                }
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Accept") {
                    store.send(.onAcceptButtonTap)
                }
            }
        }
    }
}

#if DEBUG
struct MechMuseCreatureGenerationFeature_Preview: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            MechMuseCreatureGenerationSheet(
                store: Store(
                    initialState: .init(
                        id: UUID(),
                        prompt: "",
                        base: StatBlock(
                            name: "Goblin",
                            armor: [],
                            savingThrows: [:],
                            skills: [:],
                            features: [],
                            actions: [
                                CreatureAction(id: UUID(), name: "Scimitar", description: "Melee Weapon Attack: +4 to hit, reach 5 ft., one target. Hit: 5 (1d6 + 2) slashing damage."),
                                CreatureAction(id: UUID(), name: "Shortbow", description: "Ranged Weapon Attack: +4 to hit, range 80/320 ft., one target. Hit: 5 (1d6 + 2) piercing damage.")
                            ],
                            reactions: []
                        ),
                        revisions: IdentifiedArrayOf<MechMuseCreatureGenerationFeature.State.Revision>()
                    )
                ) {
                    MechMuseCreatureGenerationFeature()
                }
            )
        }
    }

}
#endif
