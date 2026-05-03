extends Control

var buttons = []
var moving_sprite_start

var character_color = Color.white
var outline_color = Color.black
var extra_color_1 = null
var extra_color_2 = null

var free_colors = []
var custom_particles = []

var selected_hitspark = "bash"

var workshop_preview_image: Image = null

var hitspark_scene = null

const AURA_SLOT_COUNT = 2
var current_aura_slot = 0
var aura_show = [false, false]
var aura_settings_cache = [null, null]
var aura_slot_dropdown: OptionButton = null
var copy_aura_button: Button = null
var paste_aura_button: Button = null
var aura_clipboard = null
var loading_aura_slot = false

# limb_data dict from the currently-previewed character (for attaching auras
# to limbs on the portrait sprites in the customization preview).
var current_character_limb_data := {}

# Attribution: creator + last-N modifiers (capped by MAX_STYLE_MODIFIERS).
# Filled from the loaded .style
# dict; updated on save when the user has actually made changes. The *_id
# arrays are parallel to the username arrays — same index, same person —
# and hold steam_ids as strings (or "" for non-steam users / unknown).
# Used so a re-save by the latest person in the chain can bypass the
# allow_others_save gate even when usernames clash.
var loaded_style_creator := ""
var loaded_style_creator_id := ""
var loaded_style_modifiers := []
var loaded_style_modifier_ids := []
var style_modified_since_load := false
const MAX_STYLE_MODIFIERS := 2000

func get_style_data():
	save_current_aura_slot()
	var auras := []
	for i in range(AURA_SLOT_COUNT):
		auras.append({"show": aura_show[i], "settings": aura_settings_cache[i]})
	var data = {
		"style_name": Utils.filter_filename($"%StyleName".text.strip_edges()) if $"%StyleName".text.strip_edges() else "untitled" + str(int(Time.get_unix_time_from_system())),
		"character_color": character_color,
		"extra_color_1": extra_color_1,
		"extra_color_2": extra_color_2,
		"use_outline": $"%ShowOutline".pressed,
		"outline_color": outline_color if $"%ShowOutline".pressed else null,
		"hitspark": "bash" if selected_hitspark == null else selected_hitspark,
		# Old-format mirrors of the first two array entries — kept so older
		# game versions can still read newly-saved styles.
		"show_aura": aura_show[0],
		"aura_settings": aura_settings_cache[0],
		"show_aura_2": aura_show[1],
		"aura_settings_2": aura_settings_cache[1],
		"auras": auras,
		"ivy_effect": false,
		"creator": loaded_style_creator,
		"creator_id": loaded_style_creator_id,
		"modifiers": loaded_style_modifiers.duplicate(),
		"modifier_ids": loaded_style_modifier_ids.duplicate(),
		# Empty dict reserved for mod-specific data attached to the style.
		"mod_data": {},
	}
	if Global.STYLE_SAVE_FEATURE_ENABLED:
		data["allow_others_save"] = $"%AllowSaveButton".pressed
	return data

func save_current_aura_slot():
	if loading_aura_slot:
		return
	aura_show[current_aura_slot] = $"%ShowAura".pressed
	aura_settings_cache[current_aura_slot] = $"%TrailSettings".get_settings()

func switch_aura_slot(slot):
	save_current_aura_slot()
	current_aura_slot = posmod(slot, AURA_SLOT_COUNT)
	loading_aura_slot = true
	$"%ShowAura".pressed = aura_show[current_aura_slot]
	if aura_settings_cache[current_aura_slot]:
		$"%TrailSettings".load_settings(aura_settings_cache[current_aura_slot])
	else:
		$"%TrailSettings".load_settings(CustomTrailParticle.get_default())
	loading_aura_slot = false
	if aura_slot_dropdown:
		aura_slot_dropdown.select(current_aura_slot)
	create_all_auras()

func init():
	for name in Global.name_paths:
		var button = preload("res://ui/CSS/CharacterButton.tscn").instance()
		button.character_scene = load(Global.name_paths[name])
		$"%CharacterButtonContainer".add_child(button)
		buttons.append(button)
		button.connect("pressed", self, "_on_character_button_pressed", [button])
		button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
