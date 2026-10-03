# "OptionSet.gd"
# This class is a representation of a single set of option choices.
# Each set of choices can have up to four options. It also contains
# information on what to say when each choice is selected.

extends Object
class_name OptionSet

var option_text = []
var dialogues = []

func _init(raw_lines : Array):
	if raw_lines.size() > 4 :
		push_error("more than 4 option choices, please reduce")
	
	for line in raw_lines:
		var split : Array = line.split(":", true,  1)
		
		option_text.append(split[0].strip_edges())
		
		# after-dialogue may not exist for this option
		if split.size() < 2 :
			dialogues.append(null)
		else:
			dialogues.append(split[1].strip_edges())
