# entity_resolver.gd
# Resolves entities with ranked disambiguation.
class_name EntityResolver
extends RefCounted

const MATCH_EXACT_ID: int = 100
const MATCH_PRIMARY_ALIAS: int = 90
const MATCH_QUALIFIED_ALIAS: int = 80
const MATCH_DISPLAY: int = 70
const MATCH_AMBIGUOUS_ALIAS: int = 30
const MATCH_PARTIAL: int = 20


class EntityMatch extends RefCounted:
	var entity_id: String = ""
	var confidence: int = 0
	var match_type: String = ""
	var reason: String = ""


func resolve_entity_smart(
	query: String,
	entities: Dictionary,
	context: Dictionary = {}
) -> Array[EntityMatch]:
	var matches: Array[EntityMatch] = []
	var search := query.to_lower().strip_edges()
	if search.is_empty():
		return matches
	
	if entities.has(search):
		var exact := EntityMatch.new()
		exact.entity_id = search
		exact.confidence = MATCH_EXACT_ID
		exact.match_type = "exact_id"
		matches.append(exact)
		return matches
	
	for entity_id in entities:
		var entity: Dictionary = entities[entity_id]
		var primary: Array = entity.get("primary_aliases", [])
		if _array_contains_case_insensitive(primary, search):
			var match_entity := EntityMatch.new()
			match_entity.entity_id = entity_id
			match_entity.confidence = MATCH_PRIMARY_ALIAS
			match_entity.match_type = "primary_alias"
			matches.append(match_entity)
	
	if matches.size() == 1:
		return matches
	
	for entity_id in entities:
		var entity: Dictionary = entities[entity_id]
		var qualified: Array = entity.get("qualified_aliases", [])
		if _array_contains_case_insensitive(qualified, search):
			var match_entity := EntityMatch.new()
			match_entity.entity_id = entity_id
			match_entity.confidence = MATCH_QUALIFIED_ALIAS
			match_entity.match_type = "qualified_alias"
			matches.append(match_entity)
	
	if matches.size() >= 1:
		_apply_context_scoring(matches, context, entities)
		return matches
	
	for entity_id in entities:
		var entity: Dictionary = entities[entity_id]
		var display: String = entity.get("display", "").to_lower()
		if display == search or search in display:
			var match_entity := EntityMatch.new()
			match_entity.entity_id = entity_id
			match_entity.confidence = MATCH_DISPLAY if display == search else MATCH_PARTIAL
			match_entity.match_type = "display_name"
			matches.append(match_entity)
	
	for entity_id in entities:
		var entity: Dictionary = entities[entity_id]
		var ambiguous: Array = entity.get("ambiguous_aliases", [])
		if _array_contains_case_insensitive(ambiguous, search):
			var match_entity := EntityMatch.new()
			match_entity.entity_id = entity_id
			match_entity.confidence = MATCH_AMBIGUOUS_ALIAS
			match_entity.match_type = "ambiguous_alias"
			match_entity.reason = "Ambiguous match for '%s'" % search
			matches.append(match_entity)
	
	if matches.size() > 1:
		_apply_context_scoring(matches, context, entities)
	
	return matches


func _apply_context_scoring(
	matches: Array[EntityMatch],
	context: Dictionary,
	entities: Dictionary
) -> void:
	var npc_location: String = context.get("npc_location", "")
	var npc_beliefs: Dictionary = context.get("npc_beliefs", {})
	var recent_subjects: Array = context.get("recent_subjects", [])
	var focus_entities: Array = context.get("focus_entities", [])
	var entity_facts_index: Dictionary = context.get("entity_facts_index", {})
	
	for match_entity in matches:
		var entity: Dictionary = entities.get(match_entity.entity_id, {})
		
		if _npc_knows_entity(match_entity.entity_id, npc_beliefs, entity_facts_index):
			match_entity.confidence += 25
			match_entity.reason += " [NPC knows this entity]"
		
		if not npc_location.is_empty():
			var entity_location: String = entity.get("location", "")
			if entity_location == npc_location:
				match_entity.confidence += 20
				match_entity.reason += " [Same location]"
		
		if match_entity.entity_id in recent_subjects:
			match_entity.confidence += 15
			match_entity.reason += " [Recently mentioned]"
		
		if match_entity.entity_id in focus_entities:
			match_entity.confidence += 30
			match_entity.reason += " [Conversation focus]"
		
		var parent_concept: String = str(entity.get("parent_concept", ""))
		if parent_concept.is_empty():
			match_entity.confidence += 10
			match_entity.reason += " [More specific]"
		else:
			match_entity.confidence -= 5
			match_entity.reason += " [Less specific]"
	
	matches.sort_custom(func(a, b): return a.confidence > b.confidence)


func _npc_knows_entity(entity_id: String, npc_beliefs: Dictionary, entity_facts_index: Dictionary) -> bool:
	var fact_ids: Array = entity_facts_index.get(entity_id, [])
	for fact_id in fact_ids:
		if npc_beliefs.has(fact_id):
			return true
	return false


func _array_contains_case_insensitive(arr: Array, search: String) -> bool:
	for item in arr:
		if str(item).to_lower() == search:
			return true
	return false
