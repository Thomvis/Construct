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

    @Bindable var store: StoreOf<ActionDescriptionFeature>

    var body: some View {
        VStack {
            let isLoading = store.isLoadingDescription

            ScrollView(showsIndicators: false) {
                ZStack {
                    if isLoading || store.descriptionString != nil {
                        VStack(alignment: .trailing, spacing: 10) {
                            let description = store.descriptionString
                            Text(description ?? "Generating attack description…")
                                .foregroundColor(description == nil ? Color.secondary : Color.primary)
                                .animation(nil, value: store.descriptionString)
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
                    } else if let error = store.descriptionErrorString {
                        NoticeView(notice: .error(error))
                            .frame(minHeight: descriptionHeight)
                    } else if store.isMissingOutcomeSetting {
                        VStack {
                            Text("Did the attack hit or miss?")

                            EqualWidthLayout(spacing: 20) {
                                Button {
                                    $store.settings.outcome.wrappedValue = .hit
                                } label: {
                                    Text("Hit").frame(maxWidth: .infinity)
                                }
                                .tint(hitOrMissTintHit)

                                Button {
                                    $store.settings.outcome.wrappedValue = .miss
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
                    store.send(.onFeedbackButtonTap)
                }

                Spacer()

                HStack {
                    Group {
                        hitButton()

                        impactButton()
                    }
                    .disabled(isLoading || store.isMissingOutcomeSetting)

                    Button {
                        store.send(.onReloadOrCancelButtonTap)
                    } label: {
                        if isLoading {
                            Image(systemName: "xmark")
                                .frame(height: bottomButtonHeight)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .frame(height: bottomButtonHeight)
                        }
                    }
                    .disabled(store.isMissingOutcomeSetting)
                }
                .font(.footnote)
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
        .onDisappear {
            store.send(.onDisappear)
        }
    }

    @ViewBuilder
    func hitButton() -> some View {
        if store.settings.outcome != nil {
            Menu {
                Picker("Outcome", selection: $store.settings.outcome) {
                    Text("Hit").tag(Optional<ActionDescriptionFeature.State.Settings.OutcomeSetting>.some(.hit))
                    Text("Miss").tag(Optional<ActionDescriptionFeature.State.Settings.OutcomeSetting>.some(.miss))
                }
                .disabled(store.context.diceAction == nil)
            } label: {
                Text(store.hitOrMissString ?? "-")
            }
            .tint(store.hitOrMissTint)
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    @ViewBuilder
    func impactButton() -> some View {
        Menu {
            Picker("Outcome", selection: $store.settings.impact) {
                Text("Minimal").tag(CreatureActionDescriptionRequest.Impact.minimal)
                Text("Average").tag(CreatureActionDescriptionRequest.Impact.average)
                Text("Devastating").tag(CreatureActionDescriptionRequest.Impact.devastating)
            }
        } label: {
            Text(store.impactString)
        }
        .tint(store.impactTint)
        .disabled(!(store.effectiveOutcome?.isHit == true))
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
