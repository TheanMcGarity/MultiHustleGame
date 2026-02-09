extends Node2D
#tool #not useful as a tool script anymore since it requires a camera :/
# class names are useless in yomi modding but this isn't exclusive to that so
class_name TilingAnimatedSprite

signal animation_finished()
signal frame_changed()

var texture:Texture = null


export var frames:SpriteFrames
export var animation:String = "default" setget set_animation,get_animation
export var frame:int = 0 setget set_frame
export var centered:bool = true setget set_centered,is_centered

export var offset:Vector2 = Vector2.ZERO setget set_offset, get_offset

export var h_tile = false setget set_h_tile
export var v_tile = false setget set_v_tile

export var mirror = false

var camera = null

var anim_frame_count = 0


func set_sprite_frames(value:SpriteFrames):
	var animations = value.get_animation_names()
	var first_animation = animations[0]
	frames = value
	set_animation(first_animation)

func set_animation(value:String):
	assert(frames.has_animation(value))
	animation = value
	_update_anim_data()
	frame = 0
	emit_signal("frame_changed")
func get_animation():
	return animation

func set_centered(value:bool):
	centered = value
	update()
func is_centered():
	return centered
func set_h_tile(value:bool):
	h_tile = value
	update()
func set_v_tile(value:bool):
	v_tile = value
	update()

func _process(delta):
	# force redraws so camera follow works properly lol
	update()

func _draw():
	if texture == null || camera == null:
		return
	var tex_width = texture.get_width()
	var tex_height = texture.get_height()
	
	var view_rect = get_viewport().get_visible_rect()
	
	var center = Vector2(tex_width/2*float(centered), tex_height/2*float(centered))+offset
	var draw_rect = Rect2( -global_position*camera.zoom, view_rect.size*camera.zoom )
	var tex_rect = Rect2( -global_position*camera.zoom+center, view_rect.size*camera.zoom )
	
	if not h_tile:
		draw_rect.position.x = 0-center.x
		draw_rect.size.x = tex_width
		tex_rect.position.x = 0
		tex_rect.size.x = tex_width
	
	if not v_tile:
		draw_rect.position.y = 0-center.y
		draw_rect.size.y = tex_height
		tex_rect.position.y = 0
		tex_rect.size.y = tex_height
	
	draw_texture_rect_region(texture, draw_rect, tex_rect)

func _enter_tree():
	
	connect("frame_changed", self, "update")

func _ready():
	if frames == null:
		return
	var animations = frames.get_animation_names()
	var first_animation = animations[0]
	set_animation(first_animation)
	set_frame(frame)
	_update_anim_data()

func _update_anim_data():
	anim_frame_count = frames.get_frame_count(animation)

func set_frame(value):
	if frame == value and texture != null:
		return
	frame = clamp(value, 0, anim_frame_count-1)
	_set_texture(frames.get_frame(animation, frame))
	update()
	emit_signal("frame_changed")

func _set_texture(tex):
	if not is_instance_valid(tex): return;
	
	tex.flags = tex.flags|Texture.FLAG_REPEAT # force repeating- it's core to how this thing works
	if mirror:
		tex.flags|Texture.FLAG_MIRRORED_REPEAT
	texture = tex

func set_offset(value):
	offset = value
	update()

func get_offset():
	return offset

