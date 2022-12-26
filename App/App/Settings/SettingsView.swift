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
import Helpers
import MechMuse
import Introspect

struct SettingsContainerView: View {

    @SwiftUI.Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    var body: some View {
        NavigationStack {
            SettingsView(presentationMode: presentationMode)
        }
        .edgesIgnoringSafeArea(.all)
    }
}

struct SettingsView: View {
    @EnvironmentObject var env: Environment
    @Binding var presentationMode: PresentationMode
    @State var destination: Destination?

    @State var initialPreferences: Preferences?
    @State var preferences = Preferences()

    @State var mechMuseVerificationResult: Async<Void, MechMuseError> = .initial

    var body: some View {
        List {
            Section {
                navigationLink(destination: .safariView("https://www.construct5e.app/help/")) {
                    Text("Help center")
                }

                if self.env.canSendMail() {
                    NavigationRowButton(action: {
                        self.env.sendMail()
                    }) {
                        VStack(alignment: .leading) {
                            Text("Send feedback").foregroundColor(Color.primary)
                        }
                    }
                }

                NavigationRowButton(action: {
                    env.rateInAppStore()
                }) {
                    Text("Please rate Construct").foregroundColor(Color.primary)
                }
            }

            Section(
                footer: Group {
                    if preferences.mechMuse.enabled {
                        Text(try! AttributedString(markdown: "Construct uses [OpenAI](https://openai.com) to generate situational prompts that inspire your DM'ing."))
                    } else {
                        Text(try! AttributedString(markdown: "Let Construct generate situational prompts that inspire your DM'ing."))
                    }
                }
            ) {
                Toggle("Mechanical Muse", isOn: $preferences.mechMuse.enabled.animation())

                if preferences.mechMuse.enabled {
                    TextField("OpenAI API key", text: $preferences.mechMuse.apiKey.nonNilString)
                        .introspectTextField { field in
                            field.clearButtonMode = .whileEditing
                        }

                    VStack {
                        LabeledContent {
                            if mechMuseVerificationResult.isLoading {
                                ProgressView()
                            } else if mechMuseVerificationResult.value != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color(UIColor.systemGreen))
                            } else if mechMuseVerificationResult.error != nil {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(Color(UIColor.systemRed))
                            }
                        } label: {
                            Text("OpenAI integration status")
                        }
                        .padding(.trailing, 5) // 5 is the magic number to align with the API key textfield

                        if let errorMessage = mechMuseVerificationResult.error?.errorDescription {
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
                Toggle("Send diagnostic reports", isOn: $preferences.errorReportingEnabled.withDefault(false))
            }

            #if DEBUG
            Section(header: Text("Debug options")) {
                NavigationRowButton(action: {
                    try? self.env.database.keyValueStore.put(Preferences())
                }) {
                    Text("Reset all preferences").foregroundColor(Color.primary)
                }

                NavigationRowButton(action: {
//                    try? self.env.database.queue.write { db in
//                        try Compendium(self.env.database).importDefaultContent(db)
//                    }
                    #warning("fix here")
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
        .sheet(item: sheetDest, content: sheetView)
        .navigationBarTitle("Settings", displayMode: .inline)
        .navigationBarItems(trailing: Button(action: {
            self.presentationMode.dismiss()
        }) {
            Text("Done").bold()
        })
        .onAppear {
            if let preferences: Preferences = try? env.database.keyValueStore.get(Preferences.key) {
                self.initialPreferences = preferences
                self.preferences = preferences
            }
        }
        .onChange(of: preferences) { p in
            if p != initialPreferences && p != Preferences() {
                try? env.database.keyValueStore.put(p)
            }
        }
        .task(id: ["\(preferences.mechMuse.enabled)", preferences.mechMuse.apiKey]) { [mm=preferences.mechMuse] in
            guard mm.enabled, let key = mm.apiKey else {
                self.mechMuseVerificationResult = .initial
                return
            }
            self.mechMuseVerificationResult = .initial
            self.mechMuseVerificationResult.isLoading = true

            do {
                // debounce
                try await Task.sleep(for: .milliseconds(100))

                // verify API key
                try await env.mechMuse.verifyAPIKey(key)
                self.mechMuseVerificationResult.result = .success(())
            } catch let error as MechMuseError {
                self.mechMuseVerificationResult.result = .failure(error)
            } catch {
                self.mechMuseVerificationResult.result = .failure(.unspecified)
            }
            self.mechMuseVerificationResult.isLoading = false
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
    func navigationLink<Label>(destination: Destination, @ViewBuilder label: () -> Label) -> some View where Label: View {
        if let view = dest(destination: destination) {
            NavigationLink(
                destination: view,
                isActive: Binding(
                    get: { self.destination == destination },
                    set: {
                        if $0 {
                            self.destination = destination
                        } else if self.destination == destination {
                            self.destination = nil
                        }
                    }
                ),
                label: label
            )
        } else {
            NavigationRowButton(action: {
                self.destination = destination
            }, label: {
                label().foregroundColor(Color.primary)
            })
        }
    }

    func dest(destination: Destination) -> AnyView? {
        switch destination {
        case .safariView: return nil
        case .ogl:
            return ScrollView {
                try? Parma(fromResource: "ogl", ofType: "md")
            }.eraseToAnyView
        case .acknowledgements:
            return ScrollView {
                try? Parma(fromResource: "software_licenses", ofType: "md")
            }.eraseToAnyView
        }
    }

    var sheetDest: Binding<Destination?> {
        Binding(get: {
            if case .safariView(let url) = self.destination {
                return .safariView(url)
            }
            return nil
        }, set: {
            self.destination = $0
        })
    }

    func sheetView(destination: Destination?) -> AnyView {
        switch destination {
        case .safariView(let url):
            return SafariView(url: URL(string: url)!).edgesIgnoringSafeArea(.all).eraseToAnyView
        default:
            return EmptyView().eraseToAnyView
        }
    }

    enum Destination: Hashable, Identifiable {
        var id: Int { hashValue }

        case safariView(String)
        case ogl
        case acknowledgements
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
