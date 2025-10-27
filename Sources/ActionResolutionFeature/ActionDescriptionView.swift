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
import SharedViews

struct ActionDescriptionView: View {
    @ScaledMetric(relativeTo: .body) var descriptionHeight = 300
    @ScaledMetric(relativeTo: .largeTitle) var speechBalloonOffset = 8
    @ScaledMetric(relativeTo: .footnote) var bottomButtonHeight = 16

    let store: StoreOf<ActionDescriptionFeature>

    var body: some View {
        WithViewStore(store, observe: \.self) { viewStore in
            VStack {
                let isLoading = viewStore.state.isLoadingDescription

                ScrollView(showsIndicators: false) {
                    ZStack {
                        if isLoading || viewStore.state.descriptionString != nil {
                            VStack(alignment: .trailing, spacing: 10) {
                                let description = viewStore.state.descriptionString
                                Text(description ?? "Generating attack description…")
                                    .foregroundColor(description == nil ? Color.secondary : Color.primary)
                                    .animation(nil, value: viewStore.state.descriptionString)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .overlay(alignment: .bottom) {
                                        if isLoading {
                                            AnimatingSymbol(systemName: "ellipsis")
                                                .transition(.opacity.animation(.default.speed(1.0)))
                                        }
                                    }
                                    .padding(12)
                                    .background(BoxedTextBackground())

                                Text("Mechanical Muse")
                                    .foregroundColor(Color.secondary)
                                    .font(.footnote)
                                    .padding(EdgeInsets(top: -10, leading: 0, bottom: 0, trailing: 15))
                            }
                            .transition(.opacity)
                        } else if let error = viewStore.state.descriptionErrorString {
                            NoticeView(notice: .error(error))
                                .frame(minHeight: descriptionHeight)
                        } else if viewStore.state.isMissingOutcomeSetting {
                            VStack {
                                Text("Did the attack hit or miss?")

                                EqualWidthLayout(spacing: 20) {
                                    Button {
                                        viewStore.send(.binding(.set(\.$settings.outcome, .hit)))
                                    } label: {
                                        Text("Hit").frame(maxWidth: .infinity)
                                    }
                                    .tint(hitOrMissTintHit)

                                    Button {
                                        viewStore.send(.binding(.set(\.$settings.outcome, .miss)))
                                    } label: {
                                        Text("Miss").frame(maxWidth: .infinity)
                                    }
                                    .tint(hitOrMissTintMiss)
                                }
                                .controlSize(.large)
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.capsule)
                            }
                            .frame(minHeight: descriptionHeight)
                        }
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
                        Group {
                            hitButton(viewStore)

                            impactButton(viewStore)
                        }
                        .disabled(isLoading || viewStore.state.isMissingOutcomeSetting)

                        Button {
                            viewStore.send(.onReloadOrCancelButtonTap)
                        } label: {
                            if isLoading {
                                Image(systemName: "xmark")
                                    .frame(height: bottomButtonHeight)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .frame(height: bottomButtonHeight)
                            }
                        }
                        .disabled(viewStore.state.isMissingOutcomeSetting)
                    }
                    .font(.footnote)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                }
            }
            .onAppear {
                viewStore.send(.onAppear)
            }
            .onDisappear {
                viewStore.send(.onDisappear)
            }
        }
    }

    @ViewBuilder
    func hitButton(
        _ viewStore: ViewStoreOf<ActionDescriptionFeature>
    ) -> some View {
        if viewStore.settings.outcome != nil {
            Menu {
                Picker("Outcome", selection: viewStore.$settings.outcome) {
                    Text("Hit").tag(Optional<ActionDescriptionFeature.State.Settings.OutcomeSetting>.some(.hit))
                    Text("Miss").tag(Optional<ActionDescriptionFeature.State.Settings.OutcomeSetting>.some(.miss))
                }
                .disabled(viewStore.state.context.diceAction == nil)
            } label: {
                Text(viewStore.state.hitOrMissString ?? "-")
            }
            .tint(viewStore.state.hitOrMissTint)
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    @ViewBuilder
    func impactButton(
        _ viewStore: ViewStoreOf<ActionDescriptionFeature>
    ) -> some View {
        Menu {
            Picker("Outcome", selection: viewStore.$settings.impact) {
                Text("Minimal").tag(CreatureActionDescriptionRequest.Impact.minimal)
                Text("Average").tag(CreatureActionDescriptionRequest.Impact.average)
                Text("Devastating").tag(CreatureActionDescriptionRequest.Impact.devastating)
            }
        } label: {
            Text(viewStore.state.impactString)
        }
        .tint(viewStore.state.impactTint)
        .disabled(!(viewStore.state.effectiveOutcome?.isHit == true))
        .fixedSize(horizontal: true, vertical: false)
    }
}

let hitOrMissTintHit: Color? = Color(UIColor.systemRed)
let hitOrMissTintMiss: Color? = nil

extension ActionDescriptionFeature.State {
    var hitOrMissTint: Color? {
        if effectiveOutcome?.isHit == true {
            return hitOrMissTintHit
        } else {
            return hitOrMissTintMiss
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

func BoxedTextBackground() -> some View {
    Canvas(renderer: { ctx, size in
        let fillColor = Color(UIColor { tc in
            if tc.userInterfaceStyle == .dark {
                return UIColor(red: 0.39, green: 0, blue: 0, alpha: 1.0)
            } else {
                return UIColor(red: 0.39, green: 0, blue: 0, alpha: 1.0)
            }
        })
        let bgColor = Color(UIColor { tc in
            if tc.userInterfaceStyle == .dark {
                return UIColor(red: 0.085, green: 0.084, blue: 0.078, alpha: 1.0)
            } else {
                return UIColor(red: 0.95, green: 0.94, blue: 0.88, alpha: 1.0)
            }
        })
        let csize = CGSize(width: 10, height: 10)



        // background
        ctx.fill(
            Path(CGRect(
                x: csize.width/2,
                y: csize.height/2,
                width: size.width - csize.width,
                height: size.height - csize.height
            )),
            with: .color(bgColor)
        )

        // borders left and right
        ctx.fill(
            Path(CGRect(
                x: csize.width/2-0.5,
                y: csize.height/2,
                width: 1,
                height: size.height-csize.height
            )),
            with: .color(fillColor.opacity(0.66))
        )

        ctx.fill(
            Path(CGRect(
                x: size.width-csize.width/2-0.5,
                y: csize.height/2,
                width: 1,
                height: size.height-csize.height
            )),
            with: .color(fillColor.opacity(0.66))
        )

        // circles at each of the four corners
        ctx.fill(
            Path(ellipseIn: CGRect(
                origin: .zero,
                size: csize)),
            with: .color(fillColor)
        )

        ctx.fill(
            Path(ellipseIn: CGRect(
                origin: CGPoint(x: size.width-csize.width, y: 0),
                size: csize)),
            with: .color(fillColor)
        )

        ctx.fill(
            Path(ellipseIn: CGRect(
                origin: CGPoint(x: 0, y: size.height-csize.height),
                size: csize)),
            with: .color(fillColor)
        )

        ctx.fill(
            Path(ellipseIn: CGRect(
                origin: CGPoint(x: size.width-csize.width, y: size.height-csize.height),
                size: csize)),
            with: .color(fillColor)
        )
    })
}
