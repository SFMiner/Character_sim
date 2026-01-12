# Entity Disambiguation Solution

## Problem Analysis

The current knowledge system has a **critical ambiguity problem** where multiple distinct entities share the same type, role, or aliases. The `resolve_entity()` function returns the **first match** it finds, which leads to incorrect entity resolution.

### Current Problem Cases

#### 1. Multiple Blacksmiths
**Scenario**: Two blacksmiths in the same town at different locations
- `blacksmith_forge_quarter` - Gregor the blacksmith in Forge Quarter
- `blacksmith_west_market` - Elena the blacksmith in West Market

**Current Issue**: Query "Where is the blacksmith?" returns whichever entity is checked first in the dictionary iteration (non-deterministic).

#### 2. Polysemy: "Crown"
**Scenario**: Same word, completely different entity types
- `gold_crowns` (type: "object", subtype: "currency") - the currency
- `royal_crown` (type: "object", subtype: "regalia") - the king's headwear

**Current Issue**: Both have "crown" as an alias, so queries about "the crown" are ambiguous.

#### 3. Homonymy: "Guests"
**Scenario**: Generic vs. specific uses of the same concept
- `guests` (type: "concept") - general hospitality customs
- `wedding_guests` (type: "event_participants") - specific people at Sir Aldric's wedding

**Current Issue**: "Tell me about the guests" could refer to either entity.

---

## Root Causes

### 1. First-Match Resolution
```gdscript
func resolve_entity(query: String) -> String:
	for entity_id in entities:
		var entity: Dictionary = entities[entity_id]
		var aliases: Array = entity.get("aliases", [])
		for alias in aliases:
			if alias.to_lower() == search:
				return entity_id  # RETURNS FIRST MATCH - NO DISAMBIGUATION
```

### 2. No Context Awareness
The system doesn't consider:
- What facts the NPC actually knows about each entity
- Spatial context (which blacksmith is nearer)
- Conversational context (what was just discussed)
- Entity specificity (prefer specific over generic)

### 3. Flat Entity Registry
All entities are at the same level with no:
- Qualifiers (e.g., "forge quarter blacksmith" vs "west market blacksmith")
- Hierarchies (wedding_guests is a subset of guests)
- Disambiguation metadata

---

## Solution: Multi-Tier Disambiguation Strategy

### Tier 1: Entity Design (Prevention)

#### A. Use Qualified Aliases
```json
{
	"blacksmith_forge_quarter": {
		"type": "person",
		"subtype": "occupation",
		"display": "Gregor the blacksmith",
		"primary_aliases": ["gregor", "gregor the blacksmith"],
		"qualified_aliases": [
			"forge quarter blacksmith",
			"blacksmith in forge quarter",
			"the blacksmith near the foundry"
		],
		"ambiguous_aliases": ["blacksmith", "smith"],
		"location": "forge_quarter"
	},
	"blacksmith_west_market": {
		"type": "person",
		"subtype": "occupation",
		"display": "Elena the blacksmith",
		"primary_aliases": ["elena", "elena the blacksmith"],
		"qualified_aliases": [
			"west market blacksmith",
			"blacksmith in west market",
			"the blacksmith by the fountain"
		],
		"ambiguous_aliases": ["blacksmith", "smith"],
		"location": "west_market"
	}
}
```

**Strategy**: 
- `primary_aliases` → Unique identifiers (names)
- `qualified_aliases` → Location/descriptor-qualified terms
- `ambiguous_aliases` → Flagged as requiring disambiguation

#### B. Use Subtypes for Disambiguation
```json
{
	"gold_crowns": {
		"type": "object",
		"subtype": "currency",
		"display": "Gold Crowns",
		"primary_aliases": ["gold crowns", "crowns (currency)", "coins"],
		"ambiguous_aliases": ["crown", "crowns"]
	},
	"royal_crown": {
		"type": "object",
		"subtype": "regalia",
		"display": "the Royal Crown",
		"primary_aliases": ["royal crown", "king's crown", "crown regalia"],
		"ambiguous_aliases": ["crown", "the crown"]
	}
}
```

