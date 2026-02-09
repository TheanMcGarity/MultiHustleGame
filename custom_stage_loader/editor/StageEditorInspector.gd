extends PanelContainer

var target_object = null

# Properties in this list are exempt from being added to the inspector.
var prop_blacklist = [
	"main",
	"game",
	"camera",
	"data",
	"API",
	
	"Node",
	"editor_description",
	"_import_path",
	"pause_mode",
	"physics_interpolation_mode",
	"unique_name_in_owner",
	"filename",
	"owner",
	"multiplayer",
	"custom_multiplayer",
	"process_priority",
	"light_mask",
	"Theme",
	"theme",
	"theme_type_variation",
	"ThemeOverrides",
	"Styles",
	"Size Flags",
	
	"script",
	"frame",
]
# The editor to load for a given type, assuming there is no hint assigned to that property.
# https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-variant-type
var prop_editors = {
	TYPE_INT:preload("res://custom_stage_loader/editor/InspectorElements/I_Spinbox.tscn"),
	TYPE_REAL:preload("res://custom_stage_loader/editor/InspectorElements/I_Spinbox.tscn"),
	TYPE_VECTOR2:preload("res://custom_stage_loader/editor/InspectorElements/I_Vec2.tscn"),
	TYPE_VECTOR3:preload("res://custom_stage_loader/editor/InspectorElements/I_Vec3.tscn"),
	TYPE_PLANE:preload("res://custom_stage_loader/editor/InspectorElements/I_Plane.tscn"),
	TYPE_BOOL:preload("res://custom_stage_loader/editor/InspectorElements/I_Bool.tscn"),
	TYPE_STRING:preload("res://custom_stage_loader/editor/InspectorElements/I_String.tscn")
}
var misc_elements = {
	"category":preload("res://custom_stage_loader/editor/InspectorElements/I_Category.tscn"),
	"multiline_string":preload("res://custom_stage_loader/editor/InspectorElements/I_StringMultiline.tscn")
}
# The editor to load for a given hint, if the hint is not PROPERTY_HINT_NONE (0)
# https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-propertyhint
var prop_hints = {
	PROPERTY_HINT_RANGE:prop_editors[TYPE_INT],
	PROPERTY_HINT_MULTILINE_TEXT:misc_elements["multiline_string"],
}

func _ready():
	pass # Replace with function body.

func set_target_object(obj:Object):
	target_object = obj
	construct_property_list()

# just makes a list of labels rn- have to make prop editors........
# it's mod options all over again
func construct_property_list():
	var proplist = $"%PropList"
	for node in proplist.get_children():
		node.queue_free()
	if not target_object:
		return
	var props = target_object.get_property_list()
	#print(props)
	for i in props:
		# sorry giant if statement- i'll break it down later...
		if ((i.usage & PROPERTY_USAGE_STORAGE and i.usage & PROPERTY_USAGE_EDITOR) or i.usage & PROPERTY_USAGE_CATEGORY or i.usage & PROPERTY_USAGE_GROUP) and not i.name in prop_blacklist:
			var newobj = null
			if i.hint in prop_hints:
				# Hint was found, instance property editor by hint.
				newobj = prop_hints[i.hint].instance()
			elif i.type in prop_editors:
				# Hint not found, instance property editor by type.
				newobj = prop_editors[i.type].instance()
			elif i.usage & PROPERTY_USAGE_CATEGORY:
				# Shitty hardcoded exception...
				newobj = misc_elements["category"].instance()
			else:
				# Skip this property.
				continue
			# Set values in the property object
			newobj.set_prop_data(i)
			newobj.set_object(target_object)
			proplist.add_child(newobj)
