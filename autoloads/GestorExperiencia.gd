extends Node
## GestorExperiencia.gd — Autoload: acumula la experiencia (XP) del jugador.
## Todavía sin tabla de niveles (sin umbrales, sin subir de nivel) — por ahora
## solo guarda el total y avisa por BusEventos cada vez que sube, para que la
## UI (o lo que se agregue después) pueda reaccionar.

var xp_total: int = 0


func agregar_xp(cantidad: int) -> void:
	if cantidad <= 0:
		return
	xp_total += cantidad
	BusEventos.xp_agregada.emit(cantidad, xp_total)