#### C. Entity Hierarchies
```json
{
	"guests": {
		"type": "concept",
		"subtype": "social_norm",
		"display": "Guests (general)",
		"aliases": ["guests", "hospitality customs"]
	},
	"wedding_guests": {
		"type": "group",
		"subtype": "event_participants",
		"display": "wedding guests",
		"parent_concept": "guests",
		"event": "sir_aldric_wedding",
		"aliases": ["wedding guests", "guests at the wedding"]
	}
}
```

### Tier 2: Enhanced Resolution Algorithm

```gdscript
class_name EntityResolver
extends RefCounted

const MATCH_EXACT_ID = 100
const MATCH_PRIMARY_ALIAS = 90
const MATCH_QUALIFIED_ALIAS = 80
const MATCH_DISPLAY = 70
const MATCH_AMBIGUOUS_ALIAS = 30
const MATCH_PARTIAL = 20

class EntityMatch:
	var entity_id: String
	var confidence: int
	var match_type: String
	var reason: String

func resolve_entity_smart(
	query: String,
	entities: Dictionary,
	context: Dictionary = {}
) -> Array[EntityMatch]:
	"""
	Returns MULTIPLE matches ranked by confidence, rather than single result.
	Caller decides how to handle ambiguity.
	"""
	var matches: Array[EntityMatch] = []
	var search := query.to_lower().strip_edges()
	
	# 1. Check for exact entity ID match
	if entities.has(search):
		var match = EntityMatch.new()
		match.entity_id = search
		match.confidence = MATCH_EXACT_ID
		match.match_type = "exact_id"
		matches.append(match)
		return matches  # Unambiguous
	
	# 2. Check primary aliases (highest priority)
	for entity_id in entities:
		var entity: Dictionary = entities[entity_id]
		var primary: Array = entity.get("primary_aliases", [])
		if _array_contains_case_insensitive(primary, search):
			var match = EntityMatch.new()
			match.entity_id = entity_id
			match.confidence = MATCH_PRIMARY_ALIAS
			match.match_type = "primary_alias"
			matches.append(match)
	
	if matches.size() == 1:
		return matches  # Unambiguous
	
	# 3. Check qualified aliases (context-specific)
	for entity_id in entities:
		var entity: Dictionary = entities[entity_id]
		var qualified: Array = entity.get("qualified_aliases", [])
		if _array_contains_case_insensitive(qualified, search):
			var match = EntityMatch.new()
			match.entity_id = entity_id
			match.confidence = MATCH_QUALIFIED_ALIAS
			match.match_type = "qualified_alias"
			matches.append(match)
	
	if matches.size() >= 1:
		# Apply context scoring
		_apply_context_scoring(matches, context, entities)
		return matches
	
	# 4. Check display names
	for entity_id in entities:
		var entity: Dictionary = entities[entity_id]
		var display: String = entity.get("display", "").to_lower()
		if display == search or search in display:
			var match = EntityMatch.new()
			match.entity_id = entity_id
			match.confidence = MATCH_DISPLAY if display == search else MATCH_PARTIAL
			match.match_type = "display_name"
			matches.append(match)
	
	# 5. Last resort: Check ambiguous aliases
	for entity_id in entities:
		var entity: Dictionary = entities[entity_id]
		var ambiguous: Array = entity.get("ambiguous_aliases", [])
		if _array_contains_case_insensitive(ambiguous, search):
			var match = EntityMatch.new()
			match.entity_id = entity_id
			match.confidence = MATCH_AMBIGUOUS_ALIAS
			match.match_type = "ambiguous_alias"
			match.reason = "AMBIGUOUS: Multiple entities match '%s'" % search
			matches.append(match)
	
	# Apply context scoring to disambiguate
	if matches.size() > 1:
		_apply_context_scoring(matches, context, entities)
	
	return matches


func _apply_context_scoring(
	matches: Array[EntityMatch],
	context: Dictionary,
	entities: Dictionary
) -> void:
	"""
	Boost confidence based on contextual clues:
	- NPC's knowledge scope (does NPC know about this entity?)
	- Spatial proximity (is entity in same location as NPC?)
	- Recent conversation (was entity just mentioned?)
	- Entity specificity (prefer specific over generic)
	"""
	
	var npc_location: String = context.get("npc_location", "")
	var npc_beliefs: Dictionary = context.get("npc_beliefs", {})
	var recent_subjects: Array = context.get("recent_subjects", [])
	
	for match in matches:
		var entity: Dictionary = entities[match.entity_id]
		
		# BOOST: NPC knows facts about this entity
		if _npc_knows_entity(match.entity_id, npc_beliefs):
			match.confidence += 25
			match.reason += " [NPC knows this entity]"
		
		# BOOST: Same location as NPC
		if not npc_location.is_empty():
			var entity_location: String = entity.get("location", "")
			if entity_location == npc_location:
				match.confidence += 20
				match.reason += " [Same location]"
		
		# BOOST: Recently discussed
		if match.entity_id in recent_subjects:
			match.confidence += 15
			match.reason += " [Recently mentioned]"
		
		# BOOST: More specific entity (has parent_concept = less specific)
		if not entity.has("parent_concept"):
			match.confidence += 10
			match.reason += " [More specific]"
		else:
			match.confidence -= 5
			match.reason += " [Less specific]"
	
	# Sort by confidence (descending)
	matches.sort_custom(func(a, b): return a.confidence > b.confidence)


func _npc_knows_entity(entity_id: String, npc_beliefs: Dictionary) -> bool:
	# Check if NPC has any beliefs involving this entity
	# This requires scanning fact subjects/objects
	for fact_id in npc_beliefs:
		# Would need to check if fact involves entity_id
		# This requires entity_facts_index from KnowledgeAdapter
		pass
	return false


func _array_contains_case_insensitive(arr: Array, search: String) -> bool:
	for item in arr:
		if str(item).to_lower() == search:
			return true
	return false
```

