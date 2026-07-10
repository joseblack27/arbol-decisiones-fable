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
	# En red: si el jugador-objetivo se desconecta a mitad de combate, su
	# nodo se libera (ServidorDedicado._al_desconectar) pero la memoria del
	# BT puede seguir apuntando a esa referencia — castear un Object liberado
	# con "as" revienta con "Trying to cast a freed object", por eso hay que
	# validar ANTES de castear (mismo criterio que AccionAtacar).
	var agente_raw = _memoria.obtener("agente")
	var objetivo_raw = _memoria.obtener(clave_objetivo)
	if not is_instance_valid(agente_raw) or not is_instance_valid(objetivo_raw):
		return Estado.FALLIDO
	var agente := agente_raw as Node2D
	var objetivo := objetivo_raw as Node2D

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
