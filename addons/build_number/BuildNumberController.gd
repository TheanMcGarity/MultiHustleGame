tool
extends EditorPlugin

func build():
	increment_variable()
	return true

func increment_variable():
	var file = File.new()
	
	file.open("res://Global.gd", File.READ)
	var content = file.get_as_text()
	file.close()

	var lines = content.split("\n")

	for i in range(lines.size()):
		var line = lines[i].strip_edges()

		if line.begins_with("var BUILD"):
			var parts = line.split("=")
			if parts.size() == 2:
				var value = int(parts[1].strip_edges())
				value += 1
				lines[i] = "var BUILD = %d" % value
				break

	file.open("res://Global.gd", File.WRITE)
	file.store_string("\n".join(lines))
	file.close()

	print("Build count incremented.")