#		var character = button.character_scene.instance()
		button.text = name
	buttons[0].pressed = true
	moving_sprite_start = $"%MovingSprite".position
	$"%Character".connect("color_changed", self, "_on_character_color_changed")
	$"%Extra1".connect("color_changed", self, "_on_extra_color_1_changed")
	$"%Extra2".connect("color_changed", self, "_on_extra_color_2_changed")
	$"%Outline".connect("color_changed", self, "_on_outline_color_changed")
	$"%ShowOutline".connect("toggled", self, "_on_show_outline_toggled")
	$"%BackButton".connect("pressed", self, "_on_back_button_pressed")
	for i in range(Custom.simple_colors.size()):
		var simple_color_button = preload("res://ui/CustomizationScreen/SimpleColorButton.tscn").instance()
		var color = Custom.simple_colors[i]
		var outline = Custom.simple_outlines[i]
		simple_color_button.init(color, outline)
		$"%SimpleColorButtonContainer".add_child(simple_color_button)
		simple_color_button.connect("pressed", self, "_on_character_color_changed", [color])
		simple_color_button.connect("pressed", self, "_on_outline_color_changed", [outline])
	$"%ResetColorButton".connect("pressed", self, "_on_reset_color_pressed")
#	select_hitspark("default")
	for hitspark in Custom.hitsparks:
		var button = Button.new()
		button.text = hitspark
		button.connect("pressed", self, "select_hitspark", [hitspark])
		button.rect_min_size = Vector2(50, 20)
		$"%HitsparkButtonContainer".add_child(button)
	$"%TrailSettings".connect("settings_changed", self, "_on_trail_settings_changed")
	$"%ShowAura".connect("pressed", self, "_on_show_aura_pressed")
	aura_slot_dropdown = OptionButton.new()
	for i in range(AURA_SLOT_COUNT):
		aura_slot_dropdown.add_item("Aura %d" % (i + 1))
	aura_slot_dropdown.select(0)
	aura_slot_dropdown.connect("item_selected", self, "_on_aura_slot_dropdown_selected")
	$"%ShowAura".get_parent().add_child(aura_slot_dropdown)
	# Copy/paste on a separate row right under the slot dropdown.
	var aura_row_parent = $"%ShowAura".get_parent().get_parent()
	var copy_paste_row = HBoxContainer.new()
	aura_row_parent.add_child(copy_paste_row)
	aura_row_parent.move_child(copy_paste_row, $"%ShowAura".get_parent().get_index() + 1)
	copy_aura_button = Button.new()
	copy_aura_button.text = "copy aura"
	copy_aura_button.hint_tooltip = "Copy this aura's settings to the clipboard."
	copy_aura_button.connect("pressed", self, "_on_copy_aura_pressed")
	copy_paste_row.add_child(copy_aura_button)
	paste_aura_button = Button.new()
	paste_aura_button.text = "paste aura"
	paste_aura_button.hint_tooltip = "Paste the clipboard's aura into this slot (overwrites)."
	paste_aura_button.disabled = true
	paste_aura_button.connect("pressed", self, "_on_paste_aura_pressed")
	copy_paste_row.add_child(paste_aura_button)
	$"%SaveButton".connect("pressed", self, "save_style")
	$"%LoadStyleButton".connect("style_selected", self, "load_style")
	$"%AllowSaveButton".connect("toggled", self, "_on_allow_save_toggled")
	if !Global.STYLE_SAVE_FEATURE_ENABLED:
		$"%AllowSaveButton".hide()
	else:
		$"%AllowSaveButton".set_pressed_no_signal(Global.allow_save_default)
	if !SteamHustle.WORKSHOP_ENABLED:
		$"%WorkshopButton".disabled = true
	_on_character_button_pressed(buttons[0])
	_on_reset_color_pressed()
	update_warning()

func show():
	$"%LoadStyleButton".update_styles()
	update_warning()
	.show()
	_on_reset_color_pressed()
	
