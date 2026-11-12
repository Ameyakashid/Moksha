extends RefCounted
## Fresh report files only, outside project sources and without symlink ancestors.
static func validate(raw:String)->String:
	if raw.is_empty():return "--report is required"
	var path:=ProjectSettings.globalize_path(raw)
	if not path.is_absolute_path():return "Report path must be absolute or user://"
	if path!=path.simplify_path():return "Report path must be normalized"
	var source:=ProjectSettings.globalize_path("res://").trim_suffix("/")
	if path==source or path.begins_with(source+"/"):return "Report must be outside source tree"
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):return "Report destination already exists"
	if not DirAccess.dir_exists_absolute(path.get_base_dir()):return "Report parent must exist"
	var cursor:=path
	while cursor!="/" and not cursor.is_empty():
		var directory:=DirAccess.open(cursor.get_base_dir())
		if directory==null:return "Cannot inspect report parent"
		if directory.is_link(cursor.get_file()):return "Symlink report paths are forbidden"
		cursor=cursor.get_base_dir()
	return ""
static func write_report(raw:String,report:Dictionary)->String:
	var invalid:=validate(raw)
	if not invalid.is_empty():return invalid
	var file:=FileAccess.open(raw,FileAccess.WRITE)
	if file==null:return "Report open failed: "+str(FileAccess.get_open_error())
	var encoded:=JSON.stringify(report,"  ")
	file.store_string(encoded);file.flush()
	var error:=file.get_error();file.close()
	if error!=OK:return "Report write failed: "+str(error)
	if FileAccess.get_file_as_string(raw)!=encoded:return "Report readback mismatch"
	return ""
