extends Node

var frames = {
	1: {},
	2: {},
	"finished": false,
	"emotes": {
		1: {},
		2: {},
	}
}

var playback = false setget set_playback

var resimulating = false
var play_full = false
var resim_tick = null
var replaying_ingame = false

func set_playback(p):
	playback = p

func init():
	frames = {
		1: {},
		2: {},
		"finished": false,
		"emotes": {
			1: {},
			2: {},
		}
	}
	
	var mh_data = {}
	frames["MultiHustle"] = mh_data
	for index in Global.current_game.players:
		frames[index] = {}
		frames["emotes"][index] = {}
		mh_data[index] = {}

func frame_ids_vanilla():
	return [1, 2]

func cut_replay(last_frame):
	for id in frame_ids():
		for frame in frames[id].keys():
			if frame > last_frame:
				frames[id].erase(frame)

func get_last_action_tick(id):
	var frame_numbers: Array = frames[id].keys()
	frame_numbers.sort()
	return frame_numbers[-1]

func get_last_action(id):
	var frame_numbers: Array = frames[id].keys()
	frame_numbers.sort()
	if frame_numbers:
		return frames[id][frame_numbers[-1]]
	return null

func emote(message, player_id, tick):
	if !playback:
		frames.emotes[player_id][tick] = message

func generate_replay_name():
	var time = Time.get_datetime_dict_from_system()
	var strings = [str(time.year), str(time.month), str(time.day), str(time.hour), str(time.minute)]
	var string = ""
	for s in strings:
		string += s
		string += "-"
	string += str(time.second)
	return string

func save_replay_mp(match_data, p1, p2):
	save_replay(match_data, generate_mp_replay_name(p1, p2), true)

func save_replay(match_data: Dictionary, file_name="", autosave=false):
	
	var team_data = {}
	
	for player in Network.game.players:
		team_data[player] = Network.get_team(player)

	match_data["teams"] = team_data

	# would rename to rich_display_names but that would break existing teams replays
	match_data["rich_display_names"] = Network.game.player_names_rich

	var char_names:Dictionary;
	if Network.multiplayer_active:
		char_names = Network.game.player_names
	else:
		char_names = Network.player_character_names
	match_data["selector_char_names"] = char_names
	if file_name == "":
		file_name = generate_replay_name() 
	file_name = Utils.filter_filename(file_name) 
	
	var data = match_data.duplicate(true)
	data["frames"] = frames
	data["version"] = Global.VERSION

	var dir = Directory.new()
	if !dir.dir_exists("user://replay"):
		dir.make_dir("user://replay")
	if !dir.dir_exists("user://replay/autosave"):
		dir.make_dir("user://replay/autosave")
	var file = File.new()
#	OS.shell_open(str("file://", "user://"))
	print(file_name)
	file.open("user://replay/"+("autosave/" if autosave else "")+file_name+".replay", File.WRITE)
	file.store_var(data, true)
	file.close()
	return file_name + ".replay"

func load_replays(autosave=true):
	var dir = Directory.new()
	var files = []
	var _directories = []
	if !dir.dir_exists("user://replay"):
		dir.make_dir("user://replay")
	if !dir.dir_exists("user://replay/autosave"):
		dir.make_dir("user://replay/autosave")
	dir.open("user://replay")
	dir.list_dir_begin(false, true)
#	print(dir.get_current_dir())
	Global.add_dir_contents(dir, files, _directories, autosave)
	var replay_paths = {}
	for path in files:
		var replay_file = File.new()
#		replay_file.open(path, File.READ)
#		var match_data = replay_file.get_var()
		var modified = replay_file.get_modified_time(path)
		var data = {
			"path": path,
			"modified": modified,
#			"version": match_data.version if match_data.has("version") else null
		}
		if ".replay" in path:
			replay_paths[path.get_file().get_basename()] = data
		replay_file.close()
	return replay_paths

func load_replay(path):
	var file = File.new()
	file.open(path, File.READ)
	var data: Dictionary = file.get_var()
	frames = data.frames
	var match_data = data.duplicate(true)
	match_data.erase("frames")
	return match_data

func force_ints(dict):
	for key in dict:
		if dict[key] is float:
			dict[key] = int(dict[key])
		if dict[key] is Dictionary:
			force_ints(dict[key])
	

func frame_ids():
	var ids = frame_ids_vanilla()
	for id in frames:
		if id is int and !ids.has(id):
			ids.append(id)
	return ids

func undo(cut = true):
	if resimulating:
		return 
	var last_frame = 0
	var last_id = 1
	for id in frame_ids():
		for frame in frames[id].keys():
			if frame > last_frame:
				last_frame = frame
				last_id = id
	
		if cut:
			frames[id].erase(last_frame)
	
	resimulating = true
	playback = true
	resim_tick = (last_frame - 2) if cut else - 1

func generate_mp_replay_name(p1: String, p2: String):
	var v_name = "MH_"
	for player in Network.game.player_names:
		var p_name = Network.game.player_names[player]
		v_name += p_name.substr(0, 3)
		v_name += "-vs-"
	return v_name.substr(0, len(v_name) - 4) + "_" + generate_replay_name()