### Tier 3: Query Context Enhancement

Modify `KnowledgeAdapter.query_belief()` to accept context and use smart resolution:

```gdscript
func query_belief(
	subject: String,
	memory: NPCMemoryResource,
	npc_state: NPCState = null
) -> Dictionary:
	var context := {}
	if npc_state:
		context["npc_location"] = npc_state.current_location
		context["recent_subjects"] = npc_state.recent_subjects
		context["npc_beliefs"] = memory.beliefs
	
	var resolver := EntityResolver.new()
	var matches: Array = resolver.resolve_entity_smart(subject, entities, context)
	
	if matches.is_empty():
		return {"found": false, "content": "", "confidence": 0.0}
	
	# If multiple high-confidence matches, handle ambiguity
	if matches.size() > 1 and matches[0].confidence - matches[1].confidence < 20:
		return _handle_ambiguity(matches, memory)
	
	# Use top match
	var best_entity_id: String = matches[0].entity_id
	return _query_entity_facts(best_entity_id, memory)
```

### Tier 4: Disambiguation Dialogue

When ambiguity cannot be resolved algorithmically, **ask the player for clarification**:

```gdscript
func _handle_ambiguity(matches: Array, memory: NPCMemoryResource) -> Dictionary:
	# Generate clarification question
	var options: Array[String] = []
	for match in matches:
		var entity: Dictionary = entities[match.entity_id]
		options.append(entity.get("display", match.entity_id))
	
	var clarification := "Which one do you mean: %s?" % ", ".join(options)
	
	return {
		"found": false,
		"content": clarification,
		"confidence": 0.0,
		"requires_disambiguation": true,
		"options": options,
		"match_entity_ids": matches.map(func(m): return m.entity_id)
	}
```

The dialogue system then:
1. Presents the clarification question to the player
2. Stores the ambiguity context
3. Waits for player's next input to specify which entity they meant
4. Re-queries with the specific entity ID

---

## Implementation Phases

### Phase 1: Update Entity Schema ✓ FOUNDATIONAL
**Goal**: Add disambiguation fields to entities.json

1. Add `primary_aliases`, `qualified_aliases`, `ambiguous_aliases` arrays
2. Add `parent_concept` field for hierarchical entities
3. Add `location` field where relevant
4. Migration: Move current `aliases` into appropriate categories

