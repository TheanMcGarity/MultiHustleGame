extends ConfirmationDialog

var song_mode := -1
func show_popup(mode):
	song_mode = mode
	popup()

func _ready():
	connect("confirmed", self, "open_files")
	
	$"%ReplaySongFileDialogue".connect("file_selected", self, "on_got_file")
	
	$"%ReplaySongFileDialogue".get_cancel().connect("pressed", self, "cancel")
	get_cancel().connect("pressed", self, "cancel")
	pass
func cancel():
	Global.replay_song_mode = -1
func open_files():
	$"%ReplaySongFileDialogue".popup()

func get_path():
	if (song_mode == 1):
		return Global.REPLAY_SONG_PATH
	return Global.ADV_REPLAY_SONG_PATH % Global.next_replay_song_id

func on_got_file(file):
	var path = get_path()
	var f = File.new()
	var f2 = File.new()
	f.open(file, File.READ)
	f2.open(path+".tmp", File.WRITE)
	f2.store_buffer(f.get_buffer(f.get_len()))
	f.close()
	f2.close()
	
	var dir = Directory.new()
	dir.rename(path+".tmp", path)
	
	#Global.replay_song_mode = song_mode
	if (song_mode != 2):
		return
	Global.next_replay_song_id += 1
	var song_listing = get_tree().get_root().get_node("Main/%AdvReplaySongTemplate").duplicate()
	get_tree().get_root().get_node("Main/%ReplaySongList").add_child(song_listing)
	var song_name = file.split('/')[-1]
	if (len(song_name) >= 35):
		song_name = song_name.split(".")[0].substr(0, 34) + "[...].mp3"
	song_listing.get_node("Name").text = song_name
	song_listing.show()
	Global.replay_songs[file] = path
	
