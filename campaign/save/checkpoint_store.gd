extends RefCounted
## Disk ownership only: detached validated reads, retained invalid bytes, pending commit.
## No live campaign state, UI, actor construction or transition application.
const Progress=preload("res://demo/components/checkpoint_codec.gd")
const Codec=preload("res://campaign/logic/checkpoint_codec.gd")

static func read(path:String,sectors:Array)->Dictionary:
	if not FileAccess.file_exists(path):return {"ok":false}
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null:return {"ok":false,"error":"The campaign checkpoint could not be opened. Check folder access."}
	var text:=file.get_as_text();file.close()
	return Codec.decode(Progress.parse(text),sectors)

static func commit(path:String,raw:Dictionary)->Dictionary:
	var file:=FileAccess.open(path+".pending",FileAccess.WRITE)
	if not file:return {"ok":false,"error":"The campaign checkpoint could not be written."}
	file.store_string(JSON.stringify(raw));file.flush();var error:=file.get_error();file.close()
	if error!=OK or DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".pending"),ProjectSettings.globalize_path(path))!=OK:
		return {"ok":false,"error":"The campaign checkpoint could not be committed."}
	return {"ok":true}

static func preserve_invalid(path:String,sectors:Array)->Dictionary:
	if not FileAccess.file_exists(path) or read(path,sectors).get("ok",false):return {"ok":true}
	var digest:=FileAccess.get_sha256(path)
	var backup:=path+".preserved-"+digest+".json"
	if digest.is_empty():return {"ok":false,"error":"The existing checkpoint could not be read; it has not been replaced."}
	if not FileAccess.file_exists(backup) and DirAccess.copy_absolute(ProjectSettings.globalize_path(path),ProjectSettings.globalize_path(backup))!=OK:
		return {"ok":false,"error":"The previous checkpoint could not be preserved; it has not been replaced."}
	if FileAccess.get_sha256(backup)!=digest or FileAccess.get_sha256(path)!=digest:
		return {"ok":false,"error":"The previous checkpoint backup could not be verified; it has not been replaced."}
	return {"ok":true}