**Validation**: No change to existing behavior yet, but data is structured for disambiguation.

### Phase 2: Implement EntityResolver ✓ CORE LOGIC
**Goal**: Create multi-match resolution system

1. Create `entity_resolver.gd` with `resolve_entity_smart()` method
2. Return ranked array of `EntityMatch` objects instead of single string
3. Implement context scoring with NPC knowledge, location, recency
4. Add unit tests for each disambiguation case

**Validation**: Resolver returns correct top match for test cases.

### Phase 3: Integrate into KnowledgeAdapter ✓ INTEGRATION
**Goal**: Wire resolver into existing query flow

1. Modify `query_belief()` to use `EntityResolver`
2. Pass `NPCState` context into resolution
3. Handle single-match (proceed as before) vs multi-match (disambiguate)
4. Add `requires_disambiguation` flag to query results

**Validation**: Existing queries still work; ambiguous queries return clarification prompts.

### Phase 4: Disambiguation Dialogue ✓ UX POLISH
**Goal**: Allow player to resolve ambiguity naturally

1. Detect `requires_disambiguation` in dialogue manager
2. Present clarification options to player
3. Store disambiguation context in `NPCState`
4. Re-query with specific entity ID on next input
5. Add "I meant X, not Y" fallback for corrections

**Validation**: Player can successfully clarify ambiguous queries.

---

## Migration Guide

### Converting Existing Entities

**Before**:
```json
{
	"blacksmith": {
		"type": "person",
		"display": "the blacksmith",
		"aliases": ["blacksmith", "smith", "forge"]
	}
}
```

**After**:
```json
{
	"blacksmith_gregor": {
		"type": "person",
		"subtype": "occupation",
		"display": "Gregor the blacksmith",
		"primary_aliases": ["gregor", "gregor the smith"],
		"qualified_aliases": ["forge quarter blacksmith", "blacksmith near foundry"],
		"ambiguous_aliases": ["blacksmith", "smith"],
		"location": "forge_quarter"
	}
}
```

### Rules for Alias Classification

**Primary Aliases** (Unique identifiers):
- Proper names: "gregor", "elena"
- Unique descriptors: "archmage", "captain of the guard"
- Full titles: "king aldric iii"

**Qualified Aliases** (Context-specific):
- Location-qualified: "forge quarter blacksmith"
- Descriptor-qualified: "old blacksmith"
- Relational: "the king's blacksmith"

**Ambiguous Aliases** (Shared terms - FLAG for disambiguation):
- Generic roles: "blacksmith", "merchant", "guard"
- Common nouns: "crown", "sword", "tavern"
- Pronouns: "he", "she", "it" (handled by coreference system)

---

## Edge Cases & Handling

### Case 1: Generic Query with No Context
**Query**: "Where is the blacksmith?"
**NPC Knowledge**: Knows about both blacksmiths
**Resolution**:
1. Resolver finds 2 matches with low confidence differential
2. Apply context scoring: NPC is in Forge Quarter
3. Boost `blacksmith_forge_quarter` confidence (+20)
4. Return: "Gregor's forge is just down the street."

**Alternative** (if confidence still tied):
Return: "Do you mean Gregor in the Forge Quarter or Elena by the market?"

### Case 2: Qualified Query
**Query**: "Where is the west market blacksmith?"
**Resolution**:
1. Resolver finds qualified alias match on `blacksmith_west_market`
2. High confidence (80+) with no close competitors
3. Return: "Elena's smithy is by the fountain in West Market."

### Case 3: Polysemy with Type Clue
**Query**: "How much do gold crowns cost?"
**Resolution**:
1. Context: "how much" + "cost" signals commerce/currency
2. Resolver finds both `gold_crowns` (currency) and `royal_crown` (regalia)
3. Context scoring boosts `gold_crowns` due to subtype match
4. Return: "Gold crowns are worth about 10 silver pieces each."

