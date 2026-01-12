## Phase 2B: Entity-Based Knowledge Queries

---

### Objective

Update `KnowledgeAdapter` to resolve queries through the entity registry, enabling lookups like "king" → `king_aldric` → all facts where `king_aldric` is subject or object. This replaces the current tag-only fuzzy matching.

---

### Dependencies

- Phase 2A complete (entities.json, facts.json, KnowledgeLoader exist and work)

---

### Modify knowledge/knowledge_adapter.gd

**Add entity awareness:**

gdscript

```gdscript
class_name KnowledgeAdapter
extends RefCounted

var world: WorldKnowledgeResource
var entities: Dictionary = {}  # NEW: entity_id -> entity data
var entity_facts_index: Dictionary = {}  # NEW: entity_id -> Array[int] of fact_ids

func _init(world_knowledge: WorldKnowledgeResource) -> void:
	world = world_knowledge
	_build_indices()

func set_entities(entity_data: Dictionary) -> void:
	entities = entity_data
	_build_indices()

func _build_indices() -> void:
	# Build reverse index: entity_id -> [fact_ids where entity appears]
	entity_facts_index.clear()
	for fact_id in world.facts:
		var fact: FactResource = world.facts[fact_id]
		# Parse raw_content or use stored subject/object if available
		var parsed := _parse_fact_entities(fact)
		for entity_id in parsed:
			if not entity_facts_index.has(entity_id):
				entity_facts_index[entity_id] = []
			entity_facts_index[entity_id].append(fact_id)
```

**Replace `_find_facts_by_subject()` with entity-first resolution:**

gdscript

```gdscript
func _find_facts_by_subject(subject: String) -> Array[FactResource]:
	var results: Array[FactResource] = []
	
	# Step 1: Try entity resolution first
	var entity_id := resolve_entity(subject)
	if not entity_id.is_empty():
		var fact_ids: Array = entity_facts_index.get(entity_id, [])
		for fid in fact_ids:
			if world.facts.has(fid):
				results.append(world.facts[fid])
		if not results.is_empty():
			return results
	
	# Step 2: Fallback to tag matching (existing logic)
	return _find_facts_by_tags(subject)

func resolve_entity(query: String) -> String:
	var search := query.to_lower().strip_edges()
	
	# Exact ID match
	if entities.has(search):
		return search
	
	# Display name match
	for entity_id in entities:
		var entity: Dictionary = entities[entity_id]
		if entity.get("display", "").to_lower() == search:
			return entity_id
	
	# Alias match
	for entity_id in entities:
		var entity: Dictionary = entities[entity_id]
		var aliases: Array = entity.get("aliases", [])
		for alias in aliases:
			if alias.to_lower() == search:
				return entity_id
	
	# Partial match on display (fallback)
	for entity_id in entities:
		var entity: Dictionary = entities[entity_id]
		if search in entity.get("display", "").to_lower():
			return entity_id
	
	return ""

func _find_facts_by_tags(subject: String) -> Array[FactResource]:
	# Existing fuzzy tag matching logic - keep as fallback
	# Move current _find_facts_by_subject() body here
	pass
```

**Add method to parse entities from a fact:**

gdscript

```gdscript
func _parse_fact_entities(fact: FactResource) -> Array[String]:
	var found: Array[String] = []
	
	# If fact has structured data (from JSON loader), use it directly
	if fact.get("subject_entity"):
		found.append(fact.subject_entity)
	if fact.get("object_entity"):
		found.append(fact.object_entity)
	
	if not found.is_empty():
		return found
	
	# Otherwise, parse from raw_content and resolve
	var content := fact.raw_content.to_lower()
	for entity_id in entities:
		var entity: Dictionary = entities[entity_id]
		var display := entity.get("display", "").to_lower()
		if display.length() >= 3 and display in content:
			found.append(entity_id)
		for alias in entity.get("aliases", []):
			if alias.to_lower() in content:
				if entity_id not in found:
					found.append(entity_id)
	
	return found
```

---

### Modify knowledge/fact_resource.gd

Add optional structured fields (backward compatible):

gdscript

```gdscript
class_name FactResource
extends Resource

@export var fact_id: int = 0
@export var tags: Array[String] = []
@export var raw_content: String = ""

# NEW: Structured entity references (optional - populated by JSON loader)
@export var subject_entity: String = ""
@export var predicate: String = ""
@export var object_entity: String = ""
@export var object_literal: String = ""
@export var access: String = "public"
@export var requires_trust: float = 0.0
@export var owner_entity: String = ""
```

---

### Modify knowledge/knowledge_loader.gd

Update `load_facts()` to populate new FactResource fields:

