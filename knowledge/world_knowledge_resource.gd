# world_knowledge_resource.gd
# Canonical truth archive. NPCs don't access this directly.
# This is not what NPCs believe - it's the objective truth.
class_name WorldKnowledgeResource
extends Resource

@export var facts: Dictionary = {}  # fact_id (int) -> FactResource


func get_fact(fact_id: int) -> FactResource:
	return facts.get(fact_id, null)


func get_facts_by_tag(tag: String) -> Array[FactResource]:
	var results: Array[FactResource] = []
	for fact in facts.values():
		if tag in fact.tags:
			results.append(fact)
	return results


## EXTENSION POINT: Tag intersection, prerequisite chains
# func get_facts_by_tags(tags: Array[String], match_all: bool = false) -> Array[FactResource]:
#     var results: Array[FactResource] = []
#     for fact in facts.values():
#         var matched_count: int = 0
#         for tag in tags:
#             if tag in fact.tags:
#                 matched_count += 1
#         if match_all:
#             if matched_count == tags.size():
#                 results.append(fact)
#         else:
#             if matched_count > 0:
#                 results.append(fact)
#     return results
