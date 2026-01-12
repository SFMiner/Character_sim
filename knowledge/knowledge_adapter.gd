# knowledge_adapter.gd
# Epistemic firewall. ONLY code allowed to read world knowledge + NPC memory.
# Returns what NPC *believes*, not what is *true*.
# Belief always overrides truth when misinformation exists.
class_name KnowledgeAdapter
extends RefCounted

var world: WorldKnowledgeResource
var entities: Dictionary = {}
var entity_facts_index: Dictionary = {}


func _init(world_knowledge: WorldKnowledgeResource) -> void:
	world = world_knowledge
	_build_indices()


func set_entities(entity_data: Dictionary) -> void:
	entities = entity_data
	_build_indices()


func _build_indices() -> void:
	entity_facts_index.clear()
	for fact_id in world.facts:
		var fact: FactResource = world.facts[fact_id]
		var parsed: Array[String] = _parse_fact_entities(fact)
		for entity_id in parsed:
			if not entity_facts_index.has(entity_id):
				entity_facts_index[entity_id] = []
			entity_facts_index[entity_id].append(fact_id)


## Core query: what does this NPC believe about a subject?
## Returns Dictionary with "content" (String) and "confidence" (float)
## EXTENSION POINT: Add "source", "granularity", "is_secret" to result
func query_belief(subject: String, memory: NPCMemoryResource) -> Dictionary:
	print("[KnowledgeAdapter] query_belief subject=", subject)
	var result: Dictionary = {
		"found": false,
		"content": "",
		"confidence": 0.0,
		## EXTENSION POINT: Uncomment when needed
		# "source": "",
		# "granularity": 0,
		# "is_secret": false,
		# "has_prerequisites_met": true,
	}
	
	# Find facts matching subject
	var matching_facts: Array[FactResource] = _find_facts_by_subject(subject)
	print("[KnowledgeAdapter] matching_facts size=", matching_facts.size())
	if matching_facts.is_empty():
		return result
	
	# Check NPC's beliefs about these facts
	for fact in matching_facts:
		if not memory.beliefs.has(fact.fact_id):
			continue
		
		var confidence: float = memory.beliefs[fact.fact_id]
		if confidence <= 0.0:
			continue
		
		# Check for misinformation - belief overrides truth
		var content: String
		if memory.misinformation.has(fact.fact_id):
			content = memory.misinformation[fact.fact_id]
		else:
			content = fact.raw_content
		
		# Update last accessed (lazy decay prep)
		memory.last_accessed[fact.fact_id] = Time.get_unix_time_from_system()
		
		# Return first valid belief
		# EXTENSION POINT: Return best match based on confidence/recency
		result.found = true
		result.content = content
		result.confidence = confidence
		print("[KnowledgeAdapter] matched fact_id=", fact.fact_id, " confidence=", confidence)
		return result
	
	return result


func _find_facts_by_subject(subject: String) -> Array[FactResource]:
	var results: Array[FactResource] = []
	
	var entity_id := resolve_entity(subject)
	if not entity_id.is_empty():
		var fact_ids: Array = entity_facts_index.get(entity_id, [])
		for fact_id in fact_ids:
			if world.facts.has(fact_id):
				results.append(world.facts[fact_id])
		if not results.is_empty():
			return results
	
	return _find_facts_by_tags(subject)


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


func _parse_fact_entities(fact: FactResource) -> Array[String]:
	var found: Array[String] = []
	
	if not fact.subject_entity.is_empty():
		found.append(fact.subject_entity)
	if not fact.object_entity.is_empty():
		found.append(fact.object_entity)
	
	if not found.is_empty():
		return found
	
	var content := fact.raw_content.to_lower()
	for entity_id in entities:
		var entity: Dictionary = entities[entity_id]
		var display : String = entity.get("display", "").to_lower()
		if display.length() >= 3 and display in content:
			found.append(entity_id)
			continue
		for alias in entity.get("aliases", []):
			if alias.to_lower() in content:
				if entity_id not in found:
					found.append(entity_id)
	
	return found