gdscript

```gdscript
func load_facts(path: String) -> Array[FactResource]:
	# ... existing JSON loading ...
	
	for fact_id in facts_data.facts:
		var entry: Dictionary = facts_data.facts[fact_id]
		var fact := FactResource.new()
		
		fact.fact_id = int(fact_id)
		fact.tags = Array(entry.get("tags", []))
		
		# NEW: Populate structured fields
		fact.subject_entity = entry.get("subject", "")
		fact.predicate = entry.get("predicate", "")
		fact.object_entity = entry.get("object", "")
		fact.object_literal = entry.get("object_literal", "")
		fact.access = entry.get("access", "public")
		fact.requires_trust = entry.get("requires_trust", 0.0)
		fact.owner_entity = entry.get("owner", "")
		
		# Generate raw_content for backward compatibility
		fact.raw_content = generate_raw_content(entry)
		
		results.append(fact)
	
	return results
```

---

### Modify knowledge/world_knowledge_autoload.gd

Pass entities to KnowledgeAdapter:

gdscript

```gdscript
func _initialize_knowledge() -> void:
	knowledge = WorldKnowledgeResource.new()
	
	var loader := KnowledgeLoader.new()
	var result := loader.load_all()
	
	_entities = result.entities
	_loader = loader  # Keep reference for resolve_entity
	
	for fact in result.facts:
		knowledge.facts[fact.fact_id] = fact

# Add public method for adapter initialization
func get_entities() -> Dictionary:
	return _entities
```

Update any code that creates KnowledgeAdapter to pass entities:

gdscript

```gdscript
# In dialogue_manager.gd or wherever KnowledgeAdapter is instantiated
knowledge_adapter = KnowledgeAdapter.new(world_knowledge)
knowledge_adapter.set_entities(WorldKnowledge.get_entities())
```

---

### Validation

1. Query "blacksmith" → resolves to `blacksmith` entity → returns fact 1
2. Query "king" → resolves to `king_aldric` via alias → returns facts 4, 9
3. Query "tavern" → resolves to `rusty_sword_tavern` via alias → returns fact 2
4. Query "forge" → resolves to `blacksmith` via alias → returns fact 1
5. Query "xyzzy" → no entity match → falls back to tag search → returns empty
6. Existing dialogue still works with both NPCs

---

## Phase 2C: Scopes and Graph-Traversal Seeding

---

### Objective

Implement the scope/graph seeding system that:

1. Defines knowledge scopes (templates for what archetypes know)
2. Seeds NPC memory by traversing entity relationships
3. Replaces hardcoded belief dictionaries in `.tres` files

---

### Dependencies

- Phase 2A complete (entities.json, facts.json work)
- Phase 2B complete (entity resolution and indexing work)

---

### Files to Create

|File|Purpose|
|---|---|
|`data/knowledge_scopes.json`|Scope definitions and NPC seed configs|
|`knowledge/knowledge_seeder.gd`|Traverses graph, populates NPCMemoryResource|

---

### Schema: knowledge_scopes.json

json

```json
{
  "meta": { "version": "1.0" },
  
  "scopes": {
	"common_knowledge": {
	  "description": "What everyone knows",
	  "include_access": ["public"],
	  "exclude_access": ["secret", "self_only"],
	  "base_strength": 0.7
	},
	
	"local_resident": {
	  "extends": "common_knowledge",
	  "description": "Locals know local things",
	  "include_access": ["public", "local"],
	  "base_strength": 0.8
	},
	
	"city_watch_veteran": {
	  "extends": "local_resident",
	  "description": "Guards know military + law enforcement",
	  "include_tags": ["military", "guard", "law", "crime"],
	  "seed_entities": ["city_watch", "guard_barracks"],
	  "base_strength": 0.85
	},
	
	"scholar": {
	  "extends": "common_knowledge",
	  "description": "Academics know history and lore",
	  "include_tags": ["history", "lore", "legend", "academy"],
	  "base_strength": 0.9
	},
	
	"merchant": {
	  "extends": "local_resident", 
	  "description": "Merchants know trade and economy",
	  "include_tags": ["trade", "economy", "guild", "merchant"],
	  "seed_entities": ["merchant_guild", "market_district"],
	  "base_strength": 0.8
	},
	
	"underground": {
	  "description": "Criminal knowledge - not inherited",
	  "include_tags": ["crime", "underground", "thieves"],
	  "include_access": ["secret"],
	  "requires_trust_override": 0.0,
	  "base_strength": 0.75
	}
  },
  
  "npc_seeds": {
	"old_marcus": {
	  "scopes": ["city_watch_veteran"],
	  "identity_entity": "old_marcus",
	  "graph_seeds": [
		{
		  "entity": "old_marcus",
		  "depth": 0,
		  "strength": 1.0,
		  "include_predicates": ["is_identity"]
		},
		{
		  "entity": "city_watch",
		  "depth": 1,
		  "strength": 0.85,
		  "traverse_predicates": ["leads", "member_of"]
		},
		{
		  "entity": "king_aldric",
		  "depth": 1,
		  "strength": 0.7,
		  "exclude_tags": ["secret"]
		}
	  ],
	  "misinformation": {
		"4": {
		  "replace_object_literal": "Aldric the Wise",
		  "strength": 0.8
		}
	  }
	},
	
	"archivist_7": {
	  "scopes": ["scholar"],
	  "identity_entity": "archivist_7",
	  "graph_seeds": [
		{
		  "entity": "archivist_7",
		  "depth": 0,
		  "strength": 1.0,
		  "include_predicates": ["is_identity"]
		}
	  ],
	  "exclude_tags": ["magic", "sorcery", "spells"],
	  "misinformation": {}
	}
  }
}
```

