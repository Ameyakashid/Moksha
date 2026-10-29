extends RefCounted
static func sectors()->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	for level in range(1,6):
		var path:="res://campaign/layouts/level_%02d.gd"%level
		if not ResourceLoader.exists(path):continue
		var source=load(path)
		for data in source.sectors():
			data["level"]=level
			result.append(data)
	return result
