//
//  GenerateCreatureStatBlock.swift
//
//
//  Created by Mechanical Muse.
//

import Foundation
import OpenAI

public struct GenerateStatBlockRequest: Hashable {
    public var base: SimpleStatBlock?
    public var revisions: [(String, SimpleStatBlock)]
    public var instructions: String

    public init(base: SimpleStatBlock? = nil, revisions: [(String, SimpleStatBlock)], instructions: String) {
        self.base = base
        self.revisions = revisions
        self.instructions = instructions
    }

}

extension GenerateStatBlockRequest: PromptConvertible {
    public func prompt() -> [InputItem] {
        var initialMessage = """
        Create or edit a Dungeons & Dragons creature stat block following these instructions:
        
        """

        let encoder = JSONEncoder()
        if let base {
            // Provide current creature JSON to guide edits.
            if let data = try? encoder.encode(base), let json = String(data: data, encoding: .utf8) {
                initialMessage += """
                    Current creature stat block:
                    
                    <stat-block>
                    \(json)
                    </stat-block>
                    """
            }
        }

        func instructionsInputItem(_ instructions: String) -> InputItem {
            return .inputMessage(.init(role: .user, content: .textInput("""
                Update the latest stat block following the following instructions:

                <instructions>
                \(instructions)
                </instructions
                
                Respond with the updated stat block. If a field should not change, use the same value in your response.
                """
            )))
        }

        return [
            .inputMessage(.init(role: .system, content: .textInput("""
                You help a Dungeons & Dragons DM create or edit creatures. Be concise and consistent with 5e.
                
                Guidelines:
                - pass null instead of empty strings, arrays or objects.
                - pass null instead of 0 for movement types the creature does not have.
                """
            ))),
            .inputMessage(.init(role: .user, content: .textInput(initialMessage)))
        ] + revisions.flatMap { (instructions, statBlock) in
            return if let data = try? encoder.encode(statBlock), let json = String(data: data, encoding: .utf8) {
                [
                    instructionsInputItem(instructions),
                    .inputMessage(.init(role: .assistant, content: .textInput(json)))
                ]
            } else {
                [instructionsInputItem(instructions)]
            }
        } + [
            instructionsInputItem(instructions)
        ]
    }
}

public extension GenerateStatBlockRequest {
    static func == (lhs: GenerateStatBlockRequest, rhs: GenerateStatBlockRequest) -> Bool {
        lhs.instructions == rhs.instructions && lhs.base == rhs.base
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(instructions)
        hasher.combine(base)
    }
}


