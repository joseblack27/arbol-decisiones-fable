extends Node
class_name ExperienciaComponente
## ExperienciaComponente — la XP de ESTE jugador (Fase 1 del plan de
## migración a multijugador). Antes vivía en el autoload GestorExperiencia;
## ver ese archivo, que ahora es una fachada de compatibilidad.

var xp_total: int = 0


func agregar_xp(cantidad: int) -> void:
	if cantidad <= 0:
		return
	xp_total += cantidad
	BusEventos.xp_agregada.emit(cantidad, xp_total)
