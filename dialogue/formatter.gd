# formatter.gd
# Final assembly. No logic, no branching.
# Assembles skeleton parts with content into final response.
class_name Formatter
extends RefCounted


## Assembles skeleton parts with content into final response.
func format(skeleton: Dictionary, content: String, profile: CharacterProfile) -> String:
	var preamble: String = skeleton.get("preamble", "")
	var body: String = skeleton.get("body", "{content}")
	var postamble: String = skeleton.get("postamble", "")
	
	# Insert content into body
	body = body.replace("{content}", content)
	
	# Assemble parts
	var parts: Array[String] = []
	if not preamble.is_empty():
		parts.append(preamble)
	if not body.is_empty():
		parts.append(body)
	if not postamble.is_empty():
		parts.append(postamble)
	
	var result: String = " ".join(parts)
	
	# Apply hedge intensity for LLM characters
	if profile.character_type == "llm" and profile.hedge_intensity > 0.5:
		result = _apply_hedging(result, profile.hedge_intensity)
	
	# Clean up spacing and punctuation
	result = _clean_text(result)
	
	return result


func _apply_hedging(text: String, intensity: float) -> String:
	# Only apply additional hedging for high intensity
	if intensity < 0.7:
		return text
	
	# Don't double-hedge
	if _starts_with_hedge(text):
		return text
	
	# Add uncertainty marker
	var hedges: Array[String] = [
		"I believe ",
		"It seems that ",
		"From my understanding, ",
		"As far as I know, ",
	]
	
	# Select deterministically based on text hash to avoid randomness
	var hedge_index: int = text.hash() % hedges.size()
	var hedge: String = hedges[hedge_index]
	
	# Lowercase the first character of original text
	var first_char: String = text[0].to_lower() if text.length() > 0 else ""
	var rest: String = text.substr(1) if text.length() > 1 else ""
	
	return hedge + first_char + rest


func _starts_with_hedge(text: String) -> bool:
	var hedge_starts: Array[String] = [
		"I believe",
		"I think",
		"It seems",
		"Perhaps",
		"From my",
		"If I recall",
		"As far as",
		"To my knowledge",
	]
	for h in hedge_starts:
		if text.begins_with(h):
			return true
	return false


func _clean_text(text: String) -> String:
	var result: String = text
	
	# Remove double spaces
	while "  " in result:
		result = result.replace("  ", " ")
	
	# Fix space before punctuation
	result = result.replace(" .", ".")
	result = result.replace(" ,", ",")
	result = result.replace(" ?", "?")
	result = result.replace(" !", "!")
	
	# Ensure single space after periods (not double)
	result = result.replace(". ", ".  ")
	result = result.replace(".  ", ". ")
	
	# Capitalize first letter
	result = result.strip_edges()
	if result.length() > 0:
		result = result[0].to_upper() + result.substr(1)
	
	return result
