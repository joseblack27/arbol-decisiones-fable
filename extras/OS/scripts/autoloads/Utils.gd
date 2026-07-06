extends Node

func snake_to_pascal(text: String) -> String:
	var parts = text.split("_")
	var result := ""

	for p in parts:
		if p.length() > 0:
			result += p.capitalize()

	return result
