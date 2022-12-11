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

                ScrollView {
                    ZStack {
                        if let description = viewStore.state.descriptionString {
                            Text("“\(description)”")
                                .padding(6)
                                .background(Color(UIColor.secondarySystemBackground).cornerRadius(4))
                                .opacity(isLoading ? 0.15 : 1.0)
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
                    BetaLabel()

                    Spacer()

                    HStack {
                        if viewStore.state.descriptionString != nil {
                            Button {
                                viewStore.send(.description(.reload))
                            } label: {
                                Image(systemName: "arrow.clockwise.circle.fill")
                            }
                            .padding(2)
                        }

                        configButton(viewStore)
                    }
                    .disabled(isLoading)
                }
            }
        }
    }

    @ViewBuilder
    func configButton(
        _ viewStore: ViewStore<ActionDescriptionViewState, ActionDescriptionViewAction>
    ) -> some View {
        Menu {
            Picker("Tone of Voice", selection: viewStore.binding(\.$settings.toneOfVoice)) {
                ForEach(ToneOfVoice.allCases, id: \.rawValue) { tov in
                    Text(tov.rawValue.capitalized).tag(tov)
                }
            }

            Divider()

            Picker("Outcome", selection: viewStore.binding(\.$settings.outcome)) {
                Text("Hit").tag(ActionDescriptionViewState.Settings.OutcomeSetting.hit)
                Text("Miss").tag(ActionDescriptionViewState.Settings.OutcomeSetting.miss)
            }
            .disabled(viewStore.context.diceAction == nil)

        } label: {
            Button {

            } label: {
                Image(systemName: "gearshape.fill")
                    .padding(1)
            }
        }
    }
}
