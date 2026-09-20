extends Resource

class_name MHStoryInstance

export(Resource) var dialogue_collection
export var characters := { }

func _notification(what):
	if what == NOTIFICATION_POSTINITIALIZE:
		assert_valid()

func assert_valid():
	assert(dialogue_collection is MHStoryDialogue, "Invalid story instance -- dialogue_collection is not a MHStoryDialogue!")
	
	for chara in characters:
		assert(chara > 0, "Invalid story instance -- characters[%d] does not have a valid id! ([#] id too low)" % chara)
		assert(characters[chara] is MHStoryFighter, "Invalid story instance -- characters[%d] is not a MHStoryFighter!" % chara)
		assert(characters[chara].is_char_valid(), "Invalid story instance -- characters[%d] is not a valid character! (=%s)" % [chara, characters[chara].character_type])
		assert(characters[chara].is_char_valid(), "Invalid story instance -- characters[%d] does not have a valid team! (=%d)" % [chara, characters[chara].team])
