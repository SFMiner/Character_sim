# knowledge_seeder.gd
# Seeds NPC memory from scope and graph configs.
class_name KnowledgeSeeder
extends RefCounted

var world: WorldKnowledgeResource
var entities: Dictionary
var entity_facts_index: Dictionary = {}
var fact_entities_index: Dictionary = {}
var scopes: Dictionary
var npc_seeds: Dictionary


func _init(
	world_knowledge: WorldKnowledgeResource,
	entity_data: Dictionary,
	scope_data: Dictionary
) -> void:
	world = world_knowledge
	entities = entity_data
	scopes = scope_data.get("scopes", {})
	npc_seeds = scope_data.get("npc_seeds", {})
	_build_indices()


func _build_indices() -> void:
	entity_facts_index.clear()
	fact_entities_index.clear()
	
	for fact_id in world.facts:
		var fact: FactResource = world.facts[fact_id]
		var fact_entities: Array[String] = []
		
		if not fact.subject_entity.is_empty():
			fact_entities.append(fact.subject_entity)
			_index_entity_fact(fact.subject_entity, fact_id)
		
		if not fact.object_entity.is_empty():
			fact_entities.append(fact.object_entity)
			_index_entity_fact(fact.object_entity, fact_id)
		
		fact_entities_index[fact_id] = fact_entities


func _index_entity_fact(entity_id: String, fact_id: int) -> void:
	if not entity_facts_index.has(entity_id):
		entity_facts_index[entity_id] = []
	if fact_id not in entity_facts_index[entity_id]:
		entity_facts_index[entity_id].append(fact_id)


# ============================================================
# MAIN API
# ============================================================

func seed_npc(npc_id: String) -> NPCMemoryResource:
	var memory := NPCMemoryResource.new()
	
	if not npc_seeds.has(npc_id):
		push_warning("KnowledgeSeeder: No seed config for '%s'" % npc_id)
		return memory
	
	var seed_config: Dictionary = npc_seeds[npc_id]
	
	var scope_names: Array = seed_config.get("scopes", [])
	for scope_name in scope_names:
		_apply_scope(memory, scope_name, seed_config)
	
	var graph_seeds: Array = seed_config.get("graph_seeds", [])
	for graph_seed in graph_seeds:
		_apply_graph_seed(memory, graph_seed, seed_config)
	
	var misinfo: Dictionary = seed_config.get("misinformation", {})
	for fact_id_str in misinfo:
		var fact_id := int(fact_id_str)
		var misinfo_entry: Dictionary = misinfo[fact_id_str]
		_apply_misinformation(memory, fact_id, misinfo_entry)
	
	var exclude_tags: Array = seed_config.get("exclude_tags", [])
	_remove_by_tags(memory, exclude_tags)
	
	return memory


# ============================================================
# SCOPE APPLICATION
# ============================================================

func _apply_scope(memory: NPCMemoryResource, scope_name: String, npc_config: Dictionary) -> void:
	if not scopes.has(scope_name):
		push_warning("KnowledgeSeeder: Unknown scope '%s'" % scope_name)
		return
	
	var scope: Dictionary = scopes[scope_name]
	
	if scope.has("extends"):
		_apply_scope(memory, scope.extends, npc_config)
	
	var base_strength: float = scope.get("base_strength", 0.7)
	var include_access: Array = scope.get("include_access", [])
	var exclude_access: Array = scope.get("exclude_access", [])
	var include_tags: Array = scope.get("include_tags", [])
	
	for fact_id in world.facts:
		var fact: FactResource = world.facts[fact_id]
		
		if not include_access.is_empty():
			if fact.access not in include_access:
				continue
		
		if fact.access in exclude_access:
			continue
		
		if not include_tags.is_empty():
			var has_required_tag := false
			for tag in include_tags:
				if tag in fact.tags:
					has_required_tag = true
					break
			if not has_required_tag:
				continue
		
		if fact.requires_trust > 0.0:
			var trust_override: float = scope.get("requires_trust_override", -1.0)
			if trust_override < 0.0:
				continue
		
		if not memory.beliefs.has(fact_id):
			memory.beliefs[fact_id] = base_strength
	
	var seed_entities: Array = scope.get("seed_entities", [])
	for entity_id in seed_entities:
		_seed_entity_facts(memory, entity_id, base_strength, npc_config)


func _seed_entity_facts(
	memory: NPCMemoryResource,
	entity_id: String,
	strength: float,
	npc_config: Dictionary
) -> void:
	if not entity_facts_index.has(entity_id):
		return
	
	var exclude_tags: Array = npc_config.get("exclude_tags", [])
	
	for fact_id in entity_facts_index[entity_id]:
		var fact: FactResource = world.facts[fact_id]
		
		var excluded := false
		for tag in exclude_tags:
			if tag in fact.tags:
				excluded = true
				break
		if excluded:
			continue
		
		if fact.access == "self_only":
			var identity_entity: String = npc_config.get("identity_entity", "")
			if fact.owner_entity != identity_entity:
				continue
		
		if memory.beliefs.has(fact_id):
			memory.beliefs[fact_id] = max(memory.beliefs[fact_id], strength)
		else:
			memory.beliefs[fact_id] = strength


