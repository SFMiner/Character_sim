# fact_resource.gd
# Semantic content only. Never dialogue-ready.
# If printed directly, it should sound unnatural.
class_name FactResource
extends Resource

@export var fact_id: int = 0
@export var tags: Array[String] = []
@export var raw_content: String = ""  # e.g., "blacksmith | located_in | Market District"

## EXTENSION POINT: Uncomment when ready to add knowledge gating
# @export var granularity: int = 0  # 0=summary, 1=general, 2=detailed, 3=expert
# @export var prerequisites: Array[int] = []  # fact_ids that must be known first
# @export var skill_requirements: Dictionary = {}  # skill_name -> min_level (float)