func save_style(clear_text = false):
	# Apply attribution before snapshotting style data: set creator on a
	# fresh style and append the current user as a modifier when there have
	# been actual edits since loading. Capped at MAX_STYLE_MODIFIERS, with
	# a consecutive-duplicate skip so saving twice in a row doesn't double up.
	var current_user = _current_username()
	var current_id = _current_steam_id()
	if loaded_style_creator == "" and current_user != "":
		loaded_style_creator = current_user
		loaded_style_creator_id = current_id
	if style_modified_since_load and current_user != "":
		# Don't list the creator as a modifier, and don't list any modifier
		# more than once. Strict dedup:
		#   - both sides have a steam_id → match by id (rename-safe)
		#   - both sides lack an id → match by username (legacy / non-steam)
		#   - mismatched id presence → treat as different people (a steam
		#     user can share a name with a legacy entry coincidentally)
		var already_in_chain = false
		if current_id != "" and loaded_style_creator_id != "":
			if current_id == loaded_style_creator_id:
				already_in_chain = true
		elif current_id == "" and loaded_style_creator_id == "":
			if current_user == loaded_style_creator:
				already_in_chain = true
		if !already_in_chain:
			for i in range(loaded_style_modifiers.size()):
				var mid = loaded_style_modifier_ids[i]
				if current_id != "" and mid != "":
					if current_id == mid:
						already_in_chain = true
						break
				elif current_id == "" and mid == "":
					if loaded_style_modifiers[i] == current_user:
						already_in_chain = true
						break
		if !already_in_chain:
			loaded_style_modifiers.append(current_user)
			loaded_style_modifier_ids.append(current_id)
		while loaded_style_modifiers.size() > MAX_STYLE_MODIFIERS:
			loaded_style_modifiers.pop_front()
			if !loaded_style_modifier_ids.empty():
				loaded_style_modifier_ids.pop_front()
	style_modified_since_load = false
	var data = get_style_data()
	Custom.save_style(data)
	_refresh_style_credits_button()
	SteamHustle.unlock_achievement("ACH_STYLISH")
	if data.character_color == Color("0b0c0f"):
		if !data.use_outline or data.outline_color == Color("0b0c0f"):
			SteamHustle.unlock_achievement("ACH_SNEAKY")
	$"%LoadStyleButton".update_styles()
	if clear_text:
		$"%StyleName".clear()
	_set_label_with_ellipsis($"%SavedLabel", "saved as " + data.style_name + ".style")
	$"%SavedLabel".show()

func update_warning():
#	if !Global.full_version():
#		$"%DLCWarning".visible = Custom.requires_dlc(get_style_data())
	pass

