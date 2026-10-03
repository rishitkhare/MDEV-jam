extends Panel

func _ready() -> void:
	pass

# TODO fill these function definitions
func _on_dialogue_system_dialogue_advance(new_dialogue: Variant) -> void:
	pass # Replace with function body.

func _on_dialogue_system_display_options(choices: Variant) -> void:
	visible = false

func _on_dialogue_system_display_text() -> void:
	visible = true

func _on_dialogue_system_scroll_skip() -> void:
	pass # Replace with function body.

func _on_dialogue_system_scroll_text() -> void:
	pass # Replace with function body.

func _on_dialogue_system_scroll_text_fast() -> void:
	pass # Replace with function body.
