//
//  CombatantTagEditView.swift
//  SwiftUITest
//
//  Created by Thomas Visser on 13/11/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture

struct CombatantTagEditView: View {
    @EnvironmentObject var env: Environment
    @SwiftUI.Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    var store: Store<CombatantTagEditViewState, CombatantTagEditViewAction>
    @ObservedObject var viewStore: ViewStore<CombatantTagEditViewState, CombatantTagEditViewAction>

    init(store: Store<CombatantTagEditViewState, CombatantTagEditViewAction>) {
        self.store = store
        self.viewStore = ViewStore(store)
    }

    var tag: CombatantTag {
        viewStore.state.tag
    }

    var note: Binding<String> {
        return Binding(get: {
            self.viewStore.state.tag.note ?? ""
        }, set: {
            self.viewStore.send(.onNoteTextDidChange($0))
        })
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text(tag.definition.name).bold()
                    Spacer()
                    Text(tag.definition.category.title).italic()
                }
            }

            Section {
                HStack {
                    Image(systemName: "text.bubble")
                    TextField("Note", text: note)

                    if note.wrappedValue.isEmpty {
                        SimpleAccentedButton(action: {
                            if self.viewStore.state.effectContext?.targets.single?.definition.player != nil {
                                self.viewStore.send(.popover(.numberEntry(.pad(value: 0))))
                            } else {
                                self.viewStore.send(.popover(.numberEntry(.dice(.editingExpression(1.d(20))))))
                            }
                        }) {
                            Text("Set DC")
                        }
                    } else {
                        SimpleAccentedButton(action: {
                            self.viewStore.send(.onNoteTextDidChange(""))
                        }) {
                            Text("Clear")
                        }
                    }
                }
            }


            Section(footer: Group {
                if self.viewStore.state.effectContext == nil {
                    Text("Tags can only have a duration while running an encounter.")
                }
            }) {
                HStack {
                    Image(systemName: "stopwatch")

                    tag.duration.flatMap { d in
                        self.viewStore.state.effectContext.flatMap { effectContext in
                            d.description(environment: self.env, context: effectContext)
                        }
                    }.map { ds in
                        Text(ds)
                    }.replaceNilWith {
                        Text("Duration").foregroundColor(Color(UIColor.placeholderText))
                    }

                    Spacer()

                    if tag.duration != nil {
                        SimpleAccentedButton(action: {
                            self.viewStore.send(.onDurationDidChange(nil))
                        }) {
                            Text("Clear")
                        }
                    }

                    if let effectContext = self.viewStore.state.effectContext {
                        SimpleAccentedButton(action: {
                            self.viewStore.send(.popover(.effectDuration(CombatantTagEditViewState.EffectDurationPopover(
                                duration: self.tag.duration,
                                context: effectContext
                            ))))
                        }) {
                            Text("Select")
                        }
                    } else {
                        SimpleAccentedButton(action: { }) {
                            Text("Select")
                        }.disabled(true)
                    }
                }
            }
        }
        .navigationBarTitle(Text(viewStore.state.navigationTitle), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: Button(action: {
            self.presentationMode.wrappedValue.dismiss()
        }) {
            Text("Cancel")
        }, trailing: Button(action: {
            self.viewStore.send(.onDoneTap)
        }) {
            Text("Done").bold()
        })
        .popover(popoverBinding)
    }

    var popoverBinding: Binding<AnyView?> {
        Binding(get: {
            switch viewStore.state.popover {
            case .effectDuration(let popover):
                return EffectDurationEditView(
                    effectDuration: popover.duration,
                    effectContext: popover.context,
                    onSelection: { duration in
                        self.viewStore.send(.onDurationDidChange(duration))
                        self.viewStore.send(.popover(nil))
                    }
                ).environmentObject(env).eraseToAnyView
            case .numberEntry(let popover):
                return NumberEntryPopover(environment: env, initialState: popover, onOutcomeSelected: { outcome in
                    self.viewStore.send(.onNoteTextDidChange("DC \(outcome)"))
                    self.viewStore.send(.popover(nil))
                }).eraseToAnyView
            case nil: return nil
            }
        }, set: {
            assert($0 == nil)
            self.viewStore.send(.popover(nil))
        })
    }
}
