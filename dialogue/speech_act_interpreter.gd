# speech_act_interpreter.gd
# Classifies player input into speech acts.
# Deterministic: same input -> same classification.
# Uses keyword + punctuation heuristics only.
class_name SpeechActInterpreter
extends RefCounted

enum SpeechAct {
	ASK_ABOUT,       # Questions seeking information
	REQUEST_HELP,    # Requests for action/assistance
	CHALLENGE,       # Confrontational or accusatory
	PROBE_BOUNDARY,  # Testing limits, forbidden topics
	CASUAL_TALK,     # Greetings, small talk
}


## Returns classified speech act and extracted subject.
## EXTENSION POINT: Add urgency, emotional_tone, formality to result
func classify(input: String) -> Dictionary:
	var lower: String = input.to_lower().strip_edges()
	
	var result: Dictionary = {
		"speech_act": SpeechAct.CASUAL_TALK,
		"subject": _extract_subject(lower),
		"raw_input": input,
		## EXTENSION POINT: Uncomment when needed
		# "urgency": _assess_urgency(lower),
		# "emotional_tone": _assess_tone(lower),
		# "formality": _assess_formality(lower),
	}
	
	result.speech_act = _classify_act(lower)
	return result


func _classify_act(text: String) -> SpeechAct:
	# Question patterns - check these first
	if _is_question(text):
		return SpeechAct.ASK_ABOUT
	
	# Request patterns
	if _matches_any(text, ["can you", "could you", "would you", "please", "help me", "i need"]):
		return SpeechAct.REQUEST_HELP
	
	# Challenge patterns
	if _matches_any(text, ["you're lying", "that's wrong", "prove it", "i don't believe", "liar"]):
		return SpeechAct.CHALLENGE
	
	# Probe patterns (often leading questions)
	if _matches_any(text, ["what about", "but what if", "why won't you", "why can't you"]):
		return SpeechAct.PROBE_BOUNDARY
	
	# Greetings and casual talk
	if _matches_any(text, ["hello", "hi", "hey", "greetings", "good morning", "good evening"]):
		return SpeechAct.CASUAL_TALK
	if _matches_any(text, ["how are you", "what's up", "nice to meet"]):
		return SpeechAct.CASUAL_TALK
	
	# Default
	return SpeechAct.CASUAL_TALK


func _is_question(text: String) -> bool:
	# Ends with question mark
	if text.ends_with("?"):
		return true
	
	# Starts with question words
	var question_starters: Array[String] = [
		"where", "who", "what", "when", "why", "how",
		"do you", "can you", "have you", "is the", "are there"
	]
	for starter in question_starters:
		if text.begins_with(starter):
			return true
	
	# Contains question phrases
	if _matches_any(text, ["tell me about", "do you know", "have you heard"]):
		return true
	
	return false


func _extract_subject(text: String) -> String:
	# Check for self-referential questions first
	if _is_self_reference(text):
		return "__SELF__"  # Special marker for NPC self-reference
	
	# Try to extract the main subject from the query
	
	# Pattern: "where is the X", "where is X"
	var where_patterns: Array[String] = [
		"where is the ",
		"where is ",
		"where are the ",
		"where are ",
		"where were the ",
		"where were ",
		"where can i find the ",
		"where can i find "
	]
	for pattern in where_patterns:
		var idx: int = text.find(pattern)
		if idx >= 0:
			var remainder: String = text.substr(idx + pattern.length())
			return _extract_noun_phrase(remainder)
	
	# Pattern: "who is the X", "who is X"
	var who_patterns: Array[String] = ["who is the ", "who is ", "who's the ", "who's "]
	for pattern in who_patterns:
		var idx: int = text.find(pattern)
		if idx >= 0:
			var remainder: String = text.substr(idx + pattern.length())
			return _extract_noun_phrase(remainder)
	
	# Pattern: "what is the X", "what is X"
	var what_patterns: Array[String] = ["what is the ", "what is ", "what's the ", "what's "]
	for pattern in what_patterns:
		var idx: int = text.find(pattern)
		if idx >= 0:
			var remainder: String = text.substr(idx + pattern.length())
			return _extract_noun_phrase(remainder)

	# Pattern: "when did/was/is/does the X (end/start/etc.)"
	var when_patterns: Array[String] = ["when did the ", "when did ", "when was the ", "when was ", "when is the ", "when is ", "when does the ", "when does "]
	for pattern in when_patterns:
		var idx: int = text.find(pattern)
		if idx >= 0:
			var remainder: String = text.substr(idx + pattern.length())
			return _extract_noun_phrase(remainder)
	
	# Pattern: "about the X", "about X"
	var about_patterns: Array[String] = ["about the ", "about "]
	for pattern in about_patterns:
		var idx: int = text.find(pattern)
		if idx >= 0:
			var remainder: String = text.substr(idx + pattern.length())
			return _extract_noun_phrase(remainder)
	
	# Pattern: "tell me about X"
	if "tell me" in text:
		var idx: int = text.find("tell me")
		var remainder: String = text.substr(idx + 7).strip_edges()
		if remainder.begins_with("about "):
			remainder = remainder.substr(6)
		return _extract_noun_phrase(remainder)
	
	return ""


## Check if the question is asking about the NPC themselves
func _is_self_reference(text: String) -> bool:
	var self_patterns: Array[String] = [
		"who are you",
		"what are you",
		"what's your name",
		"what is your name",
		"your name",
		"tell me about yourself",
		"about yourself",
		"introduce yourself",
		"who do you",
		"what do you do",
		"describe yourself",
	]
	
	for pattern in self_patterns:
		if pattern in text:
			return true
	
	return false


func _extract_noun_phrase(text: String) -> String:
	# Clean and extract first noun phrase
	var clean: String = text.strip_edges()
	clean = clean.trim_suffix("?")
	clean = clean.trim_suffix("!")
	clean = clean.trim_suffix(".")
	
	var words: PackedStringArray = clean.split(" ", false)
	if words.is_empty():
		return ""
	
	# Take first 1-3 words as subject
	var adjectives: Array[String] = ["old", "new", "great", "ancient", "local", "royal", "city"]
	
	if words.size() >= 2 and words[0] in adjectives:
		return words[0] + " " + words[1]
	
	return words[0]


func _matches_any(text: String, patterns: Array) -> bool:
	for pattern in patterns:
		if pattern in text:
			return true
	return false


## EXTENSION POINT: Assess urgency from text
# func _assess_urgency(text: String) -> float:
#     var urgency: float = 0.5
#     if "!" in text:
#         urgency += 0.2
#     if _matches_any(text, ["urgent", "immediately", "now", "quick"]):
#         urgency += 0.3
#     return clamp(urgency, 0.0, 1.0)


## EXTENSION POINT: Assess emotional tone
# func _assess_tone(text: String) -> float:
#     var tone: float = 0.0
#     var positive: Array[String] = ["please", "friend", "appreciate", "thank", "kind"]
#     var negative: Array[String] = ["fool", "idiot", "stupid", "damn"]
#     for word in positive:
#         if word in text:
#             tone += 0.2
#     for word in negative:
#         if word in text:
#             tone -= 0.3
#     return clamp(tone, -1.0, 1.0)
