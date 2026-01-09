# decision_gate.gd
# Decides WHAT to do (share/refuse/deflect), not HOW to say it.
# This is the insertion point for drives, relationships, values.
# Currently minimal - just routes by speech act and forbidden topics.
class_name DecisionGate
extends RefCounted

enum Decision {
	SHARE,            # Provide information or help
	REFUSE_FORBIDDEN, # Topic is off-limits
	REFUSE_UNKNOWN,   # Don't know the answer
	DEFLECT,          # Avoid without refusing
	CHALLENGE_BACK,   # Respond to aggression
	ACKNOWLEDGE,      # Casual response
}


## Returns decision about how to respond.
## EXTENSION POINT: Add state, relationships to signature
func decide(
	speech_act: SpeechActInterpreter.SpeechAct,
	subject: String,
	profile: CharacterProfile,
	has_knowledge: bool,
	## EXTENSION POINT: Uncomment when needed
	# state: NPCState = null,
	# requester_id: String = "player",
) -> Dictionary:
	
	var result: Dictionary = {
		"decision": Decision.ACKNOWLEDGE,
		"reason": "",
		## EXTENSION POINT: Uncomment when needed
		# "drive_influences": [],
		# "relationship_factor": 1.0,
		# "value_alignment": 0.0,
	}
	
	# Check forbidden topics first - always refuse these
	if _is_forbidden(subject, profile):
		result.decision = Decision.REFUSE_FORBIDDEN
		result.reason = "forbidden_topic"
		return result
	
	# Route by speech act
	match speech_act:
		SpeechActInterpreter.SpeechAct.ASK_ABOUT:
			if has_knowledge:
				result.decision = Decision.SHARE
				result.reason = "has_knowledge"
			else:
				result.decision = Decision.REFUSE_UNKNOWN
				result.reason = "no_knowledge"
		
		SpeechActInterpreter.SpeechAct.REQUEST_HELP:
			# EXTENSION POINT: Drive evaluation would go here
			# For now, acknowledge the request
			result.decision = Decision.ACKNOWLEDGE
			result.reason = "request_noted"
		
		SpeechActInterpreter.SpeechAct.CHALLENGE:
			result.decision = Decision.CHALLENGE_BACK
			result.reason = "challenged"
		
		SpeechActInterpreter.SpeechAct.PROBE_BOUNDARY:
			# Could be probing forbidden topics
			if _is_forbidden(subject, profile):
				result.decision = Decision.REFUSE_FORBIDDEN
				result.reason = "forbidden_probe"
			else:
				result.decision = Decision.DEFLECT
				result.reason = "boundary_probe"
		
		SpeechActInterpreter.SpeechAct.CASUAL_TALK:
			result.decision = Decision.ACKNOWLEDGE
			result.reason = "casual"
	
	return result


func _is_forbidden(subject: String, profile: CharacterProfile) -> bool:
	if subject.is_empty():
		return false
	
	var lower_subject: String = subject.to_lower()
	for forbidden in profile.forbidden_topics:
		var lower_forbidden: String = forbidden.to_lower()
		# Only forbid if the forbidden phrase appears IN the subject
		# NOT if subject appears within a longer forbidden phrase
		# e.g., "king" should NOT match "king illness", but "magic" should match "magic"
		if lower_forbidden in lower_subject:
			return true
		# Also check word-boundary match for single-word forbidden topics
		if " " not in lower_forbidden:
			# Single word forbidden topic - check if it's a whole word in subject
			var words: PackedStringArray = lower_subject.split(" ", false)
			for word in words:
				if word == lower_forbidden:
					return true
	return false


## EXTENSION POINT: Drive-based decision making
# func _evaluate_drives(action_tags: Dictionary, drives: Array, state: NPCState) -> float:
#     var total: float = 0.0
#     for drive in drives:
#         match drive.type:
#             "SELF_PRESERVATION":
#                 if action_tags.get("risky", 0.0) > 0.5:
#                     total -= drive.weight
#             "SEEK_WEALTH":
#                 if action_tags.has("money_reward"):
#                     total += drive.weight * (action_tags.money_reward / 100.0)
#             # ... etc
#     return total


## EXTENSION POINT: Relationship influence
# func _relationship_modifier(requester_id: String, relationships: Dictionary) -> float:
#     if not relationships.has(requester_id):
#         return 1.0
#     var rel: Dictionary = relationships[requester_id]
#     var modifier: float = 1.0
#     modifier += rel.get("trust", 0.0) * 0.3
#     modifier += rel.get("affection", 0.0) * 0.2
#     return max(0.1, modifier)


## EXTENSION POINT: Value alignment
# func _value_alignment(action_tags: Dictionary, values: Dictionary) -> float:
#     var alignment: float = 0.0
#     if action_tags.get("honorable", false) and values.has("HONOR"):
#         alignment += values.HONOR * 0.3
#     if action_tags.get("profitable", false) and values.has("WEALTH"):
#         alignment += values.WEALTH * 0.3
#     return alignment