# ============================================================
# GRAPH TRAVERSAL
# ============================================================

func _apply_graph_seed(
	memory: NPCMemoryResource,
	graph_seed: Dictionary,
	npc_config: Dictionary
) -> void:
	var start_entity: String = graph_seed.get("entity", "")
	var max_depth: int = graph_seed.get("depth", 0)
	var base_strength: float = graph_seed.get("strength", 0.7)
	var include_predicates: Array = graph_seed.get("include_predicates", [])
	var traverse_predicates: Array = graph_seed.get("traverse_predicates", [])
	var exclude_tags: Array = graph_seed.get("exclude_tags", [])
	
	if start_entity.is_empty():
		return
	
	var visited: Dictionary = {}
	var queue: Array = [{"entity": start_entity, "depth": 0}]
	
	while not queue.is_empty():
		var current: Dictionary = queue.pop_front()
		var entity_id: String = current.entity
		var depth: int = current.depth
		
		if visited.has(entity_id):
			continue
		visited[entity_id] = depth
		
		var strength: float = base_strength * pow(0.8, depth)
		
		_add_entity_facts_filtered(
			memory,
			entity_id,
			strength,
			include_predicates if depth == 0 else [],
			exclude_tags,
			npc_config
		)
		
		if depth < max_depth:
			var connected := _get_connected_entities(entity_id, traverse_predicates)
			for connected_entity in connected:
				if not visited.has(connected_entity):
					queue.append({"entity": connected_entity, "depth": depth + 1})


func _add_entity_facts_filtered(
	memory: NPCMemoryResource,
	entity_id: String,
	strength: float,
	include_predicates: Array,
	exclude_tags: Array,
	npc_config: Dictionary
) -> void:
	if not entity_facts_index.has(entity_id):
		return
	
	for fact_id in entity_facts_index[entity_id]:
		var fact: FactResource = world.facts[fact_id]
		
		if not include_predicates.is_empty():
			if fact.predicate not in include_predicates:
				continue
		
		var excluded := false
		for tag in exclude_tags:
			if tag in fact.tags:
				excluded = true
				break
		if excluded:
			continue
		
		if fact.access == "self_only":
			var identity_entity: String = npc_config.get("identity_entity", "")
			if fact.owner_entity != identity_entity:
				continue
		
		if memory.beliefs.has(fact_id):
			memory.beliefs[fact_id] = max(memory.beliefs[fact_id], strength)
		else:
			memory.beliefs[fact_id] = strength


func _get_connected_entities(entity_id: String, predicates: Array) -> Array[String]:
	var connected: Array[String] = []
	
	if not entity_facts_index.has(entity_id):
		return connected
	
	for fact_id in entity_facts_index[entity_id]:
		var fact: FactResource = world.facts[fact_id]
		
		if not predicates.is_empty():
			if fact.predicate not in predicates:
				continue
		
		if fact.subject_entity == entity_id and not fact.object_entity.is_empty():
			if fact.object_entity not in connected:
				connected.append(fact.object_entity)
		elif fact.object_entity == entity_id and not fact.subject_entity.is_empty():
			if fact.subject_entity not in connected:
				connected.append(fact.subject_entity)
	
	return connected


# ============================================================
# MISINFORMATION & CLEANUP
# ============================================================

func _apply_misinformation(
	memory: NPCMemoryResource,
	fact_id: int,
	misinfo_entry: Dictionary
) -> void:
	var strength: float = misinfo_entry.get("strength", 0.8)
	memory.beliefs[fact_id] = strength
	
	if misinfo_entry.has("replace_object_literal"):
		var fact: FactResource = world.facts.get(fact_id)
		if fact:
			var subject_display := _get_entity_display(fact.subject_entity)
			var predicate_display := _predicate_to_text(fact.predicate)
			var object_display: String = misinfo_entry.replace_object_literal
			memory.misinformation[fact_id] = "%s | %s | %s" % [
				subject_display, predicate_display, object_display
			]


func _remove_by_tags(memory: NPCMemoryResource, exclude_tags: Array) -> void:
	if exclude_tags.is_empty():
		return
	
	var to_remove: Array[int] = []
	for fact_id in memory.beliefs:
		var fact: FactResource = world.facts.get(fact_id)
		if not fact:
			continue
		for tag in exclude_tags:
			if tag in fact.tags:
				to_remove.append(fact_id)
				break
	
	for fact_id in to_remove:
		memory.beliefs.erase(fact_id)
		memory.misinformation.erase(fact_id)


func _get_entity_display(entity_id: String) -> String:
	if entities.has(entity_id):
		return entities[entity_id].get("display", entity_id)
	return entity_id


func _predicate_to_text(predicate: String) -> String:
	return predicate.replace("_", " ")
