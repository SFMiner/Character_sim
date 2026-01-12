# npc_memory_resource.gd
# Subjective belief store. MUST be duplicated per NPC instance.
# This is what the NPC believes, which may differ from truth.
class_name NPCMemoryResource
extends Resource

## fact_id (int) -> confidence (float 0.0-1.0)
## Higher confidence = more certain about the belief
@export var beliefs: Dictionary = {}

## fact_id (int) -> distorted_content (String)
## If a fact_id is here, the NPC believes the distorted version, not truth
@export var misinformation: Dictionary = {}

## fact_id (int) -> timestamp (float)
## Used for lazy decay calculations
@export var last_accessed: Dictionary = {}

## fact_id (int) -> source_info (Dictionary)
## source_info = {type: SourceType, source_id: String, generation: int,
##                learned_at: float, reinforcements: int}
@export var sources: Dictionary = {}

## EXTENSION POINT: Uncomment when ready for hearsay chains
# @export var source_trust: Dictionary = {}  # fact_id -> source_id (String)
# @export var generation: Dictionary = {}    # fact_id -> hearsay_depth (int)
