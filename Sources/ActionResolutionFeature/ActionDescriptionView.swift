//
//  ActionDescriptionView.swift
//  
//
//  Created by Thomas Visser on 10/12/2022.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import MechMuse

struct ActionDescriptionView: View {
    @ScaledMetric(relativeTo: .body) var descriptionHeight = 300

    let store: Store<ActionDescriptionViewState, ActionDescriptionViewAction>

    var body: some View {
        WithViewStore(store) { viewStore in
            VStack {
                let isLoading = viewStore.state.isLoadingDescription
                let didFailLoading = viewStore.state.didFailLoading

                ScrollView {
                    ZStack {
                        if let description = viewStore.state.descriptionString {
                            (Text("Mechanical Muse says:\n\n") + Text("“\(description)”"))
                                .padding(10)
                                .background(Color(UIColor.secondarySystemBackground).cornerRadius(4))
                                .opacity(isLoading ? 0.15 : 1.0)
                        } else if let error = viewStore.state.descriptionErrorString {
                            Text(error)
                                .multilineTextAlignment(.center)
                                .padding(6)
                        }
                    }
                    .padding()
                    .frame(minHeight: descriptionHeight)
                }
                .overlay {
                    if isLoading {
                        ProgressView()
                    }
                }
                .frame(height: descriptionHeight)

                Divider()

                HStack {
                    FeedbackButton {
                        viewStore.send(.onFeedbackButtonTap)
                    }

                    Spacer()

                    HStack {
                        hitButton(viewStore)

                        impactButton(viewStore)

                        Button {
                            viewStore.send(.description(.reload))
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(viewStore.state.descriptionString == nil)
                    }
                    .font(.footnote)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .disabled(isLoading || didFailLoading)
                }
            }
        }
    }

    @ViewBuilder
    func hitButton(
        _ viewStore: ViewStore<ActionDescriptionViewState, ActionDescriptionViewAction>
    ) -> some View {
        Menu {
            Picker("Outcome", selection: viewStore.binding(\.$settings.outcome)) {
                Text("Hit").tag(ActionDescriptionViewState.Settings.OutcomeSetting.hit)
                Text("Miss").tag(ActionDescriptionViewState.Settings.OutcomeSetting.miss)
            }
            .disabled(viewStore.state.context.diceAction == nil)
        } label: {
            Text(viewStore.state.hitOrMissString)
        }
        .tint(viewStore.state.hitOrMissTint)
    }

    @ViewBuilder
    func impactButton(
        _ viewStore: ViewStore<ActionDescriptionViewState, ActionDescriptionViewAction>
    ) -> some View {
        Menu {
            Picker("Outcome", selection: viewStore.binding(\.$settings.impact)) {
                Text("Minimal").tag(CreatureActionDescriptionRequest.Impact.minimal)
                Text("Average").tag(CreatureActionDescriptionRequest.Impact.average)
                Text("Devastating").tag(CreatureActionDescriptionRequest.Impact.devastating)
            }
        } label: {
            Text(viewStore.state.impactString)
        }
        .tint(viewStore.state.impactTint)
        .disabled(!viewStore.state.effectiveOutcome.isHit)
    }
}

extension ActionDescriptionViewState {
    var hitOrMissTint: Color? {
        if effectiveOutcome.isHit {
            return Color(UIColor.systemRed)
        } else {
            return nil
        }
    }

    var impactTint: Color? {
        switch settings.impact {
        case .minimal: return nil
        case .average: return Color(UIColor.systemBlue)
        case .devastating: return Color(UIColor.systemPurple)
        }
    }
}
