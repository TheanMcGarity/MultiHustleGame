extends Node

class_name StyleHooks

# Modding hook surface for the style system (Custom autoload). Style data is a
# plain Dictionary, not a node, so the hooks live on the global Custom singleton
# (which creates one of these as a child in _ready). `host` is the Custom
# autoload. Each style Dictionary carries a `mod_data` dict reserved for
# mod-specific per-style data — read/write it here. See ObjHooks.gd for how
# to register an extension; the script to extend is res://StyleHooks.gd.

var host = null


# Style system finished _ready.
func ready():
	pass

# A style is being applied to a `material`. `style` is the style Dictionary,
# `force_extras` whether the extra color slots are forced on. Runs after the
# base game has set the shader params, so a mod can override or add to them.
func apply_style(style, material, force_extras):
	pass

# Styles were loaded from disk/workshop. `styles` is the array of style dicts,
# `files` the parallel array of their paths.
func load_styles(styles, files):
	pass

# A style was saved to `path`. `style` is the style Dictionary.
func save_style(style, path):
	pass
