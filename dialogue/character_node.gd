# character_node.gd
# Main NPC node. Owns state, delegates dialogue to manager.
# Attach this to a Node in your scene for each NPC.
class_name CharacterNodeClass
extends Node

## Character profile resource (static definition)
@export var profile: CharacterProfile

## Initial memory resource (will be duplicated, not shared)
@export var initial_memory: NPCMemoryResource

## Runtime state (created on initialize)
var state: NPCState

## Dialogue processor (created on initialize)
var dialogue_manager: DialogueManager

## Signal emitted when NPC responds
signal responded(character_name: String, response: String)


func _ready() -> void:
	# Auto-initialize if WorldKnowledge autoload is available
	if WorldKnowledge and WorldKnowledge.knowledge:
		initialize(WorldKnowledge.knowledge)


## Must be called after adding to tree or when world knowledge is ready
func initialize(world: WorldKnowledgeResource, skeletons: Dictionary = {}) -> void:
	state = NPCState.new()
	
	if profile and not profile.character_name.is_empty():
		var npc_id := profile.character_name.to_lower().replace(" ", "_").replace("-", "_")
		state.memory = _seed_memory(npc_id)
	elif initial_memory:
		state.memory = initial_memory.duplicate(true)
	else:
		state.memory = NPCMemoryResource.new()
	
	# Copy learning traits from profile
	if profile:
		state.curiosity = profile.curiosity
	
	# Create dialogue manager
	dialogue_manager = DialogueManager.new(world, skeletons)


## Main API: get response to player input
func respond(input: String) -> String:
	if not dialogue_manager:
		push_error("CharacterNode not initialized. Call initialize() first.")
		return ""
	
	if not profile:
		push_error("CharacterNode has no profile assigned.")
		return ""
	
	var response: String = dialogue_manager.process(input, profile, state)
	responded.emit(get_character_name(), response)
	return response


## Get character name for UI
func get_character_name() -> String:
	if profile:
		return profile.character_name
	return "Unknown"


## Get current turn count
func get_turn_count() -> int:
	if state:
		return state.turn_count
	return 0


## Get recent conversation subjects
func get_recent_subjects() -> Array[String]:
	if state:
		return state.recent_subjects
	return []


## Check if NPC knows about a topic
func knows_about(topic: String) -> bool:
	if not dialogue_manager or not state:
		return false
	return dialogue_manager.knowledge_adapter.has_knowledge_of_topic(topic, state.memory)


## Add a belief to this NPC's memory
func add_belief(fact_id: int, confidence: float = 0.8) -> void:
	if state and state.memory:
		state.memory.beliefs[fact_id] = confidence


## Add misinformation (NPC believes something false)
func add_misinformation(fact_id: int, false_content: String, confidence: float = 0.8) -> void:
	if state and state.memory:
		state.memory.beliefs[fact_id] = confidence
		state.memory.misinformation[fact_id] = false_content


## Get debug info about how NPC would process an input
func debug_process(input: String) -> Dictionary:
	if not dialogue_manager or not profile or not state:
		return {}
	return dialogue_manager.get_debug_info(input, profile, state)


func _seed_memory(npc_id: String) -> NPCMemoryResource:
	var scope_data := _load_scope_data()
	if scope_data.is_empty():
		if initial_memory:
			return initial_memory.duplicate(true)
		return NPCMemoryResource.new()
	
	var seeds: Dictionary = scope_data.get("npc_seeds", {})
	if not seeds.has(npc_id):
		if initial_memory:
			return initial_memory.duplicate(true)
		return NPCMemoryResource.new()
	
	var seeder := KnowledgeSeeder.new(
		WorldKnowledge.knowledge,
		WorldKnowledge.get_entities(),
		scope_data
	)
	
	return seeder.seed_npc(npc_id)


func _load_scope_data() -> Dictionary:
	var path := "res://data/knowledge_scopes.json"
	if not FileAccess.file_exists(path):
		return {}
	
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	
	var json_text := file.get_as_text()
	file.close()
	
	var parsed = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("CharacterNode: JSON parse error in knowledge_scopes.json")
		return {}
	
	return parsed


# =============================================================================
# LEARNING API
# =============================================================================

## Tell this NPC a fact (social learning).
## Returns true if fact was newly learned.
func tell_fact(
	fact_id: int,
	speaker_id: String,
	speaker_confidence: float = 0.8,
	generation: int = 0
) -> bool:
	if not state:
		return false
	
	var strength: float = LearningSystem.calculate_social_learning_strength(
		state.get_trust(speaker_id),
		speaker_confidence,
		generation
	)
	
	if strength < 0.1:
		return false
	
	return state.learn_fact(
		fact_id,
		strength,
		NPCState.SourceType.TOLD,
		speaker_id,
		generation + 1
	)


## NPC witnesses an event/fact directly.
func witness_fact(fact_id: int, clarity: float = 1.0) -> bool:
	if not state:
		return false
	
	return state.learn_fact(
		fact_id,
		clarity,
		NPCState.SourceType.WITNESSED,
		"",
		0
	)


## Set NPC's current location.
func set_location(location_id: String) -> void:
	if state:
		state.set_location(location_id)


## Process passive learning (call periodically).
func process_environmental_learning(delta_days: float) -> void:
	if not state or state.current_location.is_empty():
		return
	
	state.add_time_at_location(delta_days)

## EXTENSION POINT: Relationship access
# func get_relationship(target_id: String) -> Dictionary:
#     if not state or not state.relationships.has(target_id):
#         return {"trust": 0.0, "affection": 0.0, "respect": 0.0}
#     return state.relationships[target_id]


## EXTENSION POINT: Drive evaluation
# func evaluate_request(request: Dictionary) -> Dictionary:
#     # Would evaluate drives against request action_tags
#     return {"willing": true, "enthusiasm": 0.5}