func load_style(style):
	if style:
		# Reset attribution caches from the loaded style. Backward compat:
		# legacy styles without the keys default to empty creator and an
		# empty modifiers list — the next save will fill them in.
		loaded_style_creator = style.get("creator", "") if style is Dictionary else ""
		loaded_style_creator_id = ""
		loaded_style_modifiers = []
		loaded_style_modifier_ids = []
		if style is Dictionary:
			loaded_style_creator_id = str(style.get("creator_id", ""))
			if style.has("modifiers") and style["modifiers"] is Array:
				for n in style["modifiers"]:
					if n is String:
						loaded_style_modifiers.append(n)
			if style.has("modifier_ids") and style["modifier_ids"] is Array:
				for id_val in style["modifier_ids"]:
					loaded_style_modifier_ids.append(str(id_val))
		# Pad the id array with "" so it stays aligned with the username
		# array — older styles only have usernames.
		while loaded_style_modifier_ids.size() < loaded_style_modifiers.size():
			loaded_style_modifier_ids.append("")
		while loaded_style_modifier_ids.size() > loaded_style_modifiers.size():
			loaded_style_modifier_ids.pop_back()
		# If we recognise our own steam_id anywhere in the chain but the saved
		# username is stale, refresh those entries to the current username.
		# Next save persists the rename.
		var my_id = _current_steam_id()
		var my_user = _current_username()
		if my_id != "" and my_user != "":
			if loaded_style_creator_id == my_id and loaded_style_creator != my_user:
				loaded_style_creator = my_user
			for i in range(loaded_style_modifier_ids.size()):
				if loaded_style_modifier_ids[i] == my_id and loaded_style_modifiers[i] != my_user:
					loaded_style_modifiers[i] = my_user
		# Legacy styles without this field are treated as allowing save.
		# Skipped entirely while the feature is disabled — the button is
		# hidden anyway and the field stops round-tripping through saves.
		if Global.STYLE_SAVE_FEATURE_ENABLED:
			var allow_save = true
			if style is Dictionary:
				allow_save = style.get("allow_others_save", true)
			$"%AllowSaveButton".set_pressed_no_signal(allow_save)
		style_modified_since_load = false
		_refresh_style_credits_button()
		loading_aura_slot = true
		# Reset all slots, then fill from new "auras" array if present, else
		# from the old aura_settings/aura_settings_2 fields.
		for i in range(AURA_SLOT_COUNT):
			aura_show[i] = false
			aura_settings_cache[i] = null
		if style.has("auras") and style["auras"] is Array:
			var arr = style["auras"]
			for i in range(min(arr.size(), AURA_SLOT_COUNT)):
				var entry = arr[i]
				if entry is Dictionary:
					aura_show[i] = entry.get("show", false)
					aura_settings_cache[i] = entry.get("settings")
		else:
			aura_show[0] = style.get("show_aura", false)
			aura_settings_cache[0] = style.get("aura_settings")
			aura_show[1] = style.get("show_aura_2", false)
			aura_settings_cache[1] = style.get("aura_settings_2")
		current_aura_slot = 0
		if aura_slot_dropdown:
			aura_slot_dropdown.select(0)
		$"%ShowAura".pressed = aura_show[0]
		if aura_settings_cache[0]:
			$"%TrailSettings".load_settings(aura_settings_cache[0])
		loading_aura_slot = false
		$"%StyleName".text = style.style_name
		$"%ShowOutline".pressed = style.use_outline
		if style.use_outline:
			$"%Outline".set_color(style.outline_color)
		if style.get("extra_color_1"):
			$"%Extra1".set_color(style.extra_color_1)
		if style.get("extra_color_2"):
			$"%Extra2".set_color(style.extra_color_2)
		call_deferred("create_all_auras")
		if style.character_color != null:
			$"%Character".set_color(style.character_color)
		for child in $"%HitsparkButtonContainer".get_children():
			if child.text == style.hitspark.strip_edges():
				child.pressed = true
				select_hitspark(style.hitspark)
	$"%WorkshopButton".disabled = false

func select_hitspark(hitspark_name):
	if selected_hitspark != hitspark_name:
		_mark_style_modified()
	selected_hitspark = hitspark_name
	spawn_hitspark()
	update_warning()

func spawn_hitspark():
	if Custom.hitsparks.has(selected_hitspark):
		if is_instance_valid(hitspark_scene):
			hitspark_scene.queue_free()
		hitspark_scene = load(Custom.hitsparks[selected_hitspark]).instance()

		$"%HitsparkDisplay".add_child(hitspark_scene)

func _physics_process(delta):
	if !visible:
		return
	if !is_instance_valid(hitspark_scene):
		spawn_hitspark()
	else:
		hitspark_scene.tick()
#	for particle in custom_particles:
#		if is_instance_valid(particle):
#			particle.tick()

func _on_trail_settings_changed(settings):
	if !loading_aura_slot:
		_mark_style_modified()
	save_current_aura_slot()
	call_deferred("create_all_auras")
	update_warning()

func _on_show_aura_pressed():
	if !loading_aura_slot:
		_mark_style_modified()
	save_current_aura_slot()
	call_deferred("create_all_auras")
	update_warning()

func _on_aura_slot_dropdown_selected(slot):
	switch_aura_slot(slot)

func _on_copy_aura_pressed():
	save_current_aura_slot()
	if aura_settings_cache[current_aura_slot] is Dictionary:
		aura_clipboard = aura_settings_cache[current_aura_slot].duplicate(true)
		paste_aura_button.disabled = false

func _on_paste_aura_pressed():
	if !(aura_clipboard is Dictionary):
		return
	loading_aura_slot = true
	aura_settings_cache[current_aura_slot] = aura_clipboard.duplicate(true)
	aura_show[current_aura_slot] = true
	$"%ShowAura".pressed = true
	$"%TrailSettings".load_settings(aura_settings_cache[current_aura_slot])
	loading_aura_slot = false
	create_all_auras()

