# Code is a little bit horrible right now because we have two different state machines that overlap.
# We will probably not fix this unless the need to edit this system greatly ever arises. If it ain't
# broke...
extends Control

# how fast the dialogue gets typed out on screen (seconds per character)
var char_typing_time = 0.015625

# enum defines state possibilities
enum DialogueState {INACTIVE, OPTIONS, OPENING, SCROLL_TXT, SCROLL_FIN, WAIT}
enum DialogueUIState {OPEN, CLOSED}
var state : int = DialogueUIState.CLOSED

# signals are sent to any other objects that are listening
signal on_dialogue_open(new_dialogue)
signal on_dialogue_close

# these signals are emitted when changing between text display or options choice display
signal display_options(choices)
signal display_text

# these signals are emitted for dialogue processes
signal scroll_text
signal scroll_text_fast
signal scroll_skip
signal dialogue_advance(new_dialogue)
signal dialogue_next_sound

# these signnals are emitted for option processes
signal option_select
signal option_change(selected)

# settings option that allows to end scrolling instantly
var skippable_dialogue : bool = false

# typing timer (time since last char typed)
var typing_timer = 0

# the player can only speed up dialogue after they let go of the key they used to advance the dialogue
var advance_released = false

var _dialogue_queue = [] # queue of lines to say
var current_dialogue : Dialogue
var _dialogue_state_machine

@onready var _current_options : OptionSet = null
@onready var selected : int = 0

# callback recieved when the dialogue system stops scrolling
func _on_dialogue_scrolled():
	set_state(DialogueState.SCROLL_FIN)

# callback method for initialization
func _ready():
	set_state(DialogueState.INACTIVE)
	
	# Commenting all this out because these singletons don't exist no more
# warning-ignore:return_value_discarded
	# TransitionScreen.connect("fade_away_fin",self,"resume")
# warning-ignore:return_value_discarded
	# TransitionScreen.connect("mid_fade_away", self, "_on_mid_fadeaway")
# warning-ignore:return_value_discarded
	# ItemGetUI.connect("item_get_fin", self, "resume")
	
	
# function for resuming dialogue after fadeaway (deprecated)
func resume():
	if _dialogue_state_machine == DialogueState.WAIT:
		
		# attempt to run any further commands
		while !_dialogue_queue.empty() && _dialogue_queue[0] is DialogueCommand:
			display_next_dialogue()
		
		if _dialogue_queue.empty():
			set_state(DialogueState.INACTIVE)
		else:
			set_state(DialogueState.SCROLL_FIN)
			if state == DialogueUIState.OPEN:
				display_next_dialogue()
			else:
				open_dialogueUI()

# function to be callback'd while screen is black (deprecated) (for now)
func _on_mid_fadeaway():
	# during any fade to black, execute as many of the next dialogue commands as possible
	# during the black screen
	while !_dialogue_queue.empty() && _dialogue_queue[0] is DialogueCommand:
		display_next_dialogue()
	
# callback method called every frame
func _process(delta):
	if(not Input.is_action_pressed("dialogue_advance")):
		advance_released = true
	
	match _dialogue_state_machine:
		DialogueState.SCROLL_TXT:
			if state == DialogueUIState.OPEN:
				while typing_timer > char_typing_time:
					if Input.is_action_pressed("dialogue_speed") or (advance_released and Input.is_action_pressed("dialogue_advance")):
						if skippable_dialogue:
							emit_signal("scroll_skip")
						else:
							emit_signal("scroll_text_fast")
					else:
						emit_signal("scroll_text")
					typing_timer -= char_typing_time
				typing_timer += delta
		DialogueState.OPENING:
			if Input.is_action_pressed("dialogue_speed") or (advance_released and Input.is_action_pressed("dialogue_advance")):
				# skips 1 second ahead in the animation, completing it immediately
				$AnimationPlayer.advance(1)

# callback method called on every key press
func _input(event):
	match _dialogue_state_machine:
		DialogueState.SCROLL_FIN:
			if event.is_action_pressed("dialogue_advance"):
				emit_signal("dialogue_next_sound")
				display_next_dialogue()
		
		DialogueState.OPTIONS:
			if(event.is_action_pressed("interact_select")):
				var next_dialogue = _current_options.dialogues[selected]
				if next_dialogue != null:
					_dialogue_queue.push_front(parse_single_line(next_dialogue))
				
				emit_signal("option_select")
				display_next_dialogue()
			
			if(event.is_action_pressed("ui_down")):
				selected += 1
				if(selected >= _current_options.option_text.size()):
					selected = 0
				emit_signal("option_change", selected)
				
			if(event.is_action_pressed("ui_up")):
				selected -= 1
				if(selected < 0):
					selected = _current_options.option_text.size() - 1
				emit_signal("option_change", selected)

# method used to initiate a dialogue sequence from a filename
# USE THIS ONE PUBLICLY, NOT THE queue_file_contents() METHOD!
func read_from_file_path(fileName : String) -> void:
	if _dialogue_state_machine == DialogueState.INACTIVE:
		if queue_file_contents(fileName): # in case of error
			begin_dialogue_execution()

# method used to initiate a dialogue sequence from a filename
# USE THIS ONE PUBLICLY, NOT THE queue_lines() METHOD!
func read_from_lines(lines : Array) -> void:
	if _dialogue_state_machine == DialogueState.INACTIVE:
		if queue_lines(lines): # in case of error
			begin_dialogue_execution()
	
