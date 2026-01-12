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
@onready var memory_panel: PanelContainer = %MemoryPanel
@onready var memory_label: Label = %MemoryLabel
@onready var memory_filter: LineEdit = %MemoryPanel/MemoryVBox/MemoryControls/MemoryFilter
@onready var memory_sort: OptionButton = %MemoryPanel/MemoryVBox/MemoryControls/MemorySort
@onready var memory_sort_ascending: CheckButton = %MemoryPanel/MemoryVBox/MemoryControls/MemoryAscending
@onready var memory_refresh: Button = %MemoryPanel/MemoryVBox/MemoryControls/MemoryRefresh
@onready var memory_toggle: CheckButton = %MemoryToggle
@onready var memory_table: Tree = %MemoryPanel/MemoryVBox/MemoryScroll/MemoryTable

## Toggle for debug output
var show_debug: bool = false
var memory_rows: Array = []
var memory_sort_key: String = "fact_id"
var memory_sort_is_ascending: bool = false


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
	_update_character_header()
	
	# Initialize turn counter
	_update_turn_label()
	
	# Focus input field
	_reset_input_state()
	
	# Add welcome message
	_add_system_message("Type a message and press Enter or click Submit.")
	_add_system_message("Try asking: 'Where is the blacksmith?' or 'Who is the king?'")
	
	_setup_memory_panel()


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
		_swap_character_from_scene("res://main.tscn")
		return
	if target in ["marcus", "old", "oldmarcus", "old_marcus", "human"]:
		_swap_character_from_scene("res://human_npc.tscn")
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


func _update_character_header() -> void:
	if character_node and character_label:
		character_label.text = "Talking to: " + character_node.get_character_name()
		if character_node.profile:
			character_label.text += " (" + character_node.profile.character_type + ")"


func _swap_character_from_scene(scene_path: String) -> void:
	if not character_node:
		_add_system_message("Error: No character node assigned!")
		return
	if not WorldKnowledge or not WorldKnowledge.knowledge:
		_add_system_message("Error: World knowledge not initialized.")
		return
	
	var packed := load(scene_path) as PackedScene
	if not packed:
		_add_system_message("Error: Could not load %s" % scene_path)
		return
	
	var scene_root := packed.instantiate()
	var scene_character := scene_root.get_node_or_null("CharacterNode") as CharacterNodeClass
	if not scene_character:
		scene_root.free()
		_add_system_message("Error: CharacterNode missing in %s" % scene_path)
		return
	
	character_node.profile = scene_character.profile
	character_node.initial_memory = scene_character.initial_memory
	character_node.initialize(WorldKnowledge.knowledge)
	scene_root.free()
	
	_update_character_header()
	_update_turn_label()
	_refresh_memory_table()
	_add_system_message("Switched to %s." % character_node.get_character_name())


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


func _setup_memory_panel() -> void:
	if not memory_table:
		return
	
	memory_table.columns = 3
	memory_table.hide_root = true
	memory_table.column_titles_visible = true
	memory_table.set_column_title(0, "Fact ID")
	memory_table.set_column_title(1, "Certainty")
	memory_table.set_column_title(2, "Raw Content")
	
	if memory_sort:
		memory_sort.clear()
		memory_sort.add_item("Fact ID")
		memory_sort.add_item("Certainty")
		memory_sort.add_item("Raw Content")
		memory_sort.select(0)
	
	if memory_filter:
		memory_filter.text_changed.connect(_on_memory_filter_changed)
	if memory_sort:
		memory_sort.item_selected.connect(_on_memory_sort_changed)
	if memory_sort_ascending:
		memory_sort_ascending.toggled.connect(_on_memory_sort_toggled)
	if memory_refresh:
		memory_refresh.pressed.connect(_refresh_memory_table)
	if memory_toggle:
		memory_toggle.toggled.connect(_on_memory_toggle_toggled)
	
	_refresh_memory_table()


func _refresh_memory_table() -> void:
	memory_rows.clear()
	
	var memory: NPCMemoryResource = null
	var npc_name: String = "Unknown"
	if character_node:
		npc_name = character_node.get_character_name()
		if character_node.state and character_node.state.memory:
			memory = character_node.state.memory
		elif character_node.initial_memory:
			memory = character_node.initial_memory
	
	if memory_label:
		memory_label.text = "%s Memory Facts" % npc_name
	
	if memory:
		for fact_id in memory.beliefs.keys():
			var certainty: float = float(memory.beliefs[fact_id])
			var fact: FactResource = WorldKnowledge.get_fact(int(fact_id))
			var raw_content: String = ""
			if fact:
				raw_content = fact.raw_content
			else:
				raw_content = "<missing fact %s>" % str(fact_id)
			
			memory_rows.append({
				"npc_name": npc_name,
				"fact_id": int(fact_id),
				"certainty": certainty,
				"raw_content": raw_content
			})
	
	_rebuild_memory_table()


func _on_memory_filter_changed(_text: String) -> void:
	_rebuild_memory_table()


func _on_memory_sort_changed(index: int) -> void:
	match index:
		0:
			memory_sort_key = "fact_id"
		1:
			memory_sort_key = "certainty"
		2:
			memory_sort_key = "raw_content"
		_:
			memory_sort_key = "fact_id"
	_rebuild_memory_table()


func _on_memory_sort_toggled(pressed: bool) -> void:
	memory_sort_is_ascending = pressed
	_rebuild_memory_table()


func _on_memory_toggle_toggled(pressed: bool) -> void:
	if memory_panel:
		memory_panel.visible = pressed


func _rebuild_memory_table() -> void:
	if not memory_table:
		return
	
	memory_table.clear()
	var root := memory_table.create_item()
	
	var filter_text := ""
	if memory_filter:
		filter_text = memory_filter.text.strip_edges().to_lower()
	
	var rows := memory_rows.duplicate()
	rows.sort_custom(Callable(self, "_sort_memory_rows"))
	
	for row in rows:
		if not _memory_row_matches_filter(row, filter_text):
			continue
		var item := memory_table.create_item(root)
		item.set_text(0, str(row["fact_id"]))
		item.set_text(1, "%0.2f" % row["certainty"])
		item.set_text(2, row["raw_content"])


func _memory_row_matches_filter(row: Dictionary, filter_text: String) -> bool:
	if filter_text.is_empty():
		return true
	
	if str(row["fact_id"]).find(filter_text) != -1:
		return true
	if ("%0.2f" % row["certainty"]).find(filter_text) != -1:
		return true
	if row["raw_content"].to_lower().find(filter_text) != -1:
		return true
	
	return false


func _sort_memory_rows(a: Dictionary, b: Dictionary) -> bool:
	var order := 0
	match memory_sort_key:
		"fact_id":
			order = _compare_numeric(a["fact_id"], b["fact_id"])
		"certainty":
			order = _compare_numeric(a["certainty"], b["certainty"])
		"raw_content":
			order = a["raw_content"].nocasecmp_to(b["raw_content"])
		_:
			order = _compare_numeric(a["fact_id"], b["fact_id"])
	
	if memory_sort_is_ascending:
		return order < 0
	return order > 0


func _compare_numeric(a_value: float, b_value: float) -> int:
	if a_value < b_value:
		return -1
	if a_value > b_value:
		return 1
	return 0