func create_all_auras():
	for particle in custom_particles:
		if is_instance_valid(particle):
			particle.queue_free()
	custom_particles.clear()
	var entries := []
	for slot in range(AURA_SLOT_COUNT):
		entries.append({"show": aura_show[slot], "settings": aura_settings_cache[slot]})
	for expanded in Custom.expand_aura_entries(entries):
		var settings = expanded["settings"]
		var attach_limb = expanded["attach_limb"]
		var pair_index = expanded["pair_index"]
		var resolved_limb = Custom.resolve_attach_limb(expanded)
		var position_only = settings.get("attach_position_only", true)
		var mirror_pair = settings.get("attach_pair_mirror", true)
		for node in [$"%MovingSprite", $"%StaticSprite"]:
			var entry = _preview_limb_entry(node, resolved_limb) if attach_limb != "" else null
			# Skip entirely when an attached aura's limb has no data on this
			# preview sprite, so the aura doesn't appear at the wrong spot.
			if attach_limb != "" and entry == null:
				continue
			var particle = preload("res://fx/CustomTrailParticle.tscn").instance()
			node.add_child(particle)
			custom_particles.append(particle)
			particle.load_settings(settings)
			if attach_limb != "":
				particle.position = _preview_aura_pos_from_entry(node, entry)
				particle.attached_to_limb = true
				if position_only:
					particle.attached_rotation = 0.0
					particle.attached_limb_flipped = false
				else:
					particle.attached_rotation = _preview_aura_rotation_from_entry(entry)
					var flipped = entry.get("flipped", false)
					if pair_index == 1 and mirror_pair:
						flipped = !flipped
					particle.attached_limb_flipped = flipped
				particle.facing = 1
			else:
				particle.position = Vector2()

# Returns the limb entry for the given sprite, or null if there's no usable
# data on this sprite (no entry at all, or marked absent).
func _preview_limb_entry(sprite_node: Sprite, limb_name: String):
	if limb_name == "" or current_character_limb_data.empty():
		return null
	if !current_character_limb_data.has(limb_name):
		return null
	var by_tex = current_character_limb_data[limb_name]
	if !by_tex.has(sprite_node.texture):
		return null
	var entry = by_tex[sprite_node.texture]
	if entry is Dictionary and entry.get("absent", false):
		return null
	return entry

func _preview_aura_pos_from_entry(sprite_node: Sprite, entry) -> Vector2:
	var local = Vector2(entry.x, entry.y)
	if sprite_node.centered:
		local -= sprite_node.texture.get_size() / 2
	if "offset" in sprite_node:
		local += sprite_node.offset
	return local

func _preview_aura_rotation_from_entry(entry) -> float:
	var dir = Vector2(entry.dir_x, entry.dir_y)
	if dir.length_squared() < 0.0001:
		return 0.0
	return dir.angle()

func _on_back_button_pressed():
	Global.reload()

func _on_reset_color_pressed():
	character_color = null
	extra_color_1 = null
	extra_color_2 = null
	$"%StaticSprite".get_material().set_shader_param("color", Color.white)
	$"%StaticSprite".get_material().set_shader_param("extra_color_1", Color.white)
	$"%StaticSprite".get_material().set_shader_param("extra_color_2", Color.white)
	_on_show_outline_toggled(false)
	update_warning()

func _on_character_color_changed(color):
	$"%StaticSprite".get_material().set_shader_param("color", color)
#	$"%MovingSprite".get_material().set_shader_param("color", color)
	if character_color != color:
		_mark_style_modified()
	character_color = color
	update_warning()

func _on_extra_color_1_changed(color):
	$"%StaticSprite".get_material().set_shader_param("extra_color_1", color)
	if extra_color_1 != color:
		_mark_style_modified()
	extra_color_1 = color
	update_warning()

func _on_extra_color_2_changed(color):
	$"%StaticSprite".get_material().set_shader_param("extra_color_2", color)
	if extra_color_2 != color:
		_mark_style_modified()
	extra_color_2 = color
	update_warning()

func _on_outline_color_changed(color):
	$"%ShowOutline".set_pressed_no_signal(true)
	$"%StaticSprite".get_material().set_shader_param("outline_color", color)
	$"%StaticSprite".get_material().set_shader_param("use_outline", true)
