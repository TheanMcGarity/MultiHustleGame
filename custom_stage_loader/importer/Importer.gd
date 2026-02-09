extends Reference

# + PCK Importer
# - Authors: Snazzah, Supersonic
#
# - Class that handles importing assets

var unique_hash = ""
var pck: PCKPacker
var pck_path = ""
var dir_path = ""
var opened = false
var file_types = {
	"png": "image_import",
	"mp3": "audio_import",
	"wav": "audio_import",
	"ogg": "audio_import"
}
var audio_importer
var stex_template: String

enum CompressMode {
	COMPRESS_LOSSLESS,
	COMPRESS_LOSSY,
	COMPRESS_VIDEO_RAM,
	COMPRESS_UNCOMPRESSED
}

enum {
	FORMAT_MASK_IMAGE_FORMAT = (1 << 20) - 1,
	FORMAT_BIT_PNG = 1 << 20,
	FORMAT_BIT_WEBP = 1 << 21,
	FORMAT_BIT_STREAM = 1 << 22,
	FORMAT_BIT_HAS_MIPMAPS = 1 << 23,
	FORMAT_BIT_DETECT_3D = 1 << 24,
	FORMAT_BIT_DETECT_SRGB = 1 << 25,
	FORMAT_BIT_DETECT_NORMAL = 1 << 26,
}


func _init(pck_path = ""):
	unique_hash = str(OS.get_unix_time()).sha256_text()
	dir_path = "user://import_temp-%s" % unique_hash
	if pck_path == "":
		pck_path = "user://importer-%s.pck" % unique_hash
	self.pck_path = pck_path
	audio_importer = load("res://custom_stage_loader/importer/GDScriptAudioImport.gd").new()


func _load_template(type: String):
	if get("%s_template" % type): return
	var f = File.new()
	if f.open("res://custom_stage_loader/importer/%s.ini" % type, File.READ) == OK:
		set("%s_template" % type, f.get_as_text())
		f.close()


func start():
	var dir = Directory.new()
	if not dir.dir_exists(pck_path.get_base_dir()):
		dir.make_dir_recursive(pck_path.get_base_dir())
	pck = PCKPacker.new()
	pck.pck_start(pck_path)
	Directory.new().make_dir(dir_path)
	opened = true


func close():
	if not opened: return
	pck.flush()
	ProjectSettings.load_resource_pack(pck_path)
	opened = false
	var dir = Directory.new()
	if dir.open(dir_path) == OK:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name != "." and file_name != ".." and not dir.current_is_dir():
				dir.remove(dir_path + "/" + file_name)
			file_name = dir.get_next()
		dir.remove(dir_path)


func delete_pck():
	var dir = Directory.new()
	dir.remove(pck_path)


func copy_pck(dest: String):
	var dir = Directory.new()
	dir.copy(pck_path, dest)


func import_from_mod(folder):
	if not opened: start()
	
#	var assets = ModLoader._get_all_files(folder, "png") + ModLoader._get_all_files(folder, "wav") + ModLoader._get_all_files(folder, "ogg")
	for type in file_types.keys():
		var assets = ModLoader._get_all_files(folder, type, [], true)
		for i in len(assets):
			var asset = ProjectSettings.localize_path(assets[i])
			import_file(asset)


func import_file(asset):
	var dir = Directory.new()
	if not dir.file_exists(asset + ".import"):
		if not opened: start()
		# I would do more, but I'm lazy
		match asset.get_extension():
			"png":
				# Create import file (from a template file, even though ConfigFile would be OK too)
				if not stex_template: _load_template("stex")
				var import_path = asset + ".import"
				var dest_file = asset.get_file() + "-%s.stex" % asset.md5_text()
				var dest = "res://.import/" + dest_file
				var import_data = stex_template.replace("%__SRC__%", asset).replace("%__DEST__%", dest)
				var tmp_file = dir_path + "/" + dest_file
				var split_file_name = import_path.get_file().rsplit(".", true, 1)
				var tmp_import_file = dir_path + "/" + split_file_name[0] + "-" + asset.md5_text() + "." + split_file_name[1]
				var f = File.new()
				if f.open(tmp_import_file, File.WRITE) == OK:
					f.store_string(import_data)
					f.close()
					pck.add_file(import_path, tmp_import_file)
				
				# Create .stex file
				var img = Image.new()
				img.load(asset)
				_save_stex(img, tmp_file, CompressMode.COMPRESS_LOSSLESS, 0.7, Image.COMPRESS_S3TC, false, 0, false, true, true, false, false, true, false)
				pck.add_file(dest, tmp_file)
	else:
		var c = ConfigFile.new()
		c.load(asset + ".import")
		var dest = c.get_value("remap", "path")
		
		# If the .stex/.sample/.oggstr doesn't exist, create it
		if not dir.file_exists(dest):
			if not opened: start()
			var tmp_file = dir_path + "/" + dest.split("://.import/")[1]
			if asset.get_extension() in file_types:
				call(file_types[asset.get_extension()], c, asset, tmp_file)
				pck.add_file(dest, tmp_file)


