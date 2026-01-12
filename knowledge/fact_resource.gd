# fact_resource.gd
# Semantic content only. Never dialogue-ready.
# If printed directly, it should sound unnatural.
class_name FactResource
extends Resource

@export var fact_id: int = 0
@export var tags: Array[String] = []
@export var raw_content: String = ""  # e.g., "blacksmith | located_in | Market District"

# Structured entity references (optional - populated by JSON loader)
@export var subject_entity: String = ""
@export var predicate: String = ""
@export var object_entity: String = ""
@export var object_literal: String = ""
@export var access: String = "public"
@export var requires_trust: float = 0.0
@export var owner_entity: String = ""

## EXTENSION POINT: Uncomment when ready to add knowledge gating
# @export var granularity: int = 0  # 0=summary, 1=general, 2=detailed, 3=expert
# @export var prerequisites: Array[int] = []  # fact_ids that must be known first
# @export var skill_requirements: Dictionary = {}  # skill_name -> min_level (float)