#	$"%MovingSprite".get_material().set_shader_param("color", color)
	if outline_color != color:
		_mark_style_modified()
	outline_color = color
	update_warning()

func _on_show_outline_toggled(on):
	_mark_style_modified()
	$"%StaticSprite".get_material().set_shader_param("use_outline", on)
	$"%ShowOutline".set_pressed_no_signal(on)
	update_warning()

func _on_allow_save_toggled(pressed):
	Global.allow_save_default = pressed
	Global.save_options()
	_mark_style_modified()

func _on_character_button_pressed(button):
	for button in buttons:
		button.set_pressed_no_signal(false)
	button.set_pressed_no_signal(true)
	var character: Fighter = button.character_scene.instance()
	add_child(character)
	var character_texture = character.sprite.frames.get_frame("Wait", 0)
	var character_texture2 = character.character_portrait2
	$"%StaticSprite".get_material().set_shader_param("use_extra_color_1", character.use_extra_color_1)
	$"%StaticSprite".get_material().set_shader_param("use_extra_color_2", character.use_extra_color_2)
	$"%StaticSprite".get_material().set_shader_param("extra_replace_color_1", character.extra_color_1)
	$"%StaticSprite".get_material().set_shader_param("extra_replace_color_2", character.extra_color_2)
	$"%StaticSprite".texture = character_texture
	$"%MovingSprite".texture = character_texture2 if character_texture2 != null else character_texture
	current_character_limb_data = character.get_limb_data() if character.has_method("get_limb_data") else {}
	character.free()
	create_all_auras()

func _process(delta):
	if visible:
		$"%MovingSprite".position = moving_sprite_start + Vector2(Utils.wave(-50, 50, 2.0), 0)


func _on_StyleName_text_entered(new_text):
	save_style(false)
	pass # Replace with function body.

func _on_OpenFolderButton_pressed():
	OS.shell_open(ProjectSettings.globalize_path("user://custom"))
	pass # Replace with function body.

func _on_DLCWarning_meta_clicked(meta):
	Steam.activateGameOverlayToStore(SteamHustle.APP_ID)
	pass # Replace with function body.

func _on_WorkshopButton_pressed():
	# Publishing to workshop implies sharing — force the toggle on so both
	# the local save and the uploaded copy carry allow_others_save = true.
	# Use no_signal so Global.allow_save_default isn't overwritten.
	if Global.STYLE_SAVE_FEATURE_ENABLED:
		$"%AllowSaveButton".set_pressed_no_signal(true)
	save_style(false)
	var item = UGCItem.new()
	item.connect("item_created", self, "_on_item_created")
	item.connect("item_updated", self, "_on_item_updated")
	$"%WorkshopButton".disabled = true
	var image: Image = get_viewport().get_texture().get_data()
	image.flip_y()
	var rect = Rect2(Vector2(357, 119), Vector2(70, 70))
#	var rect = Rect2(Vector2(328, 117), Vector2(124, 70))
	image = image.get_rect(rect)
	image.resize(image.get_width() * 6, image.get_height() * 6, 0)
	workshop_preview_image = image

func _on_item_created(p_file_id):
	var data = get_style_data()
	data["workshop_id"] = p_file_id
	
	var folder_path = Custom.save_style_workshop(data)
	
	var item = UGCItem.new(p_file_id)
	item.set_tags(["Style"])
	item.set_title($"%StyleName".text)
	item.set_content(ProjectSettings.globalize_path(folder_path))
	item.set_visibility(0)
#	print(ProjectSettings.globalize_path(folder_path) + "/preview.png")
	workshop_preview_image.save_png(ProjectSettings.globalize_path(folder_path) + "/preview.png")
#	item.set_preview()
	item.set_preview(ProjectSettings.globalize_path(folder_path) + "/preview.png")
	item.update("new style")

func _on_item_updated(url):
	$"%WorkshopUpdatedLabel".clear()
	$"%WorkshopUpdatedLabel".append_bbcode("[u][url=%s]style uploaded to workshop[/url]" % url)
	$"%WorkshopUpdatedLabel".show()

func _on_StyleName_text_changed(new_text: String):
	$"%WorkshopButton".disabled = new_text.strip_edges() == ""
	$"%WorkshopUpdatedLabel".hide()


