// Generated using Sourcery 1.6.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
public enum ParseableGameModels {
	public static var combinedParserVersion: String {
		return "CreatureActionDomainParser:\(CreatureActionDomainParser.version),CreatureFeatureDomainParser:\(CreatureFeatureDomainParser.version),SpellDescriptionDomainParser:\(SpellDescriptionDomainParser.version),"
	}

	public static var combinedModelVersion: String {
		return "ParsedCreatureAction:\(ParsedCreatureAction.version),ParsedCreatureFeature:\(ParsedCreatureFeature.version),ParsedSpellDescription:\(ParsedSpellDescription.version),"
	}

	public static var combinedVersion: String {
		"parsers:\(combinedParserVersion),models:\(combinedModelVersion)"
	}
}