func audio_import(import_file: ConfigFile, path: String, tmp_file: String):
	var aud = audio_importer.loadfile(path)
	if aud is AudioStreamSample:
		var loop_mode = import_file.get_value("params","edit/loop_mode")
		if loop_mode != 0:
			aud.loop_mode = loop_mode-1
			if loop_mode > 1:
				aud.loop_begin = import_file.get_value("params","edit/loop_begin")
				aud.loop_end = import_file.get_value("params","edit/loop_end")
	else:
		aud.loop = import_file.get_value("params", "loop")
		aud.loop_offset = import_file.get_value("params", "loop_offset")
	
	ResourceSaver.save(dir_path + "/" + tmp_file.get_file(), aud)


func image_import(import_file: ConfigFile, path: String, tmp_file: String):
	_image_import(import_file, path, dir_path + "/" + tmp_file.get_file().trim_suffix(".stex"))


func _image_import(import_file, path, out_dir):
	# copy of both the texture importer and stex saver, in one. basically ported directly from the
	# godot source.
	# is this hell?
	# get import file- it follows ini format so we use ConfigFile to make our lives easy because i know
	# i'm gonna fucking need it
	
	var img := Image.new()
	var err = img.load(path)
	if err != OK:
		return err
	
	# wall of flags
	var compress_mode:int = import_file.get_value("params","compress/mode")
	var lossy:float = import_file.get_value("params", "compress/lossy_quality")
	var repeat:int = import_file.get_value("params", "flags/repeat")
	var filter:bool = import_file.get_value("params", "flags/filter")
	var mipmaps:bool = import_file.get_value("params", "flags/mipmaps")
	var anisotropic:bool = import_file.get_value("params", "flags/anisotropic")
	var srgb:int = import_file.get_value("params", "flags/srgb")
	var fix_alpha_border:bool = import_file.get_value("params", "process/fix_alpha_border")
	var premult_alpha:bool = import_file.get_value("params", "process/premult_alpha")
	var invert_color:bool = import_file.get_value("params", "process/invert_color")
	var normal_map_invert_y:bool = import_file.get_value("params", "process/normal_map_invert_y")
	var stream:bool = import_file.get_value("params", "stream")
	var size_limit:int = import_file.get_value("params", "size_limit")
	var hdr_as_srgb:bool = import_file.get_value("params", "process/HDR_as_SRGB")
	var normal:int = import_file.get_value("params", "compress/normal_map")
	var scale:float = import_file.get_value("params", "svg/scale")
	var force_rgbe:bool = import_file.get_value("params", "compress/hdr_mode")
	var btpc_ldr:int = import_file.get_value("params", "compress/bptc_ldr")
	
	var tex_flags = 0
	# set flags
	if repeat > 0:
		tex_flags |= Texture.FLAG_REPEAT
	if repeat == 2:
		tex_flags |= Texture.FLAG_MIRRORED_REPEAT
	if filter:
		tex_flags |= Texture.FLAG_FILTER # this should never be used in yomih...
	if mipmaps || compress_mode == CompressMode.COMPRESS_VIDEO_RAM:
		tex_flags |= Texture.FLAG_MIPMAPS
	if anisotropic:
		tex_flags |= Texture.FLAG_ANISOTROPIC_FILTER
	if srgb == 1:
		tex_flags |= Texture.FLAG_CONVERT_TO_LINEAR
	# size limit here
	# lol
	if fix_alpha_border:
		img.fix_alpha_edges()
	if premult_alpha:
		img.premultiply_alpha()
	if invert_color:
		var height = img.get_height()
		var width = img.get_width()
		img.lock()
		for x in width:
			for y in height:
				img.set_pixel(x, y, img.get_pixel(x,y).inverted())
		img.unlock()
	if normal_map_invert_y:
		# invert the green channel
		var height = img.get_height()
		var width = img.get_width()
		img.lock()
		for x in width:
			for y in height:
				var color := img.get_pixel(x,y)
				img.set_pixel(x, y, Color(color.r, 1-color.g, color.b))
		img.unlock()
	var detect_3d:bool = import_file.get_value("params", "detect_3d")
	var detect_srgb:bool = srgb == 2
	var detect_normal = normal == 0
	var force_normal = normal == 1
	
	if compress_mode == CompressMode.COMPRESS_VIDEO_RAM:
		compress_mode = CompressMode.COMPRESS_LOSSLESS # i don't trust that vram compression will work for now
	
	if compress_mode == CompressMode.COMPRESS_VIDEO_RAM:
		var ok_on_pc:bool = false
		var is_hdr:bool = img.get_format() >= Image.FORMAT_RF && img.get_format() <= Image.FORMAT_RGBE9995
		var is_ldr:bool = img.get_format() >= Image.FORMAT_L8 && img.get_format() <= Image.FORMAT_RGBA5551
		#var can_bptc = ProjectSettings.get_setting("rendering/vram_compression/import_bptc") #yomi doesn't use bptc (thankfully..)
		var can_bptc = false
		var can_s3tc = ProjectSettings.get_setting("rendering/vram_compression/import_s3tc")
		
		if !can_bptc && is_hdr && !force_rgbe:
			img.convert(Image.FORMAT_RGBA8)
		if can_bptc || can_s3tc:
			_save_stex(img, out_dir+".s3tc.stex", compress_mode, lossy, Image.COMPRESS_BPTC if can_bptc else Image.COMPRESS_S3TC, mipmaps, tex_flags, stream, detect_3d, detect_srgb, force_rgbe, detect_normal, force_normal, false)
			ok_on_pc = true
		if ProjectSettings.get_setting("rendering/vram_compression/import_etc2"):
			_save_stex(img, out_dir+".etc2.stex", compress_mode, lossy, Image.COMPRESS_ETC2, mipmaps, tex_flags, stream, detect_3d, detect_srgb, force_rgbe, detect_normal, force_normal, false)
		if ProjectSettings.get_setting("rendering/vram_compression/import_etc"):
			_save_stex(img, out_dir+".etc.stex", compress_mode, lossy, Image.COMPRESS_ETC, mipmaps, tex_flags, stream, detect_3d, detect_srgb, force_rgbe, detect_normal, force_normal, false)
		if ProjectSettings.get_setting("rendering/vram_compression/import_pvrtc"):
			_save_stex(img, out_dir+".etc.stex", compress_mode, lossy, Image.COMPRESS_PVRTC4, mipmaps, tex_flags, stream, detect_3d, detect_srgb, force_rgbe, detect_normal, force_normal, false)
	else:
		_save_stex(img, out_dir+".stex", compress_mode, lossy, Image.COMPRESS_S3TC, mipmaps, tex_flags, stream, detect_3d, detect_srgb, force_rgbe, detect_normal, force_normal, false)

	return OK