func _find_facts_by_tags(subject: String) -> Array[FactResource]:
	var results: Array[FactResource] = []
	var search_term: String = subject.to_lower()
	
	for fact_id in world.facts:
		var fact: FactResource = world.facts[fact_id]
		var matched: bool = false
		
		# Check tags (with fuzzy matching)
		for tag in fact.tags:
			var lower_tag: String = tag.to_lower()
			if _fuzzy_match(search_term, lower_tag):
				matched = true
				break
		
		# Check raw content (with fuzzy matching on key words)
		if not matched:
			var content_words: PackedStringArray = fact.raw_content.to_lower().split(" ", false)
			var stopwords: Array[String] = ["the", "a", "an", "is", "in", "of", "to", "and", "for", "from", "on", "at", "by", "near"]
			for word in content_words:
				# Clean punctuation
				var clean_word: String = word.trim_prefix("|").trim_suffix("|").strip_edges()
				clean_word = clean_word.trim_suffix(",").trim_suffix(".").trim_suffix("?").trim_suffix("!").trim_suffix(":").trim_suffix(";")
				if clean_word.length() < 3:
					continue
				if clean_word in stopwords:
					continue
				if _fuzzy_match(search_term, clean_word):
					matched = true
					break
		
		if matched:
			results.append(fact)
	
	return results


## Check if two strings match (exact or fuzzy within edit distance)
func _fuzzy_match(query: String, target: String, max_distance: int = 2) -> bool:
	if query.is_empty() or target.is_empty():
		return false
	# Exact substring match
	if query in target or target in query:
		return true
	
	# For short words, require closer match
	var min_len: int = min(query.length(), target.length())
	if min_len <= 5:
		max_distance = 1
	else:
		# Require same start/end when allowing wider matches
		if query[0] != target[0]:
			return false
		if query[query.length() - 1] != target[target.length() - 1]:
			return false
	
	# Levenshtein distance for typo tolerance
	var distance: int = _levenshtein_distance(query, target)
	return distance <= max_distance


## Calculate Levenshtein edit distance between two strings
func _levenshtein_distance(s1: String, s2: String) -> int:
	var len1: int = s1.length()
	var len2: int = s2.length()
	
	# Early exit for empty strings
	if len1 == 0:
		return len2
	if len2 == 0:
		return len1
	
	# Early exit if difference in length exceeds reasonable threshold
	if abs(len1 - len2) > 3:
		return abs(len1 - len2)
	
	# Create distance matrix (using two rows for memory efficiency)
	var prev_row: Array[int] = []
	var curr_row: Array[int] = []
	
	# Initialize first row
	for j in range(len2 + 1):
		prev_row.append(j)
		curr_row.append(0)
	
	# Fill in the rest of the matrix
	for i in range(1, len1 + 1):
		curr_row[0] = i
		
		for j in range(1, len2 + 1):
			var cost: int = 0 if s1[i - 1] == s2[j - 1] else 1
			
			curr_row[j] = min(
				prev_row[j] + 1,      # Deletion
				min(
					curr_row[j - 1] + 1,  # Insertion
					prev_row[j - 1] + cost  # Substitution
				)
			)
		
		# Swap rows
		var temp: Array[int] = prev_row
		prev_row = curr_row
		curr_row = temp
	
	return prev_row[len2]


## Check if NPC has any knowledge about a topic
func has_knowledge_of_topic(topic: String, memory: NPCMemoryResource) -> bool:
	var belief: Dictionary = query_belief(topic, memory)
	return belief.found


## EXTENSION POINT: Skill-gated knowledge
# func query_belief_gated(subject: String, memory: NPCMemoryResource, skills: Dictionary) -> Dictionary:
#     var belief: Dictionary = query_belief(subject, memory)
#     if not belief.found:
#         return belief
#     # Check skill requirements on the underlying fact
#     var fact: FactResource = _find_fact_for_belief(subject, memory)
#     if fact and fact.skill_requirements:
#         for skill_name in fact.skill_requirements:
#             var required: float = fact.skill_requirements[skill_name]
#             var has_skill: float = skills.get(skill_name, 0.0)
#             if has_skill < required:
#                 belief.found = false
#                 belief.content = ""
#                 break
#     return belief


## EXTENSION POINT: Memory decay
# func apply_decay(memory: NPCMemoryResource, current_time: float, decay_rate: float) -> void:
#     var to_remove: Array[int] = []
#     for fact_id in memory.beliefs:
#         var last_time: float = memory.last_accessed.get(fact_id, 0.0)
#         var elapsed: float = current_time - last_time
#         var decay: float = exp(-decay_rate * elapsed)
#         memory.beliefs[fact_id] *= decay
#         if memory.beliefs[fact_id] < 0.1:
#             to_remove.append(fact_id)
#     for fact_id in to_remove:
#         memory.beliefs.erase(fact_id)
