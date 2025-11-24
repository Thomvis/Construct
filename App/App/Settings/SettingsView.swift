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
import Persistence
import ComposableArchitecture

struct SettingsContainerView: View {

    @SwiftUI.Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    var body: some View {
        NavigationStack {
            SettingsView()
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
    @Dependency(\.mailer) var mailer
    @Dependency(\.appReview) var appReview
    @Dependency(\.preferences) var preferencesClient
    @Dependency(\.compendium) var compendium
    @Dependency(\.compendiumMetadata) var compendiumMetadata
    @Dependency(\.mechMuse) var mechMuse
    
    @State var destination: Destination?

    @State var initialPreferences: Preferences?
    @State var preferences = Preferences()

    // the value is the api key
    @State var mechMuseVerificationResult: Async<String, MechMuseError>.State = .initial

    var body: some View {
        List {
            Section {
                navigationLink(destination: .safariView("https://www.construct5e.app/help/")) {
                    Text("Help center")
                }

                if mailer.canSendMail() {
                    NavigationRowButton(action: {
                        mailer.sendMail(.init())
                    }) {
                        VStack(alignment: .leading) {
                            Text("Send feedback").foregroundColor(Color.primary)
                        }
                    }
                }

                NavigationRowButton(action: {
                    appReview.rateInAppStore()
                }) {
                    Text("Please rate Construct").foregroundColor(Color.primary)
                }

                NavigationRowButton(action: {
                    destination = .tipJar
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
                        .foregroundColor(Color.secondary)

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
                            } else {
                                Text("-").foregroundColor(Color.secondary)
                            }
                        } label: {
                            Text("OpenAI integration status")
                        }
                        .padding(.trailing, 5) // 5 is the magic number to align with the API key textfield

                        if let errorMessage = mechMuseVerificationResult.error?.attributedDescription {
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
                    try? preferencesClient.update { prefs in
                        prefs = Preferences()
                    }
                }) {
                    Text("Reset all preferences").foregroundColor(Color.primary)
                }

                NavigationRowButton(action: {
                    Task {
                        let importer = CompendiumImporter(compendium: compendium, metadata: compendiumMetadata)
                        try await importer.importDefaultContent()
                    }
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
            let prefs = preferencesClient.get()
            self.initialPreferences = prefs
            self.preferences = prefs
        }
        .onChange(of: preferences) { _, p in
            if p != initialPreferences && p != Preferences() {
                try? preferencesClient.update { prefs in
                    prefs = p
                }
            }
        }
        .task(id: ["\(preferences.mechMuse.enabled)", preferences.mechMuse.apiKey]) { [mm=preferences.mechMuse] in
            guard mm.enabled, let key = mm.apiKey else {
                self.mechMuseVerificationResult = .initial
                return
            }

            guard key != mechMuseVerificationResult.value else { return }

            self.mechMuseVerificationResult = .initial
            self.mechMuseVerificationResult.isLoading = true

            do {
                // debounce
                try await Task.sleep(for: .milliseconds(100))

                // verify API key
                try await mechMuse.verifyAPIKey(key)
                self.mechMuseVerificationResult.result = .success(key)
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
        NavigationRowButton(action: {
            self.destination = destination
        }, label: {
            label().foregroundColor(Color.primary)
        })
    }

    var sheetDestination: Binding<Destination?> {
        Binding(get: {
            if case .safariView(let url) = self.destination {
                return .safariView(url)
            }
            return nil
        }, set: {
            self.destination = $0
        })
    }

    var pushDestination: Binding<Destination?> {
        Binding(get: {
            switch self.destination {
            case .ogl, .acknowledgements, .tipJar: return self.destination
            default: return nil
            }
        }, set: {
            self.destination = $0
        })
    }

    @ViewBuilder
    func sheetView(destination: Destination?) -> some View {
        if case .safariView(let url) = destination {
            SafariView(url: URL(string: url)!).edgesIgnoringSafeArea(.all)
        }
    }

    @ViewBuilder
    func pushView(destination: Destination) -> some View {
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

    enum Destination: Hashable, Identifiable {
        var id: Int { hashValue }

        case safariView(String)
        case ogl
        case acknowledgements
        case tipJar
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
