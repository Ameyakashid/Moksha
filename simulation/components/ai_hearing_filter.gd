extends RefCounted
## AI peer policy only; shared hearing evidence and acoustic queries are unchanged.
static func ignores(source: Node, peer_group: StringName) -> bool:
	return is_instance_valid(source) and not peer_group.is_empty() and source.is_in_group(peer_group)
