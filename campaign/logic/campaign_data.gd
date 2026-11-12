extends RefCounted
const Catalog=preload("res://campaign/content/campaign_catalog.gd")

static func load_catalog(paths:Array=[])->Dictionary:
	paths=paths.duplicate()
	if paths.is_empty():
		for level in range(1,6):paths.append("res://campaign/layouts/level_%02d.gd"%level)
	var levels:Array=[]
	for path in paths:
		if not path is String or not ResourceLoader.exists(path):return {"ok":false,"error":"Missing level definition: "+str(path),"sectors":[]}
		var source=load(path)
		if source==null or not source.has_method("sectors"):return {"ok":false,"error":"Invalid level definition: "+str(path),"sectors":[]}
		levels.append(source.sectors())
	return Catalog.validate(levels)

static func sectors()->Array[Dictionary]:
	var result:=load_catalog()
	if not result.ok:
		push_error("Campaign content could not be loaded: "+str(result.error))
		return []
	var output:Array[Dictionary]=[]
	output.assign(result.sectors)
	return output
