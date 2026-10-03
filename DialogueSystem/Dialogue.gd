# "Dialogue.gd"
# This class is a object representation of a single line of dialogue. It
# stores the relevant information, such as deciding which image and
# name to use for the dialogue, along with where to put pauses.
extends Object
class_name Dialogue

# message to be stored
var message : String
# message with all the bbcode tags taken out
var actual_text : String
# texture resource of portrait to be loaded
var picture : Texture
# name of character
var name_tag : String
# Hashmap maps pause indexes to pause lengths (where and how long)
var pauseData : Dictionary

const samplePortrait1 = "res://sprites/portraits/Sample Portrait.png"
const samplePortrait2 = "res://sprites/portraits/Sample Portrait2.png"

# associates name from dialogue file to texture resource
const nameToTexture = {
	"player1" : samplePortrait1,
	"player2" : samplePortrait2
}

# constructor parses a single line from the dialogue resource file
func _init(full_line : String):
	message = parse_name_tag(full_line)
	parse_message()
	
	init_picture()

# returns the name of the character, if specified
# kind of rough, may need to add more error checking just in case
func parse_name_tag(raw_dialogue : String):
	# Attempt to find a nametag. These will return -1 if not found
	var start_index : int = raw_dialogue.find("<")
	var end_index : int = raw_dialogue.find(">")
	
	# make sure brackets are closed and the dialogue is valid
	if(check_unclosed_brackets(raw_dialogue, "[]")):
		push_error("Invalid dialogue format: unclosed square bracket (\"[\" or \"]\")")
		
	
	# if nametag not found, we are done
	if(start_index == -1 && end_index == -1):
		name_tag = ""
		return raw_dialogue.strip_edges()
	elif(start_index == -1 || end_index == -1):
		push_error("Invalid dialogue format: name tag is not closed")
	
	# if program reaches this point, a valid nametag was specified
	name_tag = raw_dialogue.substr(start_index + 1, end_index - start_index - 1)
	return raw_dialogue.substr(end_index + 1).strip_edges()

func parse_message():
	# copy the message into "actual_text" but without bbcodes
	# also remove any pause indicators, which are "\." these characters
	var is_bbCode = false
	
	var i = 0
	while i < message.length():
		if message[i] == "[":
			is_bbCode = true
		if !is_bbCode:
			actual_text += message[i]
			
			# if the current index is a pause indicator, remove it
			if i != message.length() - 1 && message[i] == "\\" && message[i + 1] == ".":
				actual_text += message[i + 1]
				message.erase(i, 2)
				i -= 1
		if message[i] == "]":
			is_bbCode = false
		i += 1
	
	# find pause indicators
	i = 0
	while i < actual_text.length() - 1:
		if actual_text[i] == "\\" && actual_text[i + 1] == ".":
			add_pause(i -1)
			actual_text.erase(i, 2)
			i -= 1
		i += 1
	
	

# Checks for brackets. Ignores escape sequence '\'
func check_unclosed_brackets(string : String, bracketType : String) -> bool:
	var openBracketCount = 0
	var closedBracketCount = 0
	
	for i in range(0, string.length()):
		if(string[i] == bracketType[0] && string[i - 1] != "\\"):
			openBracketCount += 1
		elif(string[i] == bracketType[1] && string[i - 1] != "\\"):
			closedBracketCount += 1
	
	return openBracketCount != closedBracketCount

# set the portrait texture, if specified
func init_picture():
	if(nameToTexture.has(name_tag)):
		var filepath = nameToTexture[name_tag]
		if filepath:
			picture = load(nameToTexture[name_tag])
		else:
			picture = null
	elif(name_tag != ""):
		push_error("\"" + name_tag + "\" does not have an associated picture file.")

func add_pause(index : int):
	if pauseData.has(index):
		pauseData[index] = pauseData[index] + 7
	else:
		pauseData[index] = 7
