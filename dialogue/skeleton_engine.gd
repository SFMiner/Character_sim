# skeleton_engine.gd
# Selects response structure based on decision, profile, and speech act.
# Skeletons define rhythm and structure, not content.
# Returns skeleton candidates (not just one) for future scoring.
class_name SkeletonEngine
extends RefCounted

var skeletons: Dictionary = {}  # skeleton_id -> skeleton_data


func _init(skeleton_data: Dictionary = {}) -> void:
	if skeleton_data.is_empty():
		_load_default_skeletons()
	else:
		skeletons = skeleton_data


## Returns Array of candidate skeletons, best first.
## EXTENSION POINT: Add personality scoring to rank candidates
func get_candidates(
	decision: DecisionGate.Decision,
	speech_act: SpeechActInterpreter.SpeechAct,
	profile: CharacterProfile,
	## EXTENSION POINT: Uncomment when needed
	# state: NPCState = null,
) -> Array[Dictionary]:
	
	var candidates: Array[Dictionary] = []
	
	# Get skeletons matching this decision
	var valid_ids: Array[String] = _get_valid_skeleton_ids(decision, profile)
	
	for id in valid_ids:
		if skeletons.has(id):
			var skeleton: Dictionary = skeletons[id].duplicate(true)
			skeleton["_id"] = id
			skeleton["_score"] = _score_skeleton(skeleton, profile, speech_act)
			candidates.append(skeleton)
	
	# Sort by score descending
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a._score > b._score)
	
	# Fallback if nothing matches
	if candidates.is_empty():
		candidates.append(_get_fallback_skeleton(decision))
	
	return candidates


## Convenience: get best skeleton (for minimal implementation)
func select(
	decision: DecisionGate.Decision,
	speech_act: SpeechActInterpreter.SpeechAct,
	profile: CharacterProfile,
) -> Dictionary:
	var candidates: Array[Dictionary] = get_candidates(decision, speech_act, profile)
	if candidates.size() > 0:
		return candidates[0]
	return _get_fallback_skeleton(decision)


func _get_valid_skeleton_ids(decision: DecisionGate.Decision, profile: CharacterProfile) -> Array[String]:
	var ids: Array[String] = []
	
	# Preferred skeletons from profile get priority
	for pref in profile.preferred_skeletons:
		if skeletons.has(pref):
			var skeleton: Dictionary = skeletons[pref]
			if _skeleton_matches_decision(skeleton, decision):
				ids.append(pref)
	
	# Then add other matching skeletons
	for id in skeletons:
		if id in ids:
			continue
		var skeleton: Dictionary = skeletons[id]
		if _skeleton_matches_decision(skeleton, decision):
			ids.append(id)
	
	return ids


func _skeleton_matches_decision(skeleton: Dictionary, decision: DecisionGate.Decision) -> bool:
	if not skeleton.has("decisions"):
		return true  # Universal skeleton
	
	var decisions: Array = skeleton.decisions
	var decision_name: String = DecisionGate.Decision.keys()[decision]
	
	# Check both enum value and string name
	return decision in decisions or decision_name in decisions


func _score_skeleton(
	skeleton: Dictionary,
	profile: CharacterProfile,
	speech_act: SpeechActInterpreter.SpeechAct
) -> float:
	var score: float = 0.5
	
	# Preferred skeletons get bonus
	if skeleton.has("_id") and skeleton._id in profile.preferred_skeletons:
		score += 0.3
	
	# LLM characters prefer structured skeletons
	if profile.character_type == "llm" and skeleton.get("structured", false):
		score += 0.2
	
	# Match verbosity
	if skeleton.get("verbosity", "medium") == profile.verbosity:
		score += 0.1
	
	# High hedge intensity prefers hedged skeletons
	if profile.hedge_intensity > 0.6 and skeleton.get("hedged", false):
		score += 0.15
	
	## EXTENSION POINT: Personality-based scoring
	# if state and state has personality traits:
	#     score += _personality_score(skeleton, state)
	
	return score


func _get_fallback_skeleton(decision: DecisionGate.Decision) -> Dictionary:
	match decision:
		DecisionGate.Decision.SHARE:
			return {"preamble": "", "body": "{content}", "postamble": "", "_id": "_fallback_share"}
		DecisionGate.Decision.REFUSE_FORBIDDEN:
			return {"preamble": "I cannot discuss that topic.", "body": "", "postamble": "", "_id": "_fallback_forbidden"}
		DecisionGate.Decision.REFUSE_UNKNOWN:
			return {"preamble": "I don't have information on that.", "body": "", "postamble": "", "_id": "_fallback_unknown"}
		DecisionGate.Decision.DEFLECT:
			return {"preamble": "Perhaps we could discuss something else.", "body": "", "postamble": "", "_id": "_fallback_deflect"}
		DecisionGate.Decision.CHALLENGE_BACK:
			return {"preamble": "I don't appreciate that tone.", "body": "", "postamble": "", "_id": "_fallback_challenge"}
		_:
			return {"preamble": "I see.", "body": "", "postamble": "", "_id": "_fallback_ack"}