---

### knowledge/knowledge_seeder.gd

gdscript

```gdscript
class_name KnowledgeSeeder
extends RefCounted

var world: WorldKnowledgeResource
var entities: Dictionary
var entity_facts_index: Dictionary  # entity_id -> [fact_ids]
var fact_entities_index: Dictionary  # fact_id -> [entity_ids]
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
	
	# Step 1: Apply scopes (with inheritance)
	var scope_names: Array = seed_config.get("scopes", [])
	for scope_name in scope_names:
		_apply_scope(memory, scope_name, seed_config)
	
	# Step 2: Apply graph seeds
	var graph_seeds: Array = seed_config.get("graph_seeds", [])
	for graph_seed in graph_seeds:
		_apply_graph_seed(memory, graph_seed, seed_config)
	
	# Step 3: Apply misinformation
	var misinfo: Dictionary = seed_config.get("misinformation", {})
	for fact_id_str in misinfo:
		var fact_id := int(fact_id_str)
		var misinfo_entry: Dictionary = misinfo[fact_id_str]
		_apply_misinformation(memory, fact_id, misinfo_entry)
	
	# Step 4: Apply global exclusions
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
	
	# Handle inheritance first
	if scope.has("extends"):
		_apply_scope(memory, scope.extends, npc_config)
	
	var base_strength: float = scope.get("base_strength", 0.7)
	var include_access: Array = scope.get("include_access", [])
	var exclude_access: Array = scope.get("exclude_access", [])
	var include_tags: Array = scope.get("include_tags", [])
	
	for fact_id in world.facts:
		var fact: FactResource = world.facts[fact_id]
		
		# Check access level
		if not include_access.is_empty():
			if fact.access not in include_access:
				continue
		
		if fact.access in exclude_access:
			continue
		
		# Check tag requirements
		if not include_tags.is_empty():
			var has_required_tag := false
			for tag in include_tags:
				if tag in fact.tags:
					has_required_tag = true
					break
			if not has_required_tag:
				continue
		
		# Check trust requirements (secrets need high trust to even know about)
		if fact.requires_trust > 0.0:
			var trust_override: float = scope.get("requires_trust_override", -1.0)
			if trust_override < 0.0:
				continue  # Skip secrets unless scope explicitly allows
		
		# Add to memory if not already present (don't overwrite stronger beliefs)
        if not memory.beliefs.has(fact_id):
            memory.beliefs[fact_id] = base_strength
    
    # Seed entities (find all facts involving these entities)
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
        
        # Check exclusions
        var excluded := false
        for tag in exclude_tags:
            if tag in fact.tags:
                excluded = true
                break
        if excluded:
            continue
        
        # Self-only facts belong to specific NPCs
        if fact.access == "self_only":
            var identity_entity: String = npc_config.get("identity_entity", "")
            if fact.owner_entity != identity_entity:
                continue
        
        # Add or strengthen belief
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
    
    # BFS traversal
    var visited: Dictionary = {}  # entity_id -> depth
    var queue: Array = [{"entity": start_entity, "depth": 0}]
    
    while not queue.is_empty():
        var current: Dictionary = queue.pop_front()
        var entity_id: String = current.entity
        var depth: int = current.depth
        
        if visited.has(entity_id):
            continue
        visited[entity_id] = depth
        
        # Strength decays with depth
        var strength: float = base_strength * pow(0.8, depth)
        
        # Add facts for this entity
        _add_entity_facts_filtered(
            memory,
            entity_id,
            strength,
            include_predicates if depth == 0 else [],
            exclude_tags,
            npc_config
        )
        
        # Traverse to connected entities (if within depth limit)
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
        
        # Predicate filter (if specified)
        if not include_predicates.is_empty():
            if fact.predicate not in include_predicates:
                continue
        
        # Tag exclusion
        var excluded := false
        for tag in exclude_tags:
            if tag in fact.tags:
                excluded = true
                break
        if excluded:
            continue
        
        # Self-only check
        if fact.access == "self_only":
            var identity_entity: String = npc_config.get("identity_entity", "")
            if fact.owner_entity != identity_entity:
                continue
        
        # Add or strengthen
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
        
        # Check predicate filter
        if not predicates.is_empty():
            if fact.predicate not in predicates:
                continue
        
        # Add the "other" entity in this fact
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
    # Ensure belief exists
    var strength: float = misinfo_entry.get("strength", 0.8)
    memory.beliefs[fact_id] = strength
    
    # Build distorted content
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
    # Convert snake_case predicate to readable text
    match predicate:
        "located_in": return "is located in"
        "named": return "is named"
        "leads": return "leads"
        "is_identity": return "is"
        "near": return "stands near"
        "overlooks": return "overlooks"
        "slain_by": return "was slain by"
        "suffers_from": return "suffers from"
        "produces": return "produces"
        "distrusts": return "distrusts"
        "meets_in": return "meets in"
        "hidden_in": return "is hidden in"
        "spotted_near": return "have been spotted near"
        _: return predicate.replace("_", " ")
```

