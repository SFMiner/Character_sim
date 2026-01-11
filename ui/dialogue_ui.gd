# dialogue_ui.gd
# Simple UI for dialogue interaction.
# Contains input field, output display, and submit button.
extends Control

## Reference to the NPC character node (found at runtime)
var character_node: CharacterNodeClass

## UI Elements (assigned via @onready)
@onready var input_field: LineEdit = $VBoxContainer/InputContainer/InputField
@onready var output_display: RichTextLabel = $VBoxContainer/OutputDisplay
@onready var submit_button: Button = $VBoxContainer/InputContainer/SubmitButton
@onready var character_label: Label = $VBoxContainer/HeaderContainer/CharacterLabel
@onready var turn_label: Label = $VBoxContainer/HeaderContainer/TurnLabel
@onready var debug_panel: RichTextLabel = $VBoxContainer/DebugPanel

## Toggle for debug output
var show_debug: bool = false


func _ready() -> void:
	# Find the character node (sibling in scene tree)
	character_node = get_node_or_null("CharacterNode") as CharacterNodeClass
	if not character_node:
		push_error("DialogueUI: Could not find CharacterNode!")
	
	# Connect signals
	submit_button.pressed.connect(_on_submit_pressed)
	input_field.text_submitted.connect(_on_text_submitted)

	# Keep focus on input field during interaction
	input_field.focus_mode = Control.FOCUS_ALL
	submit_button.focus_mode = Control.FOCUS_NONE
	$VBoxContainer/InputContainer/DebugToggle.focus_mode = Control.FOCUS_NONE
	
	# Set up character label
	if character_node:
		character_label.text = "Talking to: " + character_node.get_character_name()
		if character_node.profile:
			character_label.text += " (" + character_node.profile.character_type + ")"
	
	# Initialize turn counter
	_update_turn_label()
	
	# Focus input field
	_reset_input_state()
	
	# Add welcome message
	_add_system_message("Type a message and press Enter or click Submit.")
	_add_system_message("Try asking: 'Where is the blacksmith?' or 'Who is the king?'")


func _on_submit_pressed() -> void:
	_process_input()
	_reset_input_state() # Added this call

func _on_text_submitted(text: String) -> void:
	_process_input()
	_reset_input_state() # Consistently call the same cleanup
		
func _reset_input_state() -> void:
	input_field.clear()
	# Defer focus until after UI updates complete
	input_field.call_deferred("grab_focus")
	
func _process_input() -> void:
	var input_text: String = input_field.text.strip_edges()
	
	if input_text.is_empty():
		return

	# Check for commands (starting with / or \)
	if input_text.length() > 0:
		var first_char: String = input_text[0]
		if first_char == "/" or first_char == "\\":
			_handle_command(input_text)
			return
	
	# Clear input
	input_field.clear()
	
	# Display player input
	_add_message("You", input_text, Color.CORNFLOWER_BLUE)
	
	# Get NPC response
	if character_node:
		# Show debug info if enabled
		if show_debug and debug_panel:
			var debug_info: Dictionary = character_node.debug_process(input_text)
			_show_debug_info(debug_info)
		
		var response: String = character_node.respond(input_text)
		_add_message(character_node.get_character_name(), response, Color.LIGHT_GREEN)
		_update_turn_label()
	else:
		_add_system_message("Error: No character node assigned!")
	
	# Re-focus input
	input_field.grab_focus()

func _handle_command(raw_text: String) -> void:
	var command_text: String = raw_text.substr(1).strip_edges()
	if command_text.is_empty():
		_add_system_message("Commands: /help, /switch <archivist|marcus>, /list, /debug")
		return
	
	var parts: PackedStringArray = command_text.split(" ", false)
	var command: String = parts[0].to_lower()
	var args: Array[String] = []
	for i in range(1, parts.size()):
		args.append(parts[i])
	
	match command:
		"help":
			_add_system_message("Commands: /help, /switch <archivist|marcus>, /list, /debug")
		"list":
			_add_system_message("Available characters: archivist, marcus")
		"switch":
			_handle_switch_command(args)
		"debug":
			toggle_debug()
			_add_system_message("Debug panel %s." % ("enabled" if show_debug else "disabled"))
		_:
			_add_system_message("Unknown command: %s (try /help)" % command)

func _handle_switch_command(args: Array[String]) -> void:
	if args.is_empty():
		_add_system_message("Usage: /switch <archivist|marcus>")
		return
	
	var target: String = args[0].to_lower()
	if target in ["archivist", "archivist-7", "archivist7", "llm"]:
		get_tree().change_scene_to_file("res://main.tscn")
		return
	if target in ["marcus", "old", "oldmarcus", "old_marcus", "human"]:
		get_tree().change_scene_to_file("res://human_npc.tscn")
		return
	
	_add_system_message("Unknown character: %s (try /switch archivist or /switch marcus)" % args[0])


func _add_message(speaker: String, message: String, color: Color) -> void:
	var formatted: String = "[color=#%s][b]%s:[/b][/color] %s\n" % [
		color.to_html(false),
		speaker,
		message
	]
	output_display.append_text(formatted)
	
	# Auto-scroll to bottom
	await get_tree().process_frame
	output_display.scroll_to_line(output_display.get_line_count())


func _add_system_message(message: String) -> void:
	var formatted: String = "[color=#888888][i]%s[/i][/color]\n" % message
	output_display.append_text(formatted)
	_reset_input_state() # Consistently call the same cleanup



func _update_turn_label() -> void:
	if character_node and turn_label:
		turn_label.text = "Turn: " + str(character_node.get_turn_count())


func _show_debug_info(info: Dictionary) -> void:
	if not debug_panel:
		return
	
	debug_panel.clear()
	debug_panel.append_text("[color=#AAAAAA]--- Debug Info ---\n")
	debug_panel.append_text("Speech Act: %s\n" % info.get("speech_act", "?"))
	debug_panel.append_text("Subject: '%s'\n" % info.get("resolved_subject", ""))
	debug_panel.append_text("Coreference: %s\n" % str(info.get("used_coreference", false)))
	debug_panel.append_text("Self-Reference: %s\n" % str(info.get("used_self_reference", false)))
	debug_panel.append_text("Has Knowledge: %s\n" % str(info.get("has_knowledge", false)))
	debug_panel.append_text("Decision: %s\n" % info.get("decision", "?"))
	debug_panel.append_text("Reason: %s\n" % info.get("decision_reason", "?"))
	debug_panel.append_text("Recent Subjects: %s[/color]\n" % str(info.get("recent_subjects", [])))


func toggle_debug() -> void:
	show_debug = not show_debug
	if debug_panel:
		debug_panel.visible = show_debug


func _input(event: InputEvent) -> void:
	# Toggle debug with F3
	if event.is_action_pressed("ui_page_down"):  # Or bind to F3
		toggle_debug()
