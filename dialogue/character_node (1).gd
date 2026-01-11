# character_node.gd
# Main NPC node. Owns state, delegates dialogue to manager.
# Attach this to a Node in your scene for each NPC.
class_name CharacterNode
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
	# Create state with duplicated memory (never shared)
	state = NPCState.new()
	if initial_memory:
		state.memory = initial_memory.duplicate(true)
	else:
		state.memory = NPCMemoryResource.new()
	
	# Copy learning traits from profile
	if profile:
		state.curiosity = profile.curiosity
		state.trust_default = profile.default_trust
	
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


# =============================================================================
# LEARNING API
# =============================================================================

## Tell this NPC a fact (social learning from another entity).
## speaker_id: who is telling them
## speaker_confidence: how confident the speaker seems (0.0-1.0)
## generation: hearsay depth (0 = speaker witnessed it, 1+ = speaker heard it)
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
	
	# Very low strength = NPC doesn't believe it
	if strength < 0.1:
		return false
	
	return state.learn_fact(
		fact_id,
		strength,
		NPCState.SourceType.TOLD,
		speaker_id,
		generation + 1  # Increment because NPC is now one step further from source
	)


## NPC witnesses an event/fact directly.
## clarity: how clearly they perceived it (distance, visibility, etc.)
## Returns true if fact was newly learned.
func witness_fact(fact_id: int, clarity: float = 1.0) -> bool:
	if not state:
		return false
	
	return state.learn_fact(
		fact_id,
		clarity,
		NPCState.SourceType.WITNESSED,
		"",  # No intermediary
		0    # Firsthand
	)


## NPC hears a rumor (low confidence, high generation).
func hear_rumor(fact_id: int, strength: float = 0.3) -> bool:
	if not state:
		return false
	
	return state.learn_fact(
		fact_id,
		strength,
		NPCState.SourceType.RUMOR,
		"",
		3  # Rumors are considered distant hearsay
	)


## Set NPC's current location (triggers immediate obvious fact learning).
func set_location(location_id: String) -> void:
	if not state:
		return
	
	var was_different: bool = state.current_location != location_id
	state.set_location(location_id)
	
	# If arriving at new location, could trigger immediate learning
	# of obvious/landmark facts (requires world knowledge integration)
	if was_different and not location_id.is_empty():
		_on_arrive_at_location(location_id)


## Get NPC's current location.
func get_location() -> String:
	if state:
		return state.current_location
	return ""


## Process passive environmental learning (call periodically, e.g., daily tick).
## delta_days: how much time has passed
func process_environmental_learning(delta_days: float) -> void:
	if not state or state.current_location.is_empty():
		return
	
	state.add_time_at_location(delta_days)
	
	# Environmental learning requires world knowledge traversal
	# This is a hook for Phase 3 (entity-relationship integration)
	# For now, just accumulate time
	pass


## Check if NPC knows a specific fact.
func knows_fact(fact_id: int) -> bool:
	if state:
		return state.knows_fact(fact_id)
	return false


## Get NPC's confidence in a fact (-1 if unknown).
func get_belief_strength(fact_id: int) -> float:
	if state:
		return state.get_belief_strength(fact_id)
	return -1.0


## Get how NPC learned a fact (for dialogue attribution).
func get_fact_source(fact_id: int) -> Dictionary:
	if state:
		return state.get_fact_source(fact_id)
	return {}


## Get trust level for another entity.
func get_trust(entity_id: String) -> float:
	if state:
		return state.get_trust(entity_id)
	return 0.5


## Set trust level for another entity.
func set_trust(entity_id: String, level: float) -> void:
	if state:
		state.set_trust(entity_id, level)


## Placeholder for arrival learning (will integrate with world knowledge later)
func _on_arrive_at_location(_location_id: String) -> void:
	# Phase 3 will implement:
	# - Query obvious/landmark facts for this location
	# - Learn them with WITNESSED source type
	pass
