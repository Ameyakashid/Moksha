class_name MokshaMeleeChainProfile
extends Resource
## Optional original MOKSHA ordered chain. Resources are configuration only;
## runtime progress, input identities and hit sets belong to each actor.
@export var chain_id: StringName = &"moksha_light"
@export var steps: Array[MokshaMeleeStepProfile] = []
@export var start_step := 0
## Optional independent fresh-chain openings. This is not a combo link: only
## serial-zero fresh commitments consume it; held/charge/follow-ups are unchanged.
@export var fresh_start_steps := PackedInt32Array()
@export var followup_buffer_seconds := 0.22
@export var idle_retention_seconds := 0.30
## Fresh mode only: admit one new-chain tap near a terminal recovery's end.
## The ordinary attack buffer sets its deadline. Zero retains prior behavior.
@export var fresh_restart_window_seconds := 0.0

func is_valid_chain() -> bool:
	if chain_id.is_empty() or steps.is_empty() or steps.size() > 16 or start_step < 0 or start_step >= steps.size(): return false
	if not is_finite(followup_buffer_seconds) or followup_buffer_seconds <= 0 or not is_finite(idle_retention_seconds) or idle_retention_seconds < 0: return false
	if not is_finite(fresh_restart_window_seconds) or fresh_restart_window_seconds < 0: return false
	for index in fresh_start_steps:
		if index < 0 or index >= steps.size(): return false
	for step in steps:
		if step == null or not step.is_valid_step(steps.size()): return false
	return true

func snapshot() -> MokshaMeleeChainProfile:
	if not is_valid_chain(): return null
	var copy = MokshaMeleeChainProfile.new()
	copy.chain_id = chain_id
	copy.start_step = start_step
	copy.fresh_start_steps = fresh_start_steps.duplicate()
	copy.followup_buffer_seconds = followup_buffer_seconds
	copy.idle_retention_seconds = idle_retention_seconds
	copy.fresh_restart_window_seconds = fresh_restart_window_seconds
	for step in steps:
		copy.steps.append(step.duplicate(true))
	return copy
