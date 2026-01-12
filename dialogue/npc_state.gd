# npc_state.gd
# Runtime mutable state. One per NPC instance.
# Memory must be duplicated, not shared between NPCs.
class_name NPCState
extends RefCounted

## How knowledge was acquired - affects confidence and attribution
enum SourceType {
	INNATE,         # From initial seeding / always knew
	WITNESSED,      # Saw it happen firsthand
	TOLD,           # Someone told them directly
	ENVIRONMENTAL,  # Absorbed from being somewhere over time
	RUMOR,          # Overheard, unverified, low confidence
}

## Duplicated per instance - NEVER shared
var memory: NPCMemoryResource

## Conversation tracking
var turn_count: int = 0
var recent_subjects: Array[String] = []  # Max 5, most recent first
var recent_responses: Array[String] = []  # Max 5, for anti-repetition
var pending_disambiguation: Dictionary = {}
var focus_entities: Array[String] = []

## Location and time tracking
var current_location: String = ""   # Entity ID where NPC currently is
var time_at_location: float = 0.0   # Days spent at current location
var home_location: String = ""      # Where NPC returns to (for schedules)

## Learning traits (can be overridden from CharacterProfile)
var curiosity: float = 0.5          # 0.0-1.0, affects passive learning rate
var trust_default: float = 0.5      # Trust level for unknown entities
var trust_levels: Dictionary = {}   # entity_id -> float (0.0-1.0)

const MAX_RECENT_SUBJECTS: int = 5
const MAX_RECENT_RESPONSES: int = 5


func add_subject(subject: String) -> void:
	# Move to front if already present (most recent)
	if subject in recent_subjects:
		recent_subjects.erase(subject)
	recent_subjects.push_front(subject)
	# Trim to max
	while recent_subjects.size() > MAX_RECENT_SUBJECTS:
		recent_subjects.pop_back()


func get_most_recent_subject() -> String:
	if recent_subjects.is_empty():
		return ""
	return recent_subjects[0]


func add_response(response: String) -> void:
	recent_responses.push_front(response)
	while recent_responses.size() > MAX_RECENT_RESPONSES:
		recent_responses.pop_back()


func is_repetitive(response: String, threshold: float = 0.85) -> bool:
	for recent in recent_responses:
		if _similarity(response, recent) > threshold:
			return true
	return false


func _similarity(a: String, b: String) -> float:
	var words_a: PackedStringArray = a.to_lower().split(" ", false)
	var words_b: PackedStringArray = b.to_lower().split(" ", false)
	
	if words_a.is_empty() or words_b.is_empty():
		return 0.0
	
	var common: int = 0
	for word in words_a:
		if word in words_b:
			common += 1
	
	return float(common) / float(max(words_a.size(), words_b.size()))


# =============================================================================
# LEARNING SYSTEM
# =============================================================================

## Learn a new fact or reinforce existing knowledge.
## Returns true if fact was newly learned, false if reinforced or rejected.
func learn_fact(
	fact_id: int,
	strength: float,
	source_type: SourceType,
	source_id: String = "",
	generation: int = 0
) -> bool:
	if not memory:
		push_error("NPCState.learn_fact: No memory assigned")
		return false
	
	var current_time: float = Time.get_unix_time_from_system()
	var existing_strength = memory.beliefs.get(fact_id, -1.0)
	
	if existing_strength < 0.0:
		# New fact - learn it
		memory.beliefs[fact_id] = clamp(strength, 0.0, 1.0)
		memory.sources[fact_id] = {
			"type": source_type,
			"source_id": source_id,
			"generation": generation,
			"learned_at": current_time,
			"reinforcements": 0,
		}
		memory.last_accessed[fact_id] = current_time
		return true
	else:
		# Existing fact - reinforce
		reinforce_fact(fact_id, strength * 0.2)
		return false


## Strengthen existing belief through repetition/confirmation.
func reinforce_fact(fact_id: int, amount: float = 0.1) -> void:
	if not memory:
		return
	
	if not memory.beliefs.has(fact_id):
		return
	
	var current_time: float = Time.get_unix_time_from_system()
	
	# Increase strength with diminishing returns
	var current: float = memory.beliefs[fact_id]
	var new_strength: float = current + amount * (1.0 - current)
	memory.beliefs[fact_id] = clamp(new_strength, 0.0, 1.0)
	
	# Update access time and reinforcement count
	memory.last_accessed[fact_id] = current_time
	if memory.sources.has(fact_id):
		memory.sources[fact_id]["reinforcements"] += 1


## Get trust level for a specific entity/NPC.
func get_trust(entity_id: String) -> float:
	return trust_levels.get(entity_id, trust_default)


## Set trust level for a specific entity/NPC.
func set_trust(entity_id: String, level: float) -> void:
	trust_levels[entity_id] = clamp(level, 0.0, 1.0)


## Adjust trust based on interaction outcome.
func adjust_trust(entity_id: String, delta: float) -> void:
	var current: float = get_trust(entity_id)
	set_trust(entity_id, current + delta)


## Check if NPC knows a fact (regardless of confidence level).
func knows_fact(fact_id: int) -> bool:
	if not memory:
		return false
	return memory.beliefs.has(fact_id)


## Get confidence level for a known fact, or -1 if unknown.
func get_belief_strength(fact_id: int) -> float:
	if not memory:
		return -1.0
	return memory.beliefs.get(fact_id, -1.0)


## Get source information for a known fact.
func get_fact_source(fact_id: int) -> Dictionary:
	if not memory or not memory.sources.has(fact_id):
		return {}
	return memory.sources[fact_id]


## Update location and reset time counter.
func set_location(location_id: String) -> void:
	if current_location != location_id:
		current_location = location_id
		time_at_location = 0.0


## Add time at current location (call during game tick).
func add_time_at_location(delta_days: float) -> void:
	time_at_location += delta_days
