//
//  GenerateCreatureStatBlock.swift
//
//
//  Created by Mechanical Muse.
//

import Foundation
import OpenAI

public struct GenerateStatBlockRequest: Hashable {
    public var instructions: String
    public var base: SimpleStatBlock?

    public init(instructions: String, base: SimpleStatBlock? = nil) {
        self.instructions = instructions
        self.base = base
    }
}

extension GenerateStatBlockRequest: PromptConvertible {
    public func prompt() -> [ChatQuery.ChatCompletionMessageParam] {
        var user = """
        Create or edit a Dungeons & Dragons creature stat block following these instructions:
        
        <instructions>
        \(instructions)
        </instructions>
        
        """

        if let base {
            // Provide current creature JSON to guide edits.
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            if let data = try? encoder.encode(base), let json = String(data: data, encoding: .utf8) {
                user += """
                Current creature stat block:
                
                <stat-block>
                \(json)
                </stat-block>

                Respond with the updated stat block. If a field should not change, use the same value in your response.
                """
            }
        } else {
            user += "\nGenerate a cohesive stat block that fits the instructions.\n"
        }

        return [
            .system(.init(content: .textContent("You help a Dungeons & Dragons DM create or edit creatures. Be concise and consistent with 5e."))),
            .user(.init(content: .string(user)))
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


