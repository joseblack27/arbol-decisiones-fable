extends Node
class_name ComponenteConfirmacionesRed
## Ecos de confirmación que el SERVIDOR manda de vuelta al cliente dueño
## tras aplicar un cambio de estado real (botín, XP, pasiva desbloqueada,
## mejora comprada, puntos reiniciados) — el cliente dueño necesita su
## PROPIA copia de estos componentes actualizada para que la UI/predicción
## local coincida con lo que el servidor ya aplicó de verdad.
##
## Separado de Jugador.gd (que orquesta identidad/movimiento/muerte —mucho
## más acoplado a estado compartido entre sí) porque estos 6 son
## independientes entre sí y de todo lo demás: cada uno solo busca UN
## componente hermano y le pide que aplique el mismo cambio que ya ocurrió
## del lado del servidor. get_parent() en vez de get_node("../Xyz") porque
## este nodo siempre cuelga directo de Jugador (ver Jugador.tscn).


## Fase 4 del plan de multijugador: el SERVIDOR ya le dio este botín de
## verdad a la copia autoritativa (ver Enemigo._otorgar_item_al_atacante) —
## esto es el aviso al cliente dueño para que su copia espejo (inventario
## que ve en su propia UI) se entere. "authority" = solo el servidor puede
## llamarlo.
@rpc("authority", "reliable")
func _recibir_botin_red(ruta_item: String, cantidad: int) -> void:
	var item := load(ruta_item) as DatosItem
	if item == null:
		return
	var inventario := get_parent().get_node_or_null("InventarioComponente")
	if inventario:
		inventario.agregar_item(item, cantidad)


@rpc("authority", "reliable")
func _recibir_xp_red(cantidad: int) -> void:
	var experiencia := get_parent().get_node_or_null("ExperienciaComponente")
	if experiencia:
		experiencia.agregar_xp(cantidad)


## Confirmación del servidor tras InventarioComponente._pedir_desbloqueo_
## pasiva_red — el cliente dueño necesita su PROPIA instancia de
## PasivaBase (no solo la del servidor) para que la predicción visual de
## la pasiva funcione, mismo motivo que _recibir_xp_red.
@rpc("authority", "reliable")
func _recibir_pasiva_red(ruta_escena: String) -> void:
	var pasivas := get_parent().get_node_or_null("PasivasComponente")
	if pasivas:
		pasivas.desbloquear_gatillo(ruta_escena)


## Confirmación del servidor tras MejorasComponente._pedir_gastar_pasiva_
## red — el cliente dueño aplica el mismo gasto en su propia copia (mismo
## motivo que _recibir_pasiva_red: necesita su propio estado actualizado,
## no solo el del servidor).
@rpc("authority", "reliable")
func _recibir_mejora_pasiva_red(ruta_pasiva: String) -> void:
	var mejoras := get_parent().get_node_or_null("MejorasComponente")
	if mejoras:
		mejoras._gastar_en_pasiva_por_ruta(ruta_pasiva)


@rpc("authority", "reliable")
func _recibir_mejora_habilidad_red(ruta_habilidad: String) -> void:
	var mejoras := get_parent().get_node_or_null("MejorasComponente")
	if mejoras:
		mejoras._gastar_en_habilidad_por_ruta(ruta_habilidad)


## Mismo motivo que _recibir_mejora_pasiva_red: el dueño necesita su
## propio estado actualizado, no solo el del servidor (ver
## MejorasComponente.reiniciar_puntos).
@rpc("authority", "reliable")
func _recibir_reinicio_puntos_red() -> void:
	var mejoras := get_parent().get_node_or_null("MejorasComponente")
	if mejoras:
		mejoras._reiniciar_puntos_local()
