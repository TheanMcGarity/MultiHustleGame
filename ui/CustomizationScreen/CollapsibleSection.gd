extends VBoxContainer
class_name CollapsibleSection

# Wraps existing children under an internal Content VBox at runtime and adds a
# clickable Header button on top. The .tscn just declares an empty
# VBoxContainer with this script attached and the regular settings as direct
# children — at _ready, those children get re-parented under Content so a
# single visibility toggle on Content collapses the whole group without
# clobbering child-level visibility (e.g. trigger sub-options).

enum Level { TOP, SUB }

const COLOR_TOP := Color(0.392157, 0.823529, 0.419608, 1)
const COLOR_SUB := Color(0.95, 0.85, 0.4, 1)

export(Level) var level = Level.TOP setget set_level
export var section_title := "Section" setget set_section_title
export var start_expanded := false

var header: Button
var header_label: Label
var content: VBoxContainer
var _expanded := false

func _ready():
	_wrap_children()
	_expanded = start_expanded
	_refresh()

func _wrap_children():
	var existing := []
	# Capture every node's owner BEFORE the remove_child. Godot 3.5.1's
	# `_propagate_after_exit_branch` clears `data.owner` when the owner isn't an
	# ancestor of the removed node — which is always true on remove_child since
	# the node's parent is set to null. Without restoring those owners after
	# re-adding under Content, every `$"%Foo"` lookup against the outer scene
	# returns null because the unique_name pin is owner-keyed.
	var owners := {}
	for c in get_children():
		existing.append(c)
		_capture_owners(c, owners)
	for c in existing:
		remove_child(c)
	header = Button.new()
	header.name = "Header"
	header.align = Button.ALIGN_LEFT
	header.size_flags_horizontal = SIZE_EXPAND_FILL
	header.rect_min_size = Vector2(0, 15)
	header.focus_mode = Control.FOCUS_NONE
	header.connect("pressed", self, "_on_header_pressed")
	add_child(header)
	# Flat-mode label sits in the header's place when the user toggles flat
	# view — only shown for TOP-level sections (yellow sub-sections just hide
	# their header entirely in flat view).
	header_label = Label.new()
	header_label.name = "HeaderLabel"
	header_label.visible = false
	add_child(header_label)
	content = VBoxContainer.new()
	content.name = "Content"
	content.size_flags_horizontal = SIZE_EXPAND_FILL
	content.add_constant_override("separation", 5)
	add_child(content)
	for c in existing:
		content.add_child(c)
	# Restore owners godot cleared during the round-trip. set_owner() also
	# re-acquires the unique_name_in_owner pin, so no separate toggle needed.
	for n in owners:
		var orig = owners[n]
		if orig != null and n.get_owner() != orig:
			n.owner = orig

func _capture_owners(node, owners):
	owners[node] = node.get_owner()
	for child in node.get_children():
		_capture_owners(child, owners)

func set_section_title(t):
	section_title = t
	if header:
		_refresh()

func set_level(l):
	level = l
	if header:
		_refresh()

func set_expanded(on):
	_expanded = on
	if !is_inside_tree():
		start_expanded = on
		return
	_refresh()

# Flat view: hide the header button and keep content visible regardless of
# _expanded. Used by the "flat view" toggle on the customization screen so
# the entire settings tree shows at once with no chrome.
var flat_mode := false

func set_flat_mode(on):
	flat_mode = on
	if header:
		header.visible = not flat_mode
	if header_label:
		# Only TOP-level sections get a label in flat mode — yellow sub-headers
		# stay hidden so the layout reads as one continuous block.
		header_label.visible = flat_mode and level == Level.TOP
	if content:
		content.visible = flat_mode or _expanded

func is_expanded() -> bool:
	return _expanded

func _on_header_pressed():
	set_expanded(not _expanded)

const PANEL_LIGHTEN := 0.035

func _refresh():
	if !header:
		return
	header.text = section_title
	var color = COLOR_TOP if level == Level.TOP else COLOR_SUB
	header.add_color_override("font_color", color)
	header.add_color_override("font_color_hover", Color.white)
	header.add_color_override("font_color_pressed", Color.white)
	if header_label:
		header_label.text = section_title
		header_label.add_color_override("font_color", color)
	# Expanded state lightens the button's panel as a subtle "this section is
	# open" cue. Done as stylebox overrides so the text/font color isn't dragged
	# along with it. Always clear the override first so get_stylebox() reads the
	# theme's untouched base — otherwise repeated _refresh calls would lerp the
	# already-lerped color and creep toward white.
	for state in ["normal", "hover", "pressed"]:
		header.add_stylebox_override(state, null)
		if _expanded:
			var sb = header.get_stylebox(state)
			if sb is StyleBoxFlat:
				var lit = sb.duplicate()
				lit.bg_color = sb.bg_color.linear_interpolate(Color.white, PANEL_LIGHTEN)
				header.add_stylebox_override(state, lit)
	if content:
		content.visible = flat_mode or _expanded