---

### Modify dialogue/character_node.gd

Replace static `.tres` loading with dynamic seeding:

gdscript

```gdscript
func _ready() -> void:
    if WorldKnowledge and WorldKnowledge.knowledge:
        initialize(WorldKnowledge.knowledge)

func initialize(world: WorldKnowledgeResource, skeletons: Dictionary = {}) -> void:
    state = NPCState.new()
    
    # NEW: Dynamic seeding instead of .tres loading
    if profile and not profile.character_name.is_empty():
        var npc_id := profile.character_name.to_lower().replace(" ", "_").replace("-", "_")
        state.memory = _seed_memory(npc_id)
    elif initial_memory:
        # Fallback to .tres if no seed config exists
        state.memory = initial_memory.duplicate(true)
    else:
        state.memory = NPCMemoryResource.new()
    
    dialogue_manager = DialogueManager.new(world, skeletons)
    dialogue_manager.knowledge_adapter.set_entities(WorldKnowledge.get_entities())

func _seed_memory(npc_id: String) -> NPCMemoryResource:
    var scope_data := _load_scope_data()
    if scope_data.is_empty():
        push_warning("CharacterNode: Could not load knowledge_scopes.json")
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
    
    var json := JSON.new()
    if json.parse(json_text) != OK:
        push_error("CharacterNode: JSON parse error in knowledge_scopes.json")
        return {}
    
    return json.data
```

---

### Modify scene files

Update `main.tscn` and `human_npc.tscn`:

- Remove or comment out `initial_memory` resource references
- The seeder will populate memory dynamically based on `profile.character_name`

If you want to keep `.tres` as fallback, leave `initial_memory` in place - the code checks for seed config first, then falls back.

---

### Validation

1. **Startup test**: Both scenes load without errors
2. **Old Marcus knowledge**:
    - Knows blacksmith location (public, local_resident scope)
    - Knows Helena Ironhand (city_watch_veteran scope, military tag)
    - Believes king is "Aldric the Wise" (misinformation applied)
    - Does NOT know thieves guild location (secret, not in scope)
	- Does NOT know king's illness (secret)
3. **Archivist-7 knowledge**:
	- Knows historical facts (scholar scope)
	- Does NOT know anything with `magic` tag (exclude_tags)
	- Knows own identity
4. **Graph traversal test**:
	- Add a new entity connected to `city_watch`
	- Verify Old Marcus picks it up via `depth: 1` traversal
5. **Belief strength test**:
	- Identity facts = 1.0
	- Direct scope facts = base_strength (0.7-0.9)
	- Traversed facts = decayed strength (0.8^depth)

---

### Migration Checklist

|Step|Action|
|---|---|
|1|Create `data/knowledge_scopes.json` with scope definitions|
|2|Create `knowledge/knowledge_seeder.gd`|
|3|Update `character_node.gd` to use seeder|
|4|Update `dialogue_manager.gd` to pass entities to adapter|
|5|Verify existing dialogue works|
|6|Remove `.tres` memory files (optional - can keep as fallback)|
|7|Add new NPCs by adding entries to `npc_seeds` in JSON|
