# npc_state.gd
# Runtime mutable state. One per NPC instance.
# Memory must be duplicated, not shared between NPCs.
class_name NPCState
extends RefCounted

## Duplicated per instance - NEVER shared
var memory: NPCMemoryResource

## Conversation tracking
var turn_count: int = 0
var recent_subjects: Array[String] = []  # Max 5, most recent first
var recent_responses: Array[String] = []  # Max 5, for anti-repetition

## EXTENSION POINT: Uncomment when needed
# var stress_level: float = 0.0
# var current_mood: float = 0.0  # -1 to 1
# var relationships: Dictionary = {}  # target_id -> RelationshipData
# var active_drives: Array = []

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
