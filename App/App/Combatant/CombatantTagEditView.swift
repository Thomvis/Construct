//
//  CombatantTagEditView.swift
//  Construct
//
//  Created by Thomas Visser on 13/11/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI
import ComposableArchitecture
import SharedViews
import DiceRollerFeature
import GameModels
import Helpers

struct CombatantTagEditView: View {
    @EnvironmentObject var ordinalFormatter: OrdinalFormatter
    @SwiftUI.Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    var store: Store<CombatantTagEditFeature.State, CombatantTagEditFeature.Action>
    @ObservedObject var viewStore: ViewStore<CombatantTagEditFeature.State, CombatantTagEditFeature.Action>

    init(store: Store<CombatantTagEditFeature.State, CombatantTagEditFeature.Action>) {
        self.store = store
        self.viewStore = ViewStore(store, observe: \.self)
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
                            d.description(ordinalFormatter: ordinalFormatter, context: effectContext)
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
                            self.viewStore.send(.popover(.effectDuration(CombatantTagEditFeature.State.EffectDurationPopover(
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
                ).eraseToAnyView
            case .numberEntry:
                if store.numberEntryPopover != nil {
                    let popoverStore = store.scope(state: \.numberEntryPopover!, action: \.numberEntryPopover)
                    return NumberEntryPopover(store: popoverStore) { outcome in
                        self.viewStore.send(.onNoteTextDidChange("DC \(outcome)"))
                        self.viewStore.send(.popover(nil))
                    }.eraseToAnyView
                }
                return nil
            case nil: return nil
            }
        }, set: {
            assert($0 == nil)
            self.viewStore.send(.popover(nil))
        })
    }
}
