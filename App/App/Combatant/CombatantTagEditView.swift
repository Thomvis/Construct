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

    @Bindable var store: StoreOf<CombatantTagEditFeature>

    var tag: CombatantTag {
        store.tag
    }

    var note: Binding<String> {
        $store.tag.note.nonNilString.sending(\.onNoteTextDidChange)
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
                            if store.effectContext?.targets.single?.definition.player != nil {
                                store.send(.popover(.numberEntry(.pad(value: 0))))
                            } else {
                                store.send(.popover(.numberEntry(.dice(.editingExpression(1.d(20))))))
                            }
                        }) {
                            Text("Set DC")
                        }
                    } else {
                        SimpleAccentedButton(action: {
                            store.send(.onNoteTextDidChange(""))
                        }) {
                            Text("Clear")
                        }
                    }
                }
            }


            Section(footer: Group {
                if store.effectContext == nil {
                    Text("Tags can only have a duration while running an encounter.")
                }
            }) {
                HStack {
                    Image(systemName: "stopwatch")

                    tag.duration.flatMap { d in
                        store.effectContext.flatMap { effectContext in
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
                            store.send(.onDurationDidChange(nil))
                        }) {
                            Text("Clear")
                        }
                    }

                    if let effectContext = store.effectContext {
                        SimpleAccentedButton(action: {
                            store.send(.popover(.effectDuration(CombatantTagEditFeature.State.EffectDurationPopover(
                                duration: tag.duration,
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
        .navigationBarTitle(Text(store.navigationTitle), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: Button(action: {
            presentationMode.wrappedValue.dismiss()
        }) {
            Text("Cancel")
        }, trailing: Button(action: {
            store.send(.onDoneTap)
        }) {
            Text("Done").bold()
        })
        .popover(popoverBinding)
    }

    var popoverBinding: Binding<AnyView?> {
        Binding(get: {
            switch store.popover {
            case .effectDuration(let popover):
                return EffectDurationEditView(
                    effectDuration: popover.duration,
                    effectContext: popover.context,
                    onSelection: { duration in
                        store.send(.onDurationDidChange(duration))
                        store.send(.popover(nil))
                    }
                ).eraseToAnyView
            case .numberEntry:
                if let popoverStore = store.scope(state: \.numberEntryPopover, action: \.numberEntryPopover) {
                    return NumberEntryPopover(store: popoverStore) { outcome in
                        store.send(.onNoteTextDidChange("DC \(outcome)"))
                        store.send(.popover(nil))
                    }.eraseToAnyView
                }
                return nil
            case nil: return nil
            }
        }, set: {
            assert($0 == nil)
            store.send(.popover(nil))
        })
    }
}
