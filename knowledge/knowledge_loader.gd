# knowledge_loader.gd
# Loads entity/fact JSON data and populates FactResource entries.
class_name KnowledgeLoader
extends RefCounted

var entities: Dictionary = {}
var predicates: Dictionary = {}


func load_all() -> Dictionary:
	var result: Dictionary = {
		"entities": {},
		"facts": [],
		"predicates": {}
	}
	
	entities = load_entities("res://data/entities.json")
	var facts: Array[FactResource] = load_facts("res://data/facts.json")
	
	result.entities = entities
	result.facts = facts
	result.predicates = predicates
	return result


func load_entities(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("KnowledgeLoader: Missing entities file: %s" % path)
		return {}
	
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("KnowledgeLoader: Could not open entities file: %s" % path)
		return {}
	
	var text := file.get_as_text()
	file.close()
	
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("KnowledgeLoader: Invalid JSON in entities file: %s" % path)
		return {}
	
	return parsed.get("entities", {})


func load_facts(path: String) -> Array[FactResource]:
	var results: Array[FactResource] = []
	if not FileAccess.file_exists(path):
		push_error("KnowledgeLoader: Missing facts file: %s" % path)
		return results
	
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("KnowledgeLoader: Could not open facts file: %s" % path)
		return results
	
	var text := file.get_as_text()
	file.close()
	
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("KnowledgeLoader: Invalid JSON in facts file: %s" % path)
		return results
	
	predicates = parsed.get("predicates", {})
	var facts_dict: Dictionary = parsed.get("facts", {})
	var fact_ids: Array = facts_dict.keys()
	fact_ids.sort_custom(func(a, b): return int(a) < int(b))
	
	for fact_id in fact_ids:
		var entry: Dictionary = facts_dict[fact_id]
		var fact := FactResource.new()
		
		fact.fact_id = int(fact_id)
		fact.tags = _to_string_array(entry.get("tags", []))
		fact.subject_entity = entry.get("subject", "")
		fact.predicate = entry.get("predicate", "")
		fact.object_entity = entry.get("object", "")
		fact.object_literal = entry.get("object_literal", "")
		fact.access = entry.get("access", "public")
		fact.requires_trust = float(entry.get("requires_trust", 0.0))
		fact.owner_entity = entry.get("owner", "")
		fact.raw_content = generate_raw_content(entry)
		
		results.append(fact)
	
	return results


func resolve_entity(query: String) -> String:
	var search := query.to_lower().strip_edges()
	if search.is_empty():
		return ""
	
	if entities.has(search):
		return search
	
	for entity_id in entities:
		var entity: Dictionary = entities[entity_id]
		if entity.get("display", "").to_lower() == search:
			return entity_id
	
	for entity_id in entities:
		var entity: Dictionary = entities[entity_id]
		var aliases: Array = entity.get("aliases", [])
		for alias in aliases:
			if alias.to_lower() == search:
				return entity_id
	
	for entity_id in entities:
		var entity: Dictionary = entities[entity_id]
		if search in entity.get("display", "").to_lower():
			return entity_id
	
	return ""


func generate_raw_content(entry: Dictionary) -> String:
	var subject_id: String = entry.get("subject", "")
	var predicate: String = entry.get("predicate", "")
	var object_id: String = entry.get("object", "")
	var object_literal: String = entry.get("object_literal", "")
	
	var subject_display: String = _get_entity_display(subject_id)
	var predicate_text: String = _predicate_to_text(predicate)
	var object_display: String = object_literal if not object_literal.is_empty() else _get_entity_display(object_id)
	
	return "%s | %s | %s" % [subject_display, predicate_text, object_display]


func _get_entity_display(entity_id: String) -> String:
	if entities.has(entity_id):
		return entities[entity_id].get("display", entity_id)
	return entity_id


func _predicate_to_text(predicate: String) -> String:
	return predicate.replace("_", " ")


func _to_string_array(value) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	elif value is PackedStringArray:
		for item in value:
			result.append(str(item))
	return result
