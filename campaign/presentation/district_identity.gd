extends RefCounted
## Authored presentation-only vocabulary. IDs match existing districts; no new
## location, faction, objective, route or historical fact is introduced here.
## The returned data is owned by the caller and cannot mutate these definitions.
const DISTRICTS := {
	"rainline": ["RAINLINE", "market", ["shutter", "window", "duct"]],
	"city_clinic": ["NIGHT CLINIC", "clinic", ["clinic", "window", "duct"]],
	"city_tram_depot": ["TRAM DEPOT", "transit", ["power", "shutter", "duct"]],
	"city_records": ["SQUAD RECORDS", "records", ["records", "window", "duct"]],
	"city_evac_spine": ["REFUGE", "refuge", ["refuge", "window", "duct"]],
	"quarantine_intake": ["INTAKE", "intake", ["duct", "shutter", "power"]],
	"l2_exchange": ["THE EXCHANGE", "exchange", ["shutter", "power", "duct"]],
	"l2_capacitor_mill": ["CAPACITOR MILL", "power", ["power", "duct", "power"]],
	"l2_freight": ["FREIGHT TRANSFER", "freight", ["shutter", "duct", "shutter"]],
	"l2_stamping_galleries": ["STAMPING", "press", ["press", "power", "duct"]],
	"l2_thermal_foundry": ["THERMAL FOUNDRY", "heat", ["heat", "duct", "heat"]],
	"l2_union_dispatch": ["UNION DISPATCH", "dispatch", ["records", "shutter", "power"]],
	"l3_cistern": ["CISTERN", "water", ["water", "window", "water"]],
	"l3_inundated_market": ["MARKET", "market", ["shutter", "window", "water"]],
	"l3_water_clinic": ["WATERLINE CLINIC", "clinic", ["clinic", "water", "window"]],
	"l3_homes": ["RESIDENCES", "home", ["window", "refuge", "window"]],
	"l3_refuge_terraces": ["REFUGE TERRACES", "refuge", ["refuge", "window", "water"]],
	"l3_drainage_commons": ["DRAINAGE", "water", ["water", "duct", "window"]],
	"works_receiving": ["RECEIVING", "records", ["records", "rack", "shutter"]],
	"works_baffle_hall": ["LISTENING FLOOR", "baffle", ["baffle", "rack", "duct"]],
	"works_cargo_exchange": ["CARGO EXCHANGE", "freight", ["shutter", "rack", "duct"]],
	"works_memory_loom": ["MEMORY LOOM", "loom", ["loom", "records", "rack"]],
	"works_service_refuge": ["SERVICE REFUGE", "refuge", ["refuge", "window", "rack"]],
	"works_three_crews": ["THREE CREWS", "network", ["power", "rack", "loom"]],
	"works_dispatch_refusal": ["DISPATCH", "dispatch", ["records", "rack", "baffle"]],
	"crown_ascent": ["CROWN INTAKE", "weather", ["duct", "window", "power"]],
	"crown_witness_galleries": ["WITNESS GALLERY", "records", ["records", "window", "rack"]],
	"crown_manual_governor": ["MANUAL GOVERNOR", "governor", ["power", "duct", "rack"]],
	"crown_refuge_channel": ["REFUGE CHANNEL", "refuge", ["refuge", "window", "duct"]],
	"crown_coolant_interlock": ["COOLANT SERVICE", "water", ["water", "duct", "power"]],
	"crown_last_warden": ["COMMAND", "authority", ["rack", "window", "power"]],
	"crown_choice_threshold": ["MANUAL CONTROLS", "threshold", ["records", "window", "power"]],
}

static func seed_for(district_id: String) -> int:
	# Local, version-independent integer mixing. Never consume the simulation RNG.
	var result := 5381
	for code in district_id.to_utf32_buffer():
		result = ((result * 33) + int(code)) & 0x7fffffff
	return result

static func profile_for(district_id: String, motif: String) -> Dictionary:
	var seed := seed_for(district_id)
	var fallback := ["", "service", ["duct", "window", "shutter"]]
	var entry: Array = DISTRICTS.get(district_id, fallback)
	return {
		"id": district_id,
		"label": str(entry[0]),
		"mark": str(entry[1]),
		"bay_types": entry[2].duplicate(),
		"authored": DISTRICTS.has(district_id),
		"seed": seed,
		"bay_width": float([336, 384, 420, 456][posmod(seed / 13, 4)]),
		"skyline_phase": float(posmod(seed, 1489)) / 1489.0,
		"skyline_y": float(posmod(seed / 29, 96)) if motif == "crown" else float(96 + posmod(seed / 29, 144)),
		"skyline_height": 690.0 if motif == "crown" else 700.0,
		"rib_offset": float(posmod(seed / 61, 160)),
		"tint": float(posmod(seed / 101, 5)) * .015,
	}

static func bay_kind(profile: Dictionary, column: int, row: int) -> String:
	var types: Array = profile.get("bay_types", ["duct", "window", "shutter"])
	if column == 0 and row == 0:
		return str(types[0])
	var code := posmod(int(profile.get("seed", 0)) + column * 37 + row * 71 + column * column * 11, 997)
	# Equipment has breathing room: every bay is not another active machine.
	if code % 7 == 0:
		return "blank"
	return str(types[code % types.size()])
