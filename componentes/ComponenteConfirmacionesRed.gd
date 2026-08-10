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


## Confirmación del servidor tras TiendaComponente._pedir_comprar_red — el
## cliente dueño aplica el mismo ítem a su copia de InventarioComponente y
## fija el saldo de créditos EXACTO que ya descontó el servidor (no lo
## vuelve a restar de su lado, evita cualquier desfasaje).
@rpc("authority", "reliable")
func _recibir_compra_red(ruta_item: String, cantidad: int, nuevos_creditos: int) -> void:
	var item := load(ruta_item) as DatosItem
	if item == null:
		return
	var inventario := get_parent().get_node_or_null("InventarioComponente")
	if inventario:
		inventario.agregar_item(item, cantidad)
	var creditos := get_parent().get_node_or_null("CreditosComponente") as CreditosComponente
	if creditos:
		creditos._fijar_creditos_local(nuevos_creditos)


## Confirmación del servidor tras TiendaComponente._pedir_vender_red — el
## cliente dueño saca la misma cantidad de su copia de InventarioComponente
## y fija el saldo de créditos EXACTO que ya sumó el servidor.
@rpc("authority", "reliable")
func _recibir_venta_red(ruta_item: String, cantidad: int, nuevos_creditos: int) -> void:
	var inventario := get_parent().get_node_or_null("InventarioComponente")
	if inventario:
		for item: DatosItem in inventario.items:
			if item.id_recurso == ruta_item:
				inventario.quitar_cantidad(item, cantidad)
				break
	var creditos := get_parent().get_node_or_null("CreditosComponente") as CreditosComponente
	if creditos:
		creditos._fijar_creditos_local(nuevos_creditos)


## Confirmación del servidor tras MisionesComponente._pedir_aceptar_mision_
## red — el cliente dueño aplica el mismo progreso inicial a su propia copia.
@rpc("authority", "reliable")
func _recibir_mision_aceptada_red(id_mision: String) -> void:
	var misiones := get_parent().get_node_or_null("MisionesComponente") as MisionesComponente
	if misiones:
		misiones._aceptar_mision_por_id(id_mision)


## Confirmación del servidor tras MisionesComponente._pedir_completar_
## mision_red — el cliente dueño aplica las mismas recompensas a su propia
## copia (mismo motivo que _recibir_botin_red/_recibir_xp_red: necesita su
## propio estado actualizado, no solo el del servidor).
@rpc("authority", "reliable")
func _recibir_mision_completada_red(id_mision: String) -> void:
	var misiones := get_parent().get_node_or_null("MisionesComponente") as MisionesComponente
	if misiones:
		misiones._completar_mision_por_id(id_mision)


## Confirmación del servidor tras acreditar un objetivo de misión (matar/
## recolectar) — ver MisionesComponente._avisar_progreso_al_dueño.
@rpc("authority", "reliable")
func _recibir_progreso_mision_red(id_mision: String, id_objetivo: String, actual: int) -> void:
	var misiones := get_parent().get_node_or_null("MisionesComponente") as MisionesComponente
	if misiones:
		misiones._aplicar_progreso_local(id_mision, id_objetivo, actual)


## Confirmación del servidor tras MisionesComponente._pedir_abandonar_
## mision_red — el cliente dueño borra la misma entrada en su propia copia.
@rpc("authority", "reliable")
func _recibir_mision_abandonada_red(id_mision: String) -> void:
	var misiones := get_parent().get_node_or_null("MisionesComponente") as MisionesComponente
	if misiones:
		misiones._abandonar_mision_local(id_mision)
