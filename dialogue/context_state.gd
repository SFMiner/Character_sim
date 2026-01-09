# context_state.gd
# Handles coreference resolution for follow-up continuity.
# "it", "they", "there" -> most recent compatible subject
# Deterministic behavior only.
class_name ContextState
extends RefCounted


## Resolves pronouns in input using NPC's recent subjects.
## Returns augmented input with subject restored if needed.
func resolve(input: String, state: NPCState) -> Dictionary:
	var lower: String = input.to_lower()
	var result: Dictionary = {
		"resolved_input": input,
		"used_reference": false,
		"referenced_subject": "",
	}
	
	if state.recent_subjects.is_empty():
		return result
	
	# Check for pronouns that need resolution
	var needs_resolution: bool = _has_unresolved_pronoun(lower, input)
	if not needs_resolution:
		return result
	
	# Find compatible subject from history
	var subject: String = _find_compatible_subject(lower, state.recent_subjects)
	if subject.is_empty():
		return result
	
	result.used_reference = true
	result.referenced_subject = subject
	result.resolved_input = _augment_input(input, subject)
	
	return result


func _has_unresolved_pronoun(lower: String, original: String) -> bool:
	var pronouns: Array[String] = ["it", "they", "them", "there", "that", "this", "he", "she"]
	var words: PackedStringArray = lower.split(" ", false)
	
	for word in words:
		var clean: String = word.trim_suffix("?").trim_suffix("!").trim_suffix(",")
		if clean in pronouns:
			# Check if the sentence lacks a clear noun
			if not _has_clear_noun(original):
				return true
	return false


func _has_clear_noun(text: String) -> bool:
	# Check for "the X" pattern - indicates a specific noun
	if "the " in text.to_lower():
		# Make sure there's a word after "the"
		var idx: int = text.to_lower().find("the ")
		var after: String = text.substr(idx + 4).strip_edges()
		var first_word: String = after.split(" ", false)[0] if not after.is_empty() else ""
		# Filter out pronouns after "the"
		if first_word and first_word not in ["it", "they", "them", "one"]:
			return true
	
	# Check for capitalized words (proper nouns) not at sentence start
	var words: PackedStringArray = text.split(" ", false)
	for i in range(1, words.size()):  # Skip first word
		var word: String = words[i]
		if word.length() > 0:
			var first_char: String = word[0]
			if first_char == first_char.to_upper() and first_char != first_char.to_lower():
				return true
	
	return false


func _find_compatible_subject(lower: String, recent: Array[String]) -> String:
	# For minimal implementation, return most recent subject
	# EXTENSION POINT: Add compatibility matching (location pronouns vs person pronouns)
	
	# Basic compatibility check
	var is_location_query: bool = _matches_any(lower, ["where", "there", "place"])
	var is_person_query: bool = _matches_any(lower, ["who", "they", "he", "she", "them"])
	
	# For now, just return most recent
	# A smarter version would filter by subject type
	if recent.size() > 0:
		return recent[0]
	return ""


func _augment_input(input: String, subject: String) -> String:
	# Don't do blind string replacement - append context marker
	# "What about it?" -> "What about it? [regarding: blacksmith]"
	# This preserves original input while providing context
	return input + " [regarding: " + subject + "]"


func _matches_any(text: String, patterns: Array) -> bool:
	for pattern in patterns:
		if pattern in text:
			return true
	return false


## EXTENSION POINT: Smarter pronoun-subject matching
# enum SubjectType { LOCATION, PERSON, THING, CONCEPT }
#
# func _get_pronoun_type(pronoun: String) -> SubjectType:
#     match pronoun:
#         "there":
#             return SubjectType.LOCATION
#         "he", "she", "they", "them":
#             return SubjectType.PERSON
#         _:
#             return SubjectType.THING
#
# func _get_subject_type(subject: String, world: WorldKnowledgeResource) -> SubjectType:
#     # Look up subject in world knowledge to determine type
#     var facts: Array = world.get_facts_by_tag(subject)
#     for fact in facts:
#         if "location" in fact.tags:
#             return SubjectType.LOCATION
#         if "person" in fact.tags:
#             return SubjectType.PERSON
#     return SubjectType.THING
