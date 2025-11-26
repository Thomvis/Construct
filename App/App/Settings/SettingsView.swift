//
//  SettingsView.swift
//  Construct
//
//  Created by Thomas Visser on 18/01/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import Parma
import GameModels
import Compendium
import MechMuse
import Introspect
import Persistence
import ComposableArchitecture

struct SettingsContainerView: View {
    @SwiftUI.Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    let store: StoreOf<SettingsFeature>

    var body: some View {
        NavigationStack {
            SettingsView(store: store)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: {
                            self.presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Done").bold()
                        }
                    }
                }
        }
        .edgesIgnoringSafeArea(.all)
    }
}

struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsFeature>

    var body: some View {
        List {
            Section {
                navigationLink(destination: .safariView("https://www.construct5e.app/help/")) {
                    Text("Help center")
                }

                if store.canSendMail {
                    NavigationRowButton(action: {
                        store.send(.sendFeedback)
                    }) {
                        VStack(alignment: .leading) {
                            Text("Send feedback").foregroundColor(Color.primary)
                        }
                    }
                }

                NavigationRowButton(action: {
                    store.send(.rateInAppStore)
                }) {
                    Text("Please rate Construct").foregroundColor(Color.primary)
                }

                NavigationRowButton(action: {
                    store.send(.setDestination(.tipJar))
                }) {
                    let text = HStack(alignment: .firstTextBaseline) {
                        Image(systemName: "gift.fill")
                            .symbolEffect(.pulse, isActive: true)
                        Text("Tip jar")
                    }
                    .bold()

                    // First text is only there for sizing. What we see on screen is the masked gradient
                    text
                        .opacity(0)
                        .overlay {
                            LinearGradient(
                                colors: [.red, .blue, .green, .yellow],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .mask(text)
                        }

                }
            }

            Section(
                footer: Group {
                    if store.preferences.mechMuse.enabled {
                        Text(try! AttributedString(markdown: "Construct uses [OpenAI](https://openai.com) to generate situational prompts that inspire your DM'ing."))
                    } else {
                        Text(try! AttributedString(markdown: "Let Construct generate situational prompts that inspire your DM'ing."))
                    }
                }
            ) {
                Toggle(
                    "Mechanical Muse",
                    isOn: Binding(
                        get: { store.preferences.mechMuse.enabled },
                        set: { store.send(.setMechMuseEnabled($0), animation: .default) }
                    )
                )

                if store.preferences.mechMuse.enabled {
                    TextField(
                        "OpenAI API key",
                        text: Binding(
                            get: { store.preferences.mechMuse.apiKey ?? "" },
                            set: { store.send(.setMechMuseApiKey($0)) }
                        )
                    )
                    .introspectTextField { field in
                        field.clearButtonMode = .whileEditing
                    }
                    .foregroundColor(Color.secondary)

                    VStack {
                        LabeledContent {
                            if store.mechMuseVerificationState.isLoading {
                                ProgressView()
                            } else if store.mechMuseVerificationState.verifiedApiKey != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color(UIColor.systemGreen))
                            } else if store.mechMuseVerificationState.error != nil {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(Color(UIColor.systemRed))
                            } else {
                                Text("-").foregroundColor(Color.secondary)
                            }
                        } label: {
                            Text("OpenAI integration status")
                        }
                        .padding(.trailing, 5) // 5 is the magic number to align with the API key textfield

                        if let errorMessage = store.mechMuseVerificationState.error?.attributedDescription {
                            Text(errorMessage)
                                .font(.footnote)
                                .multilineTextAlignment(.leading)
                                .foregroundColor(Color(UIColor.systemRed))
                                .padding(8)
                                .frame(maxWidth: .infinity)
                                .background(Color(UIColor.systemRed).opacity(0.33).cornerRadius(4))
                        }
                    }
                }
            }

            Section(footer: Text("Help me improve Construct by sending an anonymous report when an unexpected error occurs.").font(.footnote)) {
                Toggle(
                    "Send diagnostic reports",
                    isOn: Binding(
                        get: { store.preferences.errorReportingEnabled ?? false },
                        set: { store.send(.setErrorReportingEnabled($0)) }
                    )
                )
            }

            #if DEBUG
            Section(header: Text("Debug options")) {
                NavigationRowButton(action: {
                    store.send(.resetPreferences)
                }) {
                    Text("Reset all preferences").foregroundColor(Color.primary)
                }

                NavigationRowButton(action: {
                    store.send(.importDefaultContent)
                }) {
                    Text("Import default content").foregroundColor(Color.primary)
                }
            }
            #endif

            Section {
                navigationLink(destination: .ogl) {
                    Text("Open Game License")
                }

                navigationLink(destination: .acknowledgements) {
                    Text("Third-party software")
                }

                navigationLink(destination: .safariView("https://www.construct5e.app/privacy_policy/")) {
                    Text("Privacy policy").foregroundColor(Color.primary)
                }

                navigationLink(destination: .safariView("https://www.construct5e.app/terms_conditions/")) {
                    Text("Terms & conditions")
                }

                Text("Version \(version)")
            }
        }
        .listStyle(InsetGroupedListStyle())
        .sheet(item: sheetDestination, content: sheetView)
        .navigationDestination(item: pushDestination, destination: pushView)
        .navigationBarTitle("Settings", displayMode: .inline)
        .onAppear {
            store.send(.onAppear)
        }
    }

    var version: String {
        guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String else {
                return "unknown"
        }

        return "\(version) (\(build))"
    }

    @ViewBuilder
    func navigationLink<Label>(destination: SettingsFeature.State.Destination, @ViewBuilder label: () -> Label) -> some View where Label: View {
        NavigationRowButton(action: {
            store.send(.setDestination(destination))
        }, label: {
            label().foregroundColor(Color.primary)
        })
    }

    var sheetDestination: Binding<SettingsFeature.State.Destination?> {
        Binding(get: {
            if case .safariView(let url) = store.destination {
                return .safariView(url)
            }
            return nil
        }, set: {
            store.send(.setDestination($0))
        })
    }

    var pushDestination: Binding<SettingsFeature.State.Destination?> {
        Binding(get: {
            switch store.destination {
            case .ogl, .acknowledgements, .tipJar: return store.destination
            default: return nil
            }
        }, set: {
            store.send(.setDestination($0))
        })
    }

    @ViewBuilder
    func sheetView(destination: SettingsFeature.State.Destination?) -> some View {
        if case .safariView(let url) = destination {
            SafariView(url: URL(string: url)!).edgesIgnoringSafeArea(.all)
        }
    }

    @ViewBuilder
    func pushView(destination: SettingsFeature.State.Destination) -> some View {
        switch destination {
        case .ogl:
            ScrollView {
                try? Parma(fromResource: "ogl", ofType: "md")?.padding()
            }
        case .acknowledgements:
            ScrollView {
                try? Parma(fromResource: "software_licenses", ofType: "md")?.padding()
            }
        case .tipJar:
            TipJarView()
        default: EmptyView()
        }
    }
}

extension Parma {
    init?(fromResource resource: String, ofType type: String, in bundle: Bundle = .main) throws {
        guard let path = bundle.path(forResource: resource, ofType: type) else {
            throw Error.fileNotFound
        }

        self.init(try String(contentsOfFile: path))
    }

    enum Error: Swift.Error {
        case fileNotFound
    }
}
