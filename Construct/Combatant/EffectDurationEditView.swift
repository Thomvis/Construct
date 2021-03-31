//
//  EffectDurationEditView.swift
//  Construct
//
//  Created by Thomas Visser on 14/03/2020.
//  Copyright © 2020 Thomas Visser. All rights reserved.
//

import Foundation
import SwiftUI

struct EffectDurationEditView: View {
    @EnvironmentObject var env: Environment

    var effectContext: EffectContext

    @State var durationType: DurationType = .turn

    // Time
    @State var time = 1
    @State var timeUnit: TimeUnit = .minutes

    // Round
    @State var rounds = 1

    // Turn
    @State var turnPartIsStart = true
    @State var turnSkips = 0
    @State var turnSelection: Int = 0

    var onSelection: (EffectDuration) -> ()

    init(effectDuration: EffectDuration? = nil, effectContext: EffectContext, onSelection: @escaping (EffectDuration) -> ()) {
        self.effectContext = effectContext
        self.onSelection = onSelection

        if let duration = effectDuration {
            switch duration {
            case .timeInterval(let i):
                _durationType = State(initialValue: .time)
                if let hour = i.hour {
                    _time = State(initialValue: hour)
                    _timeUnit = State(initialValue: .hours)
                } else if let minute = i.minute {
                    _time = State(initialValue: minute)
                    _timeUnit = State(initialValue: .minutes)
                }
            case .until(let moment, skipping: let skipping):
                _durationType = State(initialValue: .turn)

                _turnSkips = State(initialValue: skipping)
                switch moment {
                case .turnStart(let turn):
                    _turnPartIsStart = State(initialValue: true)
                    _turnSelection = State(initialValue: turns.firstIndex(where: { $0.turn == turn}) ?? 0)
                case .turnEnd(let turn):
                    _turnPartIsStart = State(initialValue: false)
                    _turnSelection = State(initialValue: turns.firstIndex(where: { $0.turn == turn}) ?? 0)
                }
            }
        }
    }

    var body: some View {
        VStack {
            Text("Duration").bold().multilineTextAlignment(.leading)
            
            Divider()

            Picker("", selection: $durationType) {
                Text("Until turn").tag(DurationType.turn)
                Text("Round").tag(DurationType.round)
                Text("Time").tag(DurationType.time)
            }
            .pickerStyle(SegmentedPickerStyle())

            if self.durationType == .time {
                HStack {
                    Stepper("\(time) \(timeUnit.abbreviation)", value: $time, in: 1...99)
                    Picker("", selection: $timeUnit) {
                        Text("m").tag(TimeUnit.minutes)
                        Text("h").tag(TimeUnit.hours)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }

            if self.durationType == .round {
                Stepper("\(rounds) round(s)", value: $rounds, in: 1...99)
            }

            if self.durationType == .turn {
                VStack(spacing: 12) {
                    HStack {
                        Text("Timing")
                        Spacer()
                        Picker(selection: $turnPartIsStart, label: EmptyView()) {
                            Text("Start").tag(true)
                            Text("End").tag(false)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 150)
                    }

                    HStack {
                        Text("Combatant")
                        Spacer()
                        Menu(content: {
                            ForEach(turns, id: \.id) { turn in
                                if turn.id != self.turns[self.turnSelection].id, let idx = turns.firstIndex(where: { $0.id == turn.id }) {
                                    Button(action: {
                                        self.turnSelection = idx
                                    }) {
                                        Text(turn.label)
                                    }
                                }
                            }
                        }) {
                            Text(self.turns[self.turnSelection].label)
                                .padding([.leading, .trailing], 12)
                        }
                    }

                    Stepper("\(turnSkipString)", value: $turnSkips, in: 0...99)
                }
            }

            Divider()
            Button(action: {
                guard let result = self.result else { return }
                self.onSelection(result)
            }) {
                Text("Select")
            }.disabled(result == nil)
        }
    }

    var turns: [ResolvedTurn] {
        var result: [ResolvedTurn] = []
        if let c = effectContext.source {
            result.append(ResolvedTurn(turn: .source, combatants: [c]))
        }

        result.append(ResolvedTurn(turn: .target, combatants: effectContext.targets))

        for c in effectContext.combatants {
            if c.id == effectContext.source?.id { continue }
            if effectContext.targets.contains(where: { $0.id == c.id }) { continue }

            result.append(ResolvedTurn(turn: .combatant(c.id), combatants: [c]))
        }

        return result
    }

    var result: EffectDuration? {
        switch durationType {
        case .time:
            var dc = DateComponents()
            switch timeUnit {
            case .minutes:
                dc.minute = time
            case .hours:
                dc.hour = time
            }
            return .timeInterval(dc)
        case .round:
            return .until(.turnStart(.target), skipping: rounds)
        case .turn:
            let turn = turns[turnSelection]
            return .until(turnPartIsStart ? .turnStart(turn.turn) : .turnEnd(turn.turn), skipping: turnSkips)
        }
    }

    var turnSkipString: String {
        guard let string = result?.ordinalTurnDescription(environment: env, context: effectContext) else { return "" }
        return string.localizedCapitalized
    }

    enum DurationType: Int {
        case time
        case round
        case turn
    }

    enum TimeUnit: Int {
        case minutes
        case hours

        var abbreviation: String {
            switch self {
            case .minutes: return "mins"
            case .hours: return "hrs"
            }
        }
    }

    struct ResolvedTurn {
        let turn: EncounterMoment.Turn // type
        let combatants: [Combatant] // matching combatants

        var id: String {
            let cids = combatants.map { $0.id.rawValue.uuidString }.joined()

            switch turn {
            case .source:
                return "source_\(cids)"
            case .target:
                return "target_\(cids)"
            case .combatant(let uuid):
                return "\(uuid)_\(cids)"
            }
        }

        var label: String {
            switch (turn, combatants.single) {
            case (.source, let c?):
                return "\(c.discriminatedName) (source)"
            case (.source, nil):
                return "All (\(combatants.count)) sources"
            case (.target, let c?):
                return "\(c.discriminatedName) (target)"
            case (.target, nil):
                return "All (\(combatants.count)) targets"
            case (.combatant, let c):
                return c?.discriminatedName ?? ""
            }
        }
    }
}

extension EffectDurationEditView: Popover {
    var popoverId: AnyHashable { "EffectDurationEditView" }

    func makeBody() -> AnyView {
        eraseToAnyView
    }
}
