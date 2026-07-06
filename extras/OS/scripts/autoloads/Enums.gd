extends Node

class Inventory:
	enum TypeItem {
		NONE,
		ALL,
		CONSUMABLE,
		EQUIPPABLE,
		RESOURCE,
		QUEST,
		WEAPON
	}

	enum TypeItemEquippable {
		NONE,
		HELMET,
		BODY,
		PANT,
		BOOTS,
		NECK,
		RING,
		BELT,
		WEAPON,
		SHIELD
	}

class Skill:
	enum TypeLaunch {
		PROYECTIL,
		AREA
	}
	
	enum ColorDamage {
		EARTH,
		FIRE,
		WATER,
		WIND
	}

	const color_damage_value := {
		ColorDamage.EARTH: "#905010",
		ColorDamage.FIRE: "red",
		ColorDamage.WATER: "#00c4ff",
		ColorDamage.WIND: "#008f39"
	}

class Event:
	enum Type {
		WORLD_BOSS,
		DUNGEON,
		INVASION,
		WORLD_CHANGE,
		FACTION
	}

	enum Status {
		UPCOMING,
		ACTIVE,
		COMPLETED,
		FAILED,
		CANCELLED
	}

class Mission:
	enum Type {
		HISTORIA,
		SECUNDARIA,
		EVENTO,
		DIARIA
	}

	enum Status {
		LOCKED,
		AVAILABLE,
		IN_PROGRESS,
		COMPLETED,
		FAILED
	}
	
	func _get_type_text(type: Mission.Type) -> String:
		match type:
			Mission.Type.HISTORIA: return "Historia"
			Mission.Type.SECUNDARIA: return "Secundaria"
			Mission.Type.EVENTO: return "Evento"
			Mission.Type.DIARIA: return "Diaria"
		return "-"

class ColorUI:
	enum UI {
		GREEN_FLUORESCENT,
		BACK_WHITE,
		LINE_WHITE,
		
		BLACK,
		BLUE,
		CYAN,
		GREEN,
		PURPLE,
		RED,
		WHITE,
		YELLOW,
		BRIGHT_BLACK,
		BRIGHT_BLUE,
		BRIGHT_CYAN,
		BRIGHT_GREEN,
		BRIGHT_PURPLE,
		BRIGHT_RED,
		BRIGHT_WHITE,
		BRIGHT_YELLOW
	}
	
	const color_ui_value := {
		UI.GREEN_FLUORESCENT: "38ff14",
		UI.BACK_WHITE: "f0f0f0",
		UI.LINE_WHITE: "eaeaea10",
		
		UI.BLACK: "0C0C0C",
		UI.BLUE: "0037DA",
		UI.CYAN: "3A96DD",
		UI.GREEN: "13A10E",
		UI.PURPLE: "881798",
		UI.RED: "C50F1F",
		UI.WHITE: "CCCCCC",
		UI.YELLOW: "C19C00",
		UI.BRIGHT_BLACK: "767676",
		UI.BRIGHT_BLUE: "3B78FF",
		UI.BRIGHT_CYAN: "61D6D6",
		UI.BRIGHT_GREEN: "16C60C",
		UI.BRIGHT_PURPLE: "B4009E",
		UI.BRIGHT_RED: "E74856",
		UI.BRIGHT_WHITE: "F2F2F2",
		UI.BRIGHT_YELLOW: "F9F1A5"
	}
