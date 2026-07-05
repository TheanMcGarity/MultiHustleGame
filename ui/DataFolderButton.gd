extends Button

func _on_pressed():
	OS.shell_open(ProjectSettings.globalize_path("user://"))