func begin_dialogue_execution():
	# run any possible commands BEFORE opening the UI
	while(_dialogue_queue.size() > 0 and _dialogue_queue[0] is DialogueCommand):
		var command = _dialogue_queue[0]
		_dialogue_queue.remove(0)
		command.execute()
	
	# if that's all that's needed, don't even bother opening the UI
	# and return the gamestate to the normal running command
	if _dialogue_queue.size() == 0:
		_dialogue_state_machine = DialogueState.INACTIVE
		return
	
	# otherwise, open the UI
	if _dialogue_state_machine != DialogueState.WAIT:
		if state == DialogueUIState.OPEN:
			display_next_dialogue()
		else:
			open_dialogueUI()
	
func set_skippable(value : bool) -> void:
	skippable_dialogue = value
	
# levels from 1-4 correlate to decreases in amount of time it takes to type one char
func set_speed_level(value : int) -> void:
	char_typing_time = (5 - value) * 0.01
	if char_typing_time <= 0:
		push_error("speed level cannot be higher than 4")

# queues the file contents, but doesn't actually initiate the dialogue system
# returns false upon failure
func queue_file_contents(fileName) -> bool:
	# dialogue contents are cleared when loading new file
	if(!_dialogue_queue.empty()):
		_dialogue_queue.clear()
	
	var file : FileAccess = FileAccess.open(fileName, FileAccess.READ)
	
	# if file not found, do not proceed
	if !file.is_open():
		push_error("File \"" + fileName + "\" was not found.")
		return false
		
	var lines = file.get_as_text().strip_edges().split("\n", false)
	file.close()
	
	return queue_lines(lines)
	
# queues an array of strings as lines, but doesn't actually initiate the dialogue system
func queue_lines(lines):
	var i : int = 0
	while(i < lines.size()):
		# check if the line notates an option (multiple line)
		if(lines[i].begins_with("<option>")):
			i += 1
			var options_array : Array = []
			while( i < lines.size() && lines[i] != "}"):
				options_array.append(lines[i])
				i += 1
				
			if(i >= lines.size()):
				push_error("unable to find closing curly brace, aborting dialogue")
				_dialogue_queue.clear()
				
				return false
			
			var options : OptionSet = OptionSet.new(options_array)
			_dialogue_queue.append(options)
			
		# otherwise parse it normally
		else:
			_dialogue_queue.append(parse_single_line(lines[i]))
		
		i += 1
	
	return true
	
func parse_single_line(line) -> Object:
	line=line.strip_edges()
	if(line.begins_with(">>")):
		var command : DialogueCommand = DialogueCommand.new(line)
		return command
		
	# if the line is not an option set or command, then we assume it is a piece of dialogue
	else:
		var new_dialogue : Dialogue = Dialogue.new(line)
		return new_dialogue

# activates the dialogue system by changing the state
# also emits signals to be recieved by other scripts
# warning-ignore:shadowed_variable
func set_state(state : int) -> void:
	match(state):
		DialogueState.INACTIVE:
			close_dialogueUI()
			
		DialogueState.SCROLL_TXT:
			emit_signal("display_text")
			
			advance_released = false
		
		DialogueState.OPENING:
			open_dialogueUI()
			advance_released = false
		
		DialogueState.OPTIONS:
			emit_signal("display_options", _current_options)
			selected = 0
	
	_dialogue_state_machine = state

# dequeues next dialogue from the queue
func display_next_dialogue() -> void:
	
	# shift queue
	if(!_dialogue_queue.empty()):
		if(_dialogue_queue[0] is Dialogue):
				
			current_dialogue = _dialogue_queue[0]
			_dialogue_queue.remove(0)
			
			# order matters here: the dialogue text needs to be visible
			# to properly update "percent_visible" variable
			set_state(DialogueState.SCROLL_TXT)
			
			emit_signal("dialogue_advance", current_dialogue)
		elif(_dialogue_queue[0] is OptionSet):
			
			# dequeue
			_current_options = _dialogue_queue[0]
			_dialogue_queue.remove(0)
			set_state(DialogueState.OPTIONS)
		elif(_dialogue_queue[0] is DialogueCommand):
			# dequeue/execute command, and skip to next dialogue
			var command = _dialogue_queue[0]
			_dialogue_queue.remove(0)
			
			command.execute()
			
			if _dialogue_state_machine != DialogueState.WAIT:
				display_next_dialogue()
			
		else:
			push_error("Something that is not a Dialogue made its way into the dialogue queue")
			
	else:
		# this is when the queue is empty
		set_state(DialogueState.INACTIVE)

func instant_close() -> void:
	_dialogue_queue.clear()

func close_dialogueUI():
	if state == DialogueUIState.OPEN:
		state = DialogueUIState.CLOSED
		emit_signal("on_dialogue_close")
		$AnimationPlayer.play("DialogueAnimationClose")

func open_dialogueUI():
	if state == DialogueUIState.CLOSED:
		state = DialogueUIState.OPEN
		set_state(DialogueState.OPENING)
		visible = true
		$AnimationPlayer.play("DialogueAnimation")
		
		# emit the open signal so that everything is displaying the correct thing
		if _dialogue_queue.size() > 0:
			emit_signal("on_dialogue_open", _dialogue_queue[0])
			if _dialogue_queue[0] is OptionSet:
				emit_signal("display_options", _current_options)
			elif _dialogue_queue[0] is Dialogue:
				emit_signal("display_text")
		else:
			emit_signal("on_dialogue_open", null)

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	match state:
		DialogueUIState.OPEN:
			display_next_dialogue()