func lossless_pack_png(image):
	var out_buffer:PoolByteArray = []
	
	out_buffer.append_array([0x50, 0x4E, 0x47, 0x20])
	
	out_buffer.append_array(image.save_png_to_buffer())
	return out_buffer


func _save_stex(image, out_dir, compress_mode, lossy_quality, vram_compression, mipmaps, texture_flags, streamable, detect_3d, detect_srgb, force_rgbe, detect_normal, force_normal, force_po2_for_compressed):
	var stex_file := File.new()
	stex_file.open(out_dir, File.WRITE)
	stex_file.endian_swap = false
	
	# it begins.
	# header
	stex_file.store_string('GDST')
	
	var resize_to_po2 := false
	
	if compress_mode == CompressMode.COMPRESS_VIDEO_RAM && force_po2_for_compressed && (mipmaps || texture_flags & Texture.FLAG_REPEAT):
		resize_to_po2 = true
		stex_file.store_16(nearest_po2(image.get_width()))
		stex_file.store_16(image.get_width())
		stex_file.store_16(nearest_po2(image.get_height()))
		stex_file.store_16(image.get_height())
	else:
		stex_file.store_16(image.get_width())
		stex_file.store_16(0)
		stex_file.store_16(image.get_height())
		stex_file.store_16(0)
	stex_file.store_32(texture_flags)
	
	var format = 0
	
	if streamable:
		format |= FORMAT_BIT_STREAM
	if mipmaps:
		format |= FORMAT_BIT_HAS_MIPMAPS
	if detect_3d:
		format |= FORMAT_BIT_DETECT_3D
	if detect_srgb:
		format |= FORMAT_BIT_DETECT_SRGB
	if detect_normal:
		format |= FORMAT_BIT_DETECT_NORMAL
	#print(format)
	
	if (compress_mode == CompressMode.COMPRESS_LOSSLESS || compress_mode == CompressMode.COMPRESS_LOSSY) && image.get_format() > Image.FORMAT_RGBA8:
		compress_mode = CompressMode.COMPRESS_UNCOMPRESSED
	if compress_mode == CompressMode.COMPRESS_LOSSY:
		compress_mode = CompressMode.COMPRESS_LOSSLESS
		
	
	# I would use a match but i'm testing this from a mod so that won't work : )
	if compress_mode == CompressMode.COMPRESS_LOSSLESS:
		#print("lossless")
		var lossless_force_png = ProjectSettings.get_setting("rendering/misc/lossless_compression/force_png")
		var use_webp = !lossless_force_png && image.get_width() <= 16383 && image.get_height() <= 16383
		var _image:Image = image.duplicate()