func _on_WorkshopUpdatedLabel_meta_clicked(meta):
	OS.shell_open(meta)
	pass # Replace with function body.


func _on_WorkshopButton2_pressed():
#	OS.shell_open("https://steamcommunity.com/app/2212330/workshop/")
	Steam.activateGameOverlayToWebPage("https://steamcommunity.com/app/2212330/workshop/")
	pass # Replace with function body.

# ---- Style attribution ----

# Sets a Label's text, truncating with "..." if it would overflow the
# label's rect width. Godot 3's Label has no native ellipsis behavior.
func _set_label_with_ellipsis(label: Label, text: String):
	label.clip_text = true
	var font = label.get_font("font")
	var available = label.rect_size.x
	if font == null or available <= 0 or font.get_string_size(text).x <= available:
		label.text = text
		return
	var ellipsis = "..."
	var ellipsis_w = font.get_string_size(ellipsis).x
	var truncated = text
	while truncated.length() > 0 and font.get_string_size(truncated).x + ellipsis_w > available:
		truncated = truncated.substr(0, truncated.length() - 1)
	label.text = truncated + ellipsis

func _current_username() -> String:
	if SteamHustle.STARTED and SteamHustle.STEAM_ID:
		var steam_name = Steam.getFriendPersonaName(SteamHustle.STEAM_ID)
		if steam_name is String and steam_name != "":
			return steam_name
	var pd = Global.get_player_data()
	if pd is Dictionary:
		var u = pd.get("username", "")
		if u is String:
			return u
	return ""

# The local user's steam_id as a string, or "" if the build isn't running
# under steam (or the id hasn't been resolved yet).
func _current_steam_id() -> String:
	var sid = SteamHustle.STEAM_ID
	if sid != null and typeof(sid) == TYPE_INT and sid > 0:
		return str(sid)
	return ""

func _mark_style_modified(_arg=null, _arg2=null):
	style_modified_since_load = true

# Show/hide the "style credits" button based on whether the loaded style has
# any attribution data. Called whenever load_style or save_style changes the
# cached creator/modifiers.
func _refresh_style_credits_button():
	if !has_node("%StyleCreditsButton"):
		return
	var has_credits = loaded_style_creator != "" or !loaded_style_modifiers.empty()
	$"%StyleCreditsButton".visible = has_credits

func _on_StyleCreditsButton_pressed():
	if !has_node("%StyleCreditsPanel"):
		return
	_populate_style_credits()
	$"%StyleCreditsPanel".show()

func _on_StyleCreditsCloseButton_pressed():
	if has_node("%StyleCreditsPanel"):
		$"%StyleCreditsPanel".hide()

func _populate_style_credits():
	if !has_node("%StyleCreditsList"):
		return
	var list = $"%StyleCreditsList"
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	var style_name = ""
	if has_node("%StyleName"):
		style_name = $"%StyleName".text.strip_edges()
	if style_name != "":
		var name_label = Label.new()
		name_label.text = style_name
		name_label.align = Label.ALIGN_CENTER
		list.add_child(name_label)
		var spacer = Control.new()
		spacer.rect_min_size = Vector2(0, 4)
		list.add_child(spacer)
	if loaded_style_creator != "":
		var creator_header = Label.new()
		creator_header.text = "created by"
		creator_header.modulate = Color(1, 1, 1, 0.6)
		creator_header.align = Label.ALIGN_CENTER
		list.add_child(creator_header)
		var creator_label = Label.new()
		creator_label.text = loaded_style_creator
		creator_label.align = Label.ALIGN_CENTER
		list.add_child(creator_label)
	if !loaded_style_modifiers.empty():
		var mods_header = Label.new()
		mods_header.text = "modified by"
		mods_header.modulate = Color(1, 1, 1, 0.6)
		mods_header.align = Label.ALIGN_CENTER
		list.add_child(mods_header)
		# Render most-recent first.
		for i in range(loaded_style_modifiers.size() - 1, -1, -1):
			var mod_label = Label.new()
			mod_label.text = loaded_style_modifiers[i]
			mod_label.align = Label.ALIGN_CENTER
			list.add_child(mod_label)