### Case 4: Hierarchical Specificity
**Query**: "Tell me about the guests."
**NPC Context**: Recently discussed Sir Aldric's wedding
**Resolution**:
1. Resolver finds both `guests` (concept) and `wedding_guests` (specific)
2. `recent_subjects` contains "wedding" → boost `wedding_guests` (+15)
3. Specificity bonus for child concept → further boost (+10)
4. Return: "There were fifty guests at Sir Aldric's wedding..."

**Alternative** (no wedding context):
Return: "In our culture, guests are fed before they are questioned."

---

## Testing Strategy

### Unit Tests for EntityResolver

```gdscript
func test_exact_match():
	# "gregor" → blacksmith_gregor (100 confidence)
	assert_equal(resolver.resolve_entity_smart("gregor", entities)[0].entity_id, "blacksmith_gregor")

func test_qualified_alias():
	# "forge quarter blacksmith" → blacksmith_gregor (80 confidence)
	var matches = resolver.resolve_entity_smart("forge quarter blacksmith", entities)
	assert_equal(matches[0].entity_id, "blacksmith_gregor")

func test_ambiguous_with_location_context():
	# "blacksmith" with NPC in forge_quarter → blacksmith_gregor
	var context = {"npc_location": "forge_quarter"}
	var matches = resolver.resolve_entity_smart("blacksmith", entities, context)
	assert_equal(matches[0].entity_id, "blacksmith_gregor")

func test_ambiguous_no_context():
	# "blacksmith" with no context → returns both, requires disambiguation
	var matches = resolver.resolve_entity_smart("blacksmith", entities)
	assert_equal(matches.size(), 2)
	assert_true(matches[0].confidence - matches[1].confidence < 20)

func test_polysemy_with_type_hint():
	# "crown" with recent mention of "currency" → gold_crowns
	var context = {"recent_subjects": ["currency", "trade"]}
	var matches = resolver.resolve_entity_smart("crown", entities, context)
	assert_equal(matches[0].entity_id, "gold_crowns")

func test_hierarchical_specificity():
	# "guests" with wedding context → wedding_guests (child concept)
	var context = {"recent_subjects": ["wedding"]}
	var matches = resolver.resolve_entity_smart("guests", entities, context)
	assert_equal(matches[0].entity_id, "wedding_guests")
```

### Integration Tests

```gdscript
func test_query_with_disambiguation():
	# NPC doesn't know location, both blacksmiths equal confidence
	var result = adapter.query_belief("blacksmith", npc_memory)
	assert_true(result.get("requires_disambiguation", false))
	assert_equal(result.get("options", []).size(), 2)

func test_query_after_clarification():
	# Player clarifies: "I meant the one in the market"
	npc_state.pending_disambiguation = {
		"original_query": "blacksmith",
		"options": ["blacksmith_gregor", "blacksmith_elena"]
	}
	var result = adapter.query_belief("the one in the market", npc_memory, npc_state)
	assert_equal(result.content, "Elena's smithy...")
```

---

## Summary

### Key Principles

1. **Prevention Over Correction**: Design entities with disambiguation in mind from the start
2. **Context is King**: Use NPC knowledge, location, and conversation history to resolve ambiguity
3. **Graceful Degradation**: When algorithmic resolution fails, ask the player
4. **Specificity Wins**: Prefer child concepts over parents, qualified over generic

### Benefits

- **No broken queries**: System handles "blacksmith" gracefully instead of random results
- **Natural dialogue**: Player can use generic terms; NPC figures out context
- **Extensible**: Easy to add new entities without breaking existing ones
- **Realistic NPC behavior**: "Which blacksmith do you mean?" is how real people talk

### Trade-offs

- **Complexity**: More sophisticated resolution logic
- **Data overhead**: Entities need more alias categories and metadata
- **Performance**: Resolution may scan multiple entities (mitigate with indexing)
- **Edge cases**: Some ambiguities may still require fallback to player clarification

---

## Next Steps

1. **Review this document** with your coding agent
2. **Validate the approach** against your specific use cases
3. **Prioritize phases** based on urgency (Phase 1-2 are critical)
4. **Create task specifications** for each phase
5. **Implement incrementally** with rollback capability at each phase
