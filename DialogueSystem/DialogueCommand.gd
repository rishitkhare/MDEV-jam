# "DialogueCommand.gd"
# This class is a representation of a "command"
# These will be used in dialogue files to attach code systems
# to the dialogue

extends Object
class_name DialogueCommand

var opcode : String
var params = []

func _init(command : String):
	if(!command.begins_with(">>")):
		push_error("command needs to begin with \">>\"")
	
	# remove the command marker
	command.erase(0, 2)
	command = command.strip_edges()
	
	# using regex to parse through the rest of the command:
	var args = []
	
	var arg_regex : RegEx = RegEx.new()
# warning-ignore:return_value_discarded
	# RAW REGEX: [^\"\\ ]+|\"([^\\\"]|(\\\"))*\"
	
	# GDSCRIPT ESCAPED:
	var expr = "[^\\\"\\\\ ]+|\\\"([^\\\\\\\"]|(\\\\\\\"))*\\\""
	arg_regex.compile(expr)
	
	var whitespace_regex : RegEx = RegEx.new()
# warning-ignore:return_value_discarded
	whitespace_regex.compile("[ \n]*")
	
	var start_search = 0
	var avoid_infinite = 0
	
	while start_search < command.length() and avoid_infinite < 20:
		avoid_infinite += 1
		
		var result : RegExMatch = arg_regex.search(command, start_search)
		if result:
			if result.get_start() == start_search:
				var matched : String = result.get_string()
				matched = matched.replace("\\\"", "\"")
				if matched.begins_with("\""):
					# strip quotes from quoted args
					args.append(matched.substr(1, matched.length() - 2))
				else:
					args.append(matched)
				start_search = result.get_end()
			else:
				push_error("failed parse")
				break
		else:
			push_error("failed parse")
			break
				
		
		# match to whitespace (and ignore it) if it exists
		result = whitespace_regex.search(command, start_search)
		if result and result.get_start() == start_search:
			start_search = result.get_end()
	
	if avoid_infinite == 100:
		push_error("parse failed on:\n%s" % command)
	
	opcode = args[0]
	params = args.slice(1,-1)
	
	
func execute():
	match(opcode):
		"print":
			# print something to the console in the dialogue system (used for testing only)
			if(params.size() == 1):
				print(params[0])
			else:
				push_warning("(dialogue command) print had incorrect amount of arguments")
			
		_:
			push_error("command not found: " + opcode)
