# =============================================================================
# CondicionDistanciaObjetivo.gd  (Condición utilitaria)
#
# Compara la distancia entre el agente y el objetivo en memoria.
# No requiere que la distancia esté almacenada: la calcula en cada tick.
# Retorna FALLIDO si no hay agente u objetivo en la memoria.
# =============================================================================
class_name CondicionDistanciaObjetivo
extends Condicion

enum Comparacion {
	MENOR_QUE,    ## dist < umbral
	MENOR_IGUAL,  ## dist <= umbral
	MAYOR_QUE,    ## dist > umbral
	MAYOR_IGUAL,  ## dist >= umbral
}

@export_group("Configuración")
@export var comparacion: Comparacion = Comparacion.MENOR_IGUAL
@export var umbral: float = 150.0
## Clave en memoria para el objetivo. Por defecto "objetivo".
@export var clave_objetivo: String = "objetivo"


func _on_ejecutar() -> Estado:
	var agente  := _memoria.obtener("agente")  as Node2D
	var objetivo := _memoria.obtener(clave_objetivo) as Node2D

	if not agente or not objetivo:
		return Estado.FALLIDO

	var dist: float = agente.global_position.distance_to(objetivo.global_position)

	if debug_activo:
		print_rich(
			"[color=yellow][BT 📏][/color] CondicionDistancia [b]%s[/b]: dist=%.1f %s %.1f → %s"
			% [nombre_nodo, dist, _simbolo(), umbral,
			   "EXITOSO" if _evaluar(dist) else "FALLIDO"]
		)

	return Estado.EXITOSO if _evaluar(dist) else Estado.FALLIDO


func _evaluar(dist: float) -> bool:
	match comparacion:
		Comparacion.MENOR_QUE:   return dist <  umbral
		Comparacion.MENOR_IGUAL: return dist <= umbral
		Comparacion.MAYOR_QUE:   return dist >  umbral
		Comparacion.MAYOR_IGUAL: return dist >= umbral
	return false


func _simbolo() -> String:
	match comparacion:
		Comparacion.MENOR_QUE:   return "<"
		Comparacion.MENOR_IGUAL: return "<="
		Comparacion.MAYOR_QUE:   return ">"
		Comparacion.MAYOR_IGUAL: return ">="
	return "?"
