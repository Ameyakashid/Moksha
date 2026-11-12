extends RefCounted
## Single-writer immutable history files, separate from mutable resume checkpoint.
## Record then checkpoint is a recoverable sequence, never an atomic two-file claim.
const Record=preload("res://campaign/state/completion_record.gd")

static func _failure(message:String)->Dictionary:return {"ok":false,"found":true,"error":message}
static func _path(root:String,id:String)->String:return root.path_join("completed").path_join(id+".json")
static func _ensure(directory:String)->bool:
	var cursor:=ProjectSettings.globalize_path(directory).simplify_path()
	while not cursor.is_empty():
		if FileAccess.file_exists(cursor):return false
		var parent:=cursor.get_base_dir()
		if parent==cursor:break
		cursor=parent
	return DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))==OK

static func get_record(root:String,id:String)->Dictionary:
	if not Record.valid_id(id):return _failure("Invalid completion run identity.")
	var path:=_path(root,id)
	if not FileAccess.file_exists(path):
		if DirAccess.dir_exists_absolute(path):return _failure("Completion record path is a directory; nothing was replaced.")
		return {"ok":true,"missing":true,"found":false}
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null:return _failure("Completion history cannot be read; nothing was replaced.")
	var text:=file.get_as_text();var error:=file.get_error();file.close()
	if error!=OK:return _failure("Completion history read failed.")
	var parser:=JSON.new()
	if parser.parse(text)!=OK or not Record.valid(parser.data):return _failure("Completion history is invalid; original bytes retained.")
	if parser.data.run_id!=id:return _failure("Completion history identity does not match its filename.")
	return {"ok":true,"found":true,"record":parser.data.duplicate(true),"path":path}

static func reconcile(root:String,id:String)->Dictionary:
	# Startup recovery for record-first completion. Pending bytes are terminal
	# evidence, never permission to resume the old active checkpoint.
	if not Record.valid_id(id):return _failure("Invalid completion run identity.")
	var directory:=root.path_join("completed")
	var cursor:=ProjectSettings.globalize_path(directory).simplify_path()
	while not cursor.is_empty():
		if FileAccess.file_exists(cursor):return _failure("Completion history ancestor is a file; resume blocked.")
		var parent:=cursor.get_base_dir()
		if parent==cursor:break
		cursor=parent
	var current:=get_record(root,id)
	if not current.ok or current.found:return current
	var pending:=_path(root,id)+".pending"
	if DirAccess.dir_exists_absolute(pending):return _failure("Pending completion path is a directory; resume blocked.")
	if not FileAccess.file_exists(pending):return current
	var file:=FileAccess.open(pending,FileAccess.READ)
	if file==null:return _failure("Pending completion cannot be read; resume blocked.")
	var text:=file.get_as_text();var error:=file.get_error();file.close()
	var parser:=JSON.new()
	if error!=OK or parser.parse(text)!=OK or not Record.valid(parser.data):return _failure("Pending completion is invalid; bytes retained and resume blocked.")
	if parser.data.run_id!=id:return _failure("Pending completion identity mismatch; bytes retained and resume blocked.")
	# put also rejects a noncanonical/conflicting pending file without replacing it.
	var promoted:=put(root,parser.data)
	if not promoted.ok:return promoted
	return get_record(root,id)

static func put(root:String,record:Dictionary)->Dictionary:
	if not Record.valid(record):return _failure("Invalid completion record; no history was written.")
	var path:=_path(root,record.run_id)
	var encoded:=Record.canonical(record)
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
		var existing:=get_record(root,record.run_id)
		if not existing.ok:return existing
		if not existing.found:return _failure("Completion disappeared during read; retry without replacing history.")
		if Record.canonical(existing.record)!=encoded:return _failure("Run identity already has a different completion; original history retained.")
		return {"ok":true,"path":path,"already_committed":true}
	if not _ensure(path.get_base_dir()):return _failure("Completion history folder could not be created.")
	var pending:=path+".pending"
	if DirAccess.dir_exists_absolute(pending):return _failure("Pending completion path is a directory; nothing was replaced.")
	if FileAccess.file_exists(pending):
		if FileAccess.get_file_as_string(pending)!=encoded:return _failure("Different pending completion exists; pending bytes retained.")
	else:
		var file:=FileAccess.open(pending,FileAccess.WRITE)
		if file==null:return _failure("Completion could not be written; keep the game open and retry.")
		file.store_string(encoded);file.flush();var error:=file.get_error();file.close()
		if error!=OK:return _failure("Completion write failed; pending bytes retained.")
	if FileAccess.get_file_as_string(pending)!=encoded:return _failure("Completion readback failed; pending bytes retained.")
	# Check again before rename. Callers serialize writers; this is not a cross-process lock.
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):return _failure("Completion destination appeared during commit; both files retained.")
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(pending),ProjectSettings.globalize_path(path))!=OK:return _failure("Completion commit failed; pending record retained for retry.")
	var committed:=get_record(root,record.run_id)
	if not committed.ok or not committed.get("found",false) or Record.canonical(committed.record)!=encoded:return _failure("Committed completion readback failed; history retained.")
	return {"ok":true,"path":path,"already_committed":false}

static func preserve_file(root:String,source:String,label:String)->Dictionary:
	if label.is_empty():return _failure("Preservation label is empty.")
	for character in label:
		if not character in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-":return _failure("Invalid preservation label.")
	if not FileAccess.file_exists(source):
		if DirAccess.dir_exists_absolute(source):return _failure("Preservation source is a directory.")
		return {"ok":true,"missing":true}
	var digest:=FileAccess.get_sha256(source)
	if digest.is_empty():return _failure("Previous data could not be read; it has not been replaced.")
	var path:=root.path_join("preserved").path_join(label+"-"+digest+".json")
	if not _ensure(path.get_base_dir()):return _failure("Preservation directory could not be created; previous data retained.")
	if DirAccess.dir_exists_absolute(path):return _failure("Preservation destination is a directory; previous data retained.")
	if not FileAccess.file_exists(path):
		# Preserve exact raw bytes, even if legacy JSON is malformed.
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(source),ProjectSettings.globalize_path(path))!=OK:return _failure("Previous data could not be preserved; source retained.")
	if FileAccess.get_sha256(path)!=digest or FileAccess.get_sha256(source)!=digest:return _failure("Preserved data verification failed; source and archive retained.")
	return {"ok":true,"path":path,"sha256":digest}

static func latest(root:String)->Dictionary:
	var directory:=root.path_join("completed")
	if not DirAccess.dir_exists_absolute(directory):
		if FileAccess.file_exists(directory):return _failure("Completion history directory is a file.")
		return {"ok":true,"missing":true,"found":false}
	var dir:=DirAccess.open(directory)
	if dir==null:return _failure("Completion history directory cannot be read.")
	var best:Dictionary={}
	for filename in dir.get_files():
		if not filename.ends_with(".json"):continue # Pending files are not completed records.
		var candidate:=get_record(root,filename.trim_suffix(".json"))
		if not candidate.ok:return candidate # Surface corrupt records, never silently erase/skip them.
		if not candidate.found:return _failure("Completion disappeared during history scan; retry.")
		if best.is_empty() or candidate.record.completed_at>best.record.completed_at or (candidate.record.completed_at==best.record.completed_at and candidate.record.run_id>best.record.run_id):best=candidate
	return best if not best.is_empty() else {"ok":true,"missing":true,"found":false}