func _load_default_skeletons() -> void:
	skeletons = {
		# === SHARE skeletons ===
		"neutral_explainer": {
			"decisions": ["SHARE"],
			"preamble": "I can tell you that",
			"body": "{content}.",
			"postamble": "",
			"verbosity": "medium",
		},
		"direct_answer": {
			"decisions": ["SHARE"],
			"preamble": "",
			"body": "{content}.",
			"postamble": "",
			"verbosity": "terse",
		},
		"structured_answer": {
			"decisions": ["SHARE"],
			"preamble": "Based on what I know:",
			"body": "{content}.",
			"postamble": "",
			"verbosity": "medium",
			"structured": true,
		},
		"hedged_answer": {
			"decisions": ["SHARE"],
			"preamble": "If I recall correctly,",
			"body": "{content}.",
			"postamble": "Though I may be mistaken.",
			"verbosity": "verbose",
			"hedged": true,
		},
		"llm_explainer": {
			"decisions": ["SHARE"],
			"preamble": "Based on the information available to me,",
			"body": "{content}.",
			"postamble": "I hope that helps.",
			"verbosity": "verbose",
			"structured": true,
		},
		"casual_share": {
			"decisions": ["SHARE"],
			"preamble": "Oh,",
			"body": "{content}.",
			"postamble": "",
			"verbosity": "terse",
		},
		
		# === REFUSE_UNKNOWN skeletons ===
		"polite_unknown": {
			"decisions": ["REFUSE_UNKNOWN"],
			"preamble": "I'm afraid",
			"body": "I don't know about that.",
			"postamble": "",
			"verbosity": "medium",
		},
		"curt_unknown": {
			"decisions": ["REFUSE_UNKNOWN"],
			"preamble": "",
			"body": "I don't know.",
			"postamble": "",
			"verbosity": "terse",
		},
		"helpful_unknown": {
			"decisions": ["REFUSE_UNKNOWN"],
			"preamble": "I'm sorry, but",
			"body": "I don't have information on that.",
			"postamble": "Perhaps someone else could help?",
			"verbosity": "verbose",
		},
		"llm_unknown": {
			"decisions": ["REFUSE_UNKNOWN"],
			"preamble": "I don't have specific information about that",
			"body": "in my current knowledge.",
			"postamble": "Is there something else I can help with?",
			"verbosity": "verbose",
			"structured": true,
		},
		
		# === REFUSE_FORBIDDEN skeletons ===
		"polite_refusal": {
			"decisions": ["REFUSE_FORBIDDEN"],
			"preamble": "I'm not comfortable",
			"body": "discussing that topic.",
			"postamble": "",
			"verbosity": "medium",
		},
		"firm_refusal": {
			"decisions": ["REFUSE_FORBIDDEN"],
			"preamble": "",
			"body": "I won't discuss that.",
			"postamble": "",
			"verbosity": "terse",
		},
		"llm_refusal": {
			"decisions": ["REFUSE_FORBIDDEN"],
			"preamble": "I'm not able to provide information on that topic",
			"body": "due to the nature of my training.",
			"postamble": "Is there something else I can help with?",
			"verbosity": "verbose",
			"structured": true,
		},
		
		# === DEFLECT skeletons ===
		"gentle_deflect": {
			"decisions": ["DEFLECT"],
			"preamble": "That's an interesting question.",
			"body": "Perhaps we could discuss something else?",
			"postamble": "",
			"verbosity": "medium",
		},
		"redirect_deflect": {
			"decisions": ["DEFLECT"],
			"preamble": "I'd rather not get into that.",
			"body": "What else is on your mind?",
			"postamble": "",
			"verbosity": "medium",
		},
		
		# === CHALLENGE_BACK skeletons ===
		"firm_pushback": {
			"decisions": ["CHALLENGE_BACK"],
			"preamble": "",
			"body": "I don't respond well to that approach.",
			"postamble": "",
			"verbosity": "terse",
		},
		"measured_pushback": {
			"decisions": ["CHALLENGE_BACK"],
			"preamble": "I understand you may be frustrated, but",
			"body": "I'd appreciate a more respectful tone.",
			"postamble": "",
			"verbosity": "medium",
		},
		"llm_pushback": {
			"decisions": ["CHALLENGE_BACK"],
			"preamble": "I notice some tension in your message.",
			"body": "I'm here to help, but I work best with constructive dialogue.",
			"postamble": "Would you like to rephrase your question?",
			"verbosity": "verbose",
			"structured": true,
		},
		
		# === ACKNOWLEDGE skeletons ===
		"simple_ack": {
			"decisions": ["ACKNOWLEDGE"],
			"preamble": "",
			"body": "I understand.",
			"postamble": "",
			"verbosity": "terse",
		},
		"friendly_ack": {
			"decisions": ["ACKNOWLEDGE"],
			"preamble": "Of course.",
			"body": "What would you like to know?",
			"postamble": "",
			"verbosity": "medium",
		},
		"greeting_ack": {
			"decisions": ["ACKNOWLEDGE"],
			"preamble": "Hello!",
			"body": "How can I help you today?",
			"postamble": "",
			"verbosity": "medium",
		},
		"llm_ack": {
			"decisions": ["ACKNOWLEDGE"],
			"preamble": "Hello!",
			"body": "I'm here to assist you.",
			"postamble": "Feel free to ask me anything.",
			"verbosity": "verbose",
			"structured": true,
		},
	}


## Load skeletons from JSON file
func load_from_json(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_error("Skeleton file not found: " + path)
		return false
	
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Could not open skeleton file: " + path)
		return false
	
	var json_text: String = file.get_as_text()
	file.close()
	
	var json: JSON = JSON.new()
	var error: Error = json.parse(json_text)
	if error != OK:
		push_error("JSON parse error in skeleton file: " + json.get_error_message())
		return false
	
	skeletons = json.data
	return true


## EXTENSION POINT: Personality-based skeleton scoring
# func _personality_score(skeleton: Dictionary, state: NPCState) -> float:
#     var score: float = 0.0
#     var personality = state.personality  # Assuming extension adds this
#     
#     # Warm characters prefer friendly skeletons
#     if personality.warmth > 0.5 and skeleton.get("friendly", false):
#         score += 0.2
#     
#     # Assertive characters prefer direct skeletons
#     if personality.assertiveness > 0.5 and skeleton.get("verbosity") == "terse":
#         score += 0.15
#     
#     return score