#		if mipmaps:
#			_image.generate_mipmaps()
#		else:
#			_image.clear_mipmaps()
		_image.clear_mipmaps() # mipmaps aren't supported since image.get_mipmap_count is not exposed to gdscript.
		
		var mmc = 1
		#print(mmc)
		
#		if use_webp:
#			format |= FORMAT_BIT_WEBP
#		else:
#			format |= FORMAT_BIT_PNG
		format |= FORMAT_BIT_PNG # im sorry i honestly don't feel like supporting webp right now :(
		
		stex_file.store_32(format)
		stex_file.store_32(mmc)
		
		for i in range(mmc):
			if i > 0:
				_image.shrink_x2()
			
			var data:PoolByteArray = []
			data = lossless_pack_png(_image)
			
			var data_len = data.size()
			stex_file.store_32(data_len)
			
			stex_file.store_buffer(data)
	elif compress_mode == CompressMode.COMPRESS_VIDEO_RAM:
		# I cannot guarantee that this one will work- it is untested for now
		var _image:Image = image.duplicate()
		if resize_to_po2:
			_image.resize_to_po2()
		if mipmaps:
			_image.generate_mipmaps()
		
		if force_rgbe && _image.get_format() >= Image.FORMAT_R8 && _image.get_format <= Image.FORMAT_RGBE9995:
			_image.convert(Image.FORMAT_RGBE9995)
		else:
			var csource = Image.COMPRESS_SOURCE_GENERIC
			if force_normal:
				csource = Image.COMPRESS_SOURCE_NORMAL
			elif texture_flags & Texture.FLAG_CONVERT_TO_LINEAR:
				csource = Image.COMPRESS_SOURCE_SRGB
			_image.compress(vram_compression, csource, lossy_quality)
		
		format |= _image.get_format()
		
		stex_file.store_32(format)
		
		var data = _image.get_data()
		stex_file.store_buffer(data)
		
		
	elif compress_mode == CompressMode.COMPRESS_UNCOMPRESSED:
		var _image:Image = image.duplicate()
		if mipmaps:
			_image.generate_mipmaps()
		else:
			_image.clear_mipmaps()
			
		format |= _image.get_format()
		stex_file.store_32(format)
		
		var data = _image.get_data()
		var data_size = data.size()
		
		stex_file.store_buffer(data)
		pass
	
	stex_file.close()
