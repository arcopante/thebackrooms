extends Node

const LEVELS: Array[Dictionary] = [
	{
		"room_count": 10,
		"ambient_light_energy": 0.12,
		"flicker_probability": 0.1,
		"off_light_probability": 0.25,
		"has_windows": true,
		"entity_count": 0,
		"hazard_types": ["WET_FLOOR"],
		"hazard_count_min": 0,
		"hazard_count_max": 2,
		"fog_density": 0.02,
		"description": "Moqueta amarilla desgastada, papel pintado amarillo, algunas ventanas"
	},
	{
		"room_count": 12,
		"ambient_light_energy": 0.08,
		"flicker_probability": 0.2,
		"off_light_probability": 0.25,
		"has_windows": false,
		"entity_count": 5,
		"hazard_types": ["MOLD_ZONE"],
		"hazard_count_min": 1,
		"hazard_count_max": 3,
		"fog_density": 0.04,
		"description": "Moqueta beige, pintura descascarillada blanca"
	},
	{
		"room_count": 14,
		"ambient_light_energy": 0.06,
		"flicker_probability": 0.35,
		"off_light_probability": 0.65,
		"has_windows": false,
		"entity_count": 4,
		"hazard_types": ["WET_FLOOR", "MOLD_ZONE"],
		"hazard_count_min": 2,
		"hazard_count_max": 4,
		"fog_density": 0.06,
		"description": "Linóleo sucio, azulejos blancos"
	},
	{
		"room_count": 16,
		"ambient_light_energy": 0.04,
		"flicker_probability": 0.5,
		"off_light_probability": 0.50,
		"has_windows": false,
		"entity_count": 3,
		"hazard_types": ["ELECTRICAL", "MOLD_ZONE"],
		"hazard_count_min": 2,
		"hazard_count_max": 5,
		"fog_density": 0.08,
		"description": "Cemento agrietado, paredes húmedas"
	},
	{
		"room_count": 18,
		"ambient_light_energy": 0.02,
		"flicker_probability": 0.65,
		"off_light_probability": 0.65,
		"has_windows": false,
		"entity_count": 3,
		"hazard_types": ["VOID_ZONE", "ELECTRICAL"],
		"hazard_count_min": 3,
		"hazard_count_max": 5,
		"fog_density": 0.12,
		"description": "Metal oxidado, casi sin luz"
	},
	{
		"room_count": 20,
		"ambient_light_energy": 0.0,
		"flicker_probability": 0.8,
		"off_light_probability": 0.80,
		"has_windows": false,
		"entity_count": 2,
		"hazard_types": ["WET_FLOOR", "MOLD_ZONE", "VOID_ZONE", "ELECTRICAL"],
		"hazard_count_min": 4,
		"hazard_count_max": 5,
		"fog_density": 0.18,
		"description": "Hormigón negro, solo la linterna ilumina"
	}
]

static func get_level(level_index: int) -> Dictionary:
	if level_index < 0 or level_index >= LEVELS.size():
		return LEVELS[0]
	return LEVELS[level_index]
