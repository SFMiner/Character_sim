# template_rewriter.gd
# Safe variation only. Does NOT change meaning.
# Rules: NO changing nouns, numbers, proper names. Only connectives/auxiliaries.
# Deterministic (seeded) or static.
class_name TemplateRewriter
extends RefCounted

var rng: RandomNumberGenerator


func _init(seed_value: int = 0) -> void:
	rng = RandomNumberGenerator.new()
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()


## Apply safe variations to text. Returns modified text.
func rewrite(text: String) -> String:
	var result: String = text
	
	# Safe substitutions only
	result = _vary_connectives(result)
	result = _vary_auxiliaries(result)
	result = _vary_fillers(result)
	
	return result


func _vary_connectives(text: String) -> String:
	# Only replace whole phrases, not partial matches
	var substitutions: Dictionary = {
		"However, ": ["That said, ", "Though, ", "Nevertheless, "],
		"Additionally, ": ["Also, ", "Furthermore, ", "Moreover, "],
		"Therefore, ": ["Thus, ", "So, ", "Hence, "],
		"In fact, ": ["Actually, ", "Indeed, ", "As it happens, "],
		"For example, ": ["For instance, ", "To illustrate, ", "Such as "],
	}
	
	var result: String = text
	for original in substitutions:
		if original in result:
			var options: Array = substitutions[original]
			# Only vary 30% of the time for consistency
			if rng.randf() > 0.7:
				var replacement: String = options[rng.randi() % options.size()]
				result = result.replace(original, replacement)
	
	return result


func _vary_auxiliaries(text: String) -> String:
	# Very conservative - only vary complete phrases
	var substitutions: Dictionary = {
		"I can tell you that": ["I know that", "I can say that"],
		"I don't have": ["I lack", "I'm without"],
		"I'm not able to": ["I cannot", "I'm unable to"],
		"I don't know": ["I'm not sure", "I'm uncertain"],
		"I understand": ["I see", "I hear you"],
	}
	
	var result: String = text
	for original in substitutions:
		if original in result:
			var options: Array = substitutions[original]
			# Only vary 30% of the time
			if rng.randf() > 0.7:
				var replacement: String = options[rng.randi() % options.size()]
				result = result.replace(original, replacement)
	
	return result


func _vary_fillers(text: String) -> String:
	# Safe filler variations for natural speech
	var substitutions: Dictionary = {
		"I'm afraid ": ["Unfortunately, ", "Sadly, ", "I'm sorry, but "],
		"Perhaps ": ["Maybe ", "Possibly ", "It could be that "],
		"Of course": ["Certainly", "Absolutely", "Yes"],
	}
	
	var result: String = text
	for original in substitutions:
		if original in result:
			var options: Array = substitutions[original]
			if rng.randf() > 0.7:
				var replacement: String = options[rng.randi() % options.size()]
				result = result.replace(original, replacement)
	
	return result


## Reset the random seed for deterministic testing
func set_seed(seed_value: int) -> void:
	rng.seed = seed_value


## EXTENSION POINT: Personality-influenced variation
# func rewrite_with_personality(text: String, personality: Dictionary) -> String:
#     var result: String = text
#     
#     # Warm personalities add softeners
#     if personality.get("warmth", 0.0) > 0.5:
#         result = _add_warmth_markers(result)
#     
#     # Assertive personalities remove hedging
#     if personality.get("assertiveness", 0.0) > 0.5:
#         result = _remove_hedging(result)
#     
#     return result
#
# func _add_warmth_markers(text: String) -> String:
#     # Add friendly endings occasionally
#     if rng.randf() > 0.8:
#         if not text.ends_with("friend.") and not text.ends_with("!"):
#             text = text.trim_suffix(".") + ", friend."
#     return text
#
# func _remove_hedging(text: String) -> String:
#     text = text.replace("I think ", "")
#     text = text.replace("Perhaps ", "")
#     text = text.replace("Maybe ", "")
#     return text
