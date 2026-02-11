extends Button


onready var RankedGlobal = get_tree().get_root().get_node("RankedGlobal")
onready var ranks = $"%ranks"
onready var httpreq = $HTTPRequest
onready var ranktext = $"%ranktext"


func _on_HTTPRequest_request_completed( result, response_code, headers, body ):
	var json = JSON.parse(body.get_string_from_utf8())
	ranktext.bbcode_text = ""
	var position = 1
	for player in json.result:
		var color = Color.greenyellow.linear_interpolate(Color.crimson, player.rating / 2500).to_html(false)
		ranktext.bbcode_text = ranktext.bbcode_text + player.steamName + "\n[color=#" + color + "] #" + str(position) + " RATING: " + str(player.rating) + "[/color] \n\n"
		position += 1


func _on_ArenaButton_pressed() -> void:
	RankedGlobal = pressed


func _on_InfoButton_pressed() -> void:
	ranks.visible = not ranks.visible
	httpreq.request("http://150.136.44.240:2221/leaderboard")
