# dialogue_manager.gd
# Orchestrates the full dialogue pipeline. Stateless - all state in NPCState.
# Pipeline: Input -> Interpret -> Resolve -> Query -> Decide -> Select -> Format -> Rewrite
class_name DialogueManager
extends RefCounted

var interpreter: SpeechActInterpreter
var context_resolver: ContextState
var knowledge_adapter: KnowledgeAdapter
var decision_gate: DecisionGate
var skeleton_engine: SkeletonEngine
var rewriter: TemplateRewriter
var formatter: Formatter


func _init(world_knowledge: WorldKnowledgeResource, skeleton_data: Dictionary = {}) -> void:
	interpreter = SpeechActInterpreter.new()
	context_resolver = ContextState.new()
	knowledge_adapter = KnowledgeAdapter.new(world_knowledge)
	decision_gate = DecisionGate.new()
	skeleton_engine = SkeletonEngine.new(skeleton_data)
	rewriter = TemplateRewriter.new()
	formatter = Formatter.new()


## Main entry point. Returns response string.
func process(input: String, profile: CharacterProfile, state: NPCState) -> String:
	print("[DialogueManager] input=", input, " character=", profile.character_name)
	# === STEP 1: Classify speech act ===
	var classification: Dictionary = interpreter.classify(input)
	var speech_act: SpeechActInterpreter.SpeechAct = classification.speech_act
	var subject: String = classification.subject
	print("[DialogueManager] speech_act=", SpeechActInterpreter.SpeechAct.keys()[speech_act], " subject=", subject)
	
	# === STEP 2: Resolve coreference ===
	var resolution: Dictionary = context_resolver.resolve(input, state)
	if resolution.used_reference:
		subject = resolution.referenced_subject
		print("[DialogueManager] coreference -> ", subject)
	
	# === STEP 2.5: Resolve self-reference ===
	if subject == "__SELF__":
		subject = profile.character_name.to_lower()
		print("[DialogueManager] self-reference -> ", subject)
	
	# === STEP 3: Query knowledge (if subject exists) ===
	var belief: Dictionary = {"found": false, "content": "", "confidence": 0.0}
	if not subject.is_empty():
		belief = knowledge_adapter.query_belief(subject, state.memory)
		print("[DialogueManager] belief found=", belief.found, " content=", belief.content)
		# Update recent subjects (but not for self-reference)
		if subject != profile.character_name.to_lower():
			state.add_subject(subject)
	
	# === STEP 4: Decide what to do ===
	var decision_result: Dictionary = decision_gate.decide(
		speech_act,
		subject,
		profile,
		belief.found,
	)
	var decision: DecisionGate.Decision = decision_result.decision
	
	# === STEP 5: Select skeleton ===
	var skeleton: Dictionary = skeleton_engine.select(decision, speech_act, profile)
	
	# === STEP 6: Prepare content ===
	var content: String = ""
	if belief.found:
		content = _format_belief_content(belief.content)
	
	# === STEP 7: Format response ===
	var response: String = formatter.format(skeleton, content, profile)
	
	# === STEP 8: Apply safe variation ===
	response = rewriter.rewrite(response)
	
	# === STEP 9: Update state ===
	state.turn_count += 1
	state.add_response(response)
	
	return response


## Convert raw fact content to readable form
## "subject | predicate | object" -> "subject predicate object"
func _format_belief_content(raw: String) -> String:
	# Handle pipe-delimited format
	if " | " in raw:
		var parts: PackedStringArray = raw.split(" | ")
		if parts.size() >= 3:
			return "%s %s %s" % [parts[0], parts[1], parts[2]]
		elif parts.size() == 2:
			return "%s %s" % [parts[0], parts[1]]
	
	# Return as-is if not pipe-delimited
	return raw


## Get debug info about last processing (for testing)
func get_debug_info(input: String, profile: CharacterProfile, state: NPCState) -> Dictionary:
	var classification: Dictionary = interpreter.classify(input)
	var resolution: Dictionary = context_resolver.resolve(input, state)
	var subject: String = classification.subject
	var self_resolved: bool = false
	
	if resolution.used_reference:
		subject = resolution.referenced_subject
	
	# Resolve self-reference
	if subject == "__SELF__":
		subject = profile.character_name.to_lower()
		self_resolved = true
	
	var belief: Dictionary = {"found": false, "content": "", "confidence": 0.0}
	if not subject.is_empty():
		belief = knowledge_adapter.query_belief(subject, state.memory)
	
	var decision_result: Dictionary = decision_gate.decide(
		classification.speech_act,
		subject,
		profile,
		belief.found,
	)
	
	return {
		"speech_act": SpeechActInterpreter.SpeechAct.keys()[classification.speech_act],
		"extracted_subject": classification.subject,
		"resolved_subject": subject,
		"used_coreference": resolution.used_reference,
		"used_self_reference": self_resolved,
		"has_knowledge": belief.found,
		"belief_content": belief.content,
		"belief_confidence": belief.confidence,
		"decision": DecisionGate.Decision.keys()[decision_result.decision],
		"decision_reason": decision_result.reason,
		"turn_count": state.turn_count,
		"recent_subjects": state.recent_subjects,
	}
