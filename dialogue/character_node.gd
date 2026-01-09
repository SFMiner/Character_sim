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


## EXTENSION POINT: Relationship access
# func get_relationship(target_id: String) -> Dictionary:
#     if not state or not state.relationships.has(target_id):
#         return {"trust": 0.0, "affection": 0.0, "respect": 0.0}
#     return state.relationships[target_id]


## EXTENSION POINT: Drive evaluation
# func evaluate_request(request: Dictionary) -> Dictionary:
#     # Would evaluate drives against request action_tags
#     return {"willing": true, "enthusiasm": 0.5}
