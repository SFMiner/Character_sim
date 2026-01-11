# learning_system.gd
# Centralized learning calculations and utilities.
# Static functions - no instance state.
class_name LearningSystem
extends RefCounted


## Calculate effective learning strength for social transmission.
## trust: how much listener trusts speaker (0.0-1.0)
## speaker_confidence: how confident speaker is about the fact (0.0-1.0)
## generation: hearsay depth (0 = firsthand, 1+ = nth-hand)
static func calculate_social_learning_strength(
	trust: float,
	speaker_confidence: float,
	generation: int
) -> float:
	var hearsay_penalty: float = calculate_hearsay_penalty(generation)
	return trust * speaker_confidence * hearsay_penalty


## Calculate how much hearsay degrades belief strength.
## generation 0 = firsthand (no penalty)
## generation 1 = secondhand (30% penalty)
## generation 2+ = increasingly degraded
static func calculate_hearsay_penalty(generation: int) -> float:
	if generation <= 0:
		return 1.0
	# Exponential decay: 0.7^generation
	# gen 1: 0.7, gen 2: 0.49, gen 3: 0.34, gen 4: 0.24
	return pow(0.7, generation)


## Calculate environmental learning chance for a fact.
## proximity: how close the fact's entity is (0 = far, 1 = here)
## salience: how noticeable the fact is (0 = obscure, 1 = obvious)
## curiosity: NPC's learning rate (0-1)
## time_factor: accumulated time budget
static func calculate_environmental_chance(
	proximity: float,
	salience: float,
	curiosity: float,
	time_factor: float
) -> float:
	return proximity * salience * curiosity * time_factor


## Format source info for dialogue attribution.
## Returns phrases like "I saw it myself", "I heard from Bob", etc.
static func format_source_attribution(source_info: Dictionary, npc_state = null) -> String:
	if source_info.is_empty():
		return ""
	
	# Import SourceType from NPCState
	# Note: Can't use NPCState.SourceType directly in static context,
	# so we use int comparison
	var source_type: int = source_info.get("type", 0)
	var source_id: String = source_info.get("source_id", "")
	var generation: int = source_info.get("generation", 0)
	
	# SourceType enum values: INNATE=0, WITNESSED=1, TOLD=2, ENVIRONMENTAL=3, RUMOR=4
	match source_type:
		0:  # INNATE
			return ""  # No attribution for innate knowledge
		1:  # WITNESSED
			return "I saw it myself"
		2:  # TOLD
			if generation <= 1:
				if source_id.is_empty():
					return "Someone told me"
				else:
					return "I heard from " + source_id
			else:
				return "Word is..."
		3:  # ENVIRONMENTAL
			return "Everyone knows"
		4:  # RUMOR
			return "Rumor has it..."
		_:
			return ""


## Get confidence descriptor for dialogue.
## Returns phrases like "I'm certain", "I think", "I'm not sure but..."
static func format_confidence_descriptor(confidence: float) -> String:
	if confidence >= 0.9:
		return "I'm certain"
	elif confidence >= 0.7:
		return "I know"
	elif confidence >= 0.5:
		return "I believe"
	elif confidence >= 0.3:
		return "I think"
	else:
		return "I'm not sure, but"


## Combine attribution and confidence for full prefix.
## Example: "I heard from Bob that..." or "I'm certain that..."
static func format_knowledge_prefix(
	source_info: Dictionary,
	confidence: float,
	include_attribution: bool = true
) -> String:
	var parts: Array[String] = []
	
	# Confidence first
	var conf_desc: String = format_confidence_descriptor(confidence)
	if not conf_desc.is_empty():
		parts.append(conf_desc)
	
	# Attribution if requested and meaningful
	if include_attribution:
		var attr: String = format_source_attribution(source_info)
		if not attr.is_empty() and attr != "Everyone knows":
			# Restructure: "I heard from Bob" becomes part of the sentence
			if attr.begins_with("I heard") or attr.begins_with("I saw"):
				return attr + " that"
			elif attr.begins_with("Rumor") or attr.begins_with("Word"):
				return attr
	
	if parts.is_empty():
		return ""
	
	return parts[0] + " that"


## Determine if two facts conflict (same subject, different claims).
## This is a stub - full implementation needs fact structure knowledge.
static func facts_conflict(fact_a: Dictionary, fact_b: Dictionary) -> bool:
	# Would compare subject/predicate/object structure
	# For now, assume no conflicts
	return false


## Calculate memory decay based on time since last access.
## Returns multiplier to apply to belief strength.
static func calculate_decay(
	time_elapsed: float,
	decay_rate: float,
	reinforcements: int
) -> float:
	# Base exponential decay
	var base_decay: float = exp(-decay_rate * time_elapsed)
	
	# Reinforcement provides buffer (max 30% protection)
	var reinforcement_buffer: float = min(0.3, reinforcements * 0.05)
	
	return clamp(base_decay + reinforcement_buffer, 0.0, 1.0)
