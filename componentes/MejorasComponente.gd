extends Node
class_name MejorasComponente
## Puntos de mejora de ESTE jugador: se ganan por nivel de personaje
## (DERIVADOS, nunca guardados como número aparte — ver
## puntos_disponibles(), mismo criterio que vida_maxima/energia_maxima) y
## se gastan en subir tiers de pasivas de estadística (ver
## ExperienciaComponente.pasivas_stat) o niveles de habilidades activas
## equipadas (ver HabilidadBase.aplicar_nivel_mejora). Cuelga del Jugador,
## mismo lugar que PasivasComponente/SlotHabilidades.

const PUNTOS_POR_NIVEL := 1

## resource_path de PasivaStatDesbloqueo -> tiers comprados (ADEMÁS del
## tier gratis que ya da el desbloqueo automático por nivel — ver
## ExperienciaComponente._aplicar_crecimiento_nivel, sin cambios).
var niveles_pasivas: Dictionary = {}
## resource_path de DatosHabilidad -> niveles comprados. El nivel_mejora
## real de la instancia equipada = 1 + este valor (ver
## HabilidadBase.aplicar_nivel_mejora).
var niveles_habilidades: Dictionary = {}
## Único dato que de verdad hay que guardar: los puntos DISPONIBLES se
## derivan solos de nivel * PUNTOS_POR_NIVEL - esto.
var puntos_gastados: int = 0


func puntos_disponibles() -> int:
	var padre := get_parent()
	var experiencia = padre.get_node_or_null("ExperienciaComponente") if padre else null
	var nivel: int = experiencia.nivel if experiencia else 1
	return nivel * PUNTOS_POR_NIVEL - puntos_gastados


func nivel_pasiva(ruta: String) -> int:
	return niveles_pasivas.get(ruta, 0)


func nivel_habilidad(ruta: String) -> int:
	return niveles_habilidades.get(ruta, 0)


## API pública: gastar un punto en una pasiva de estadística, por
## resource_path — mismo patrón que InventarioComponente
## ._pedir_desbloqueo_pasiva: en red, el cliente solo pide (el servidor es
## quien de verdad tiene la última palabra sobre puntos/tope/nivel);
## fuera de red o ya siendo el servidor, se aplica acá mismo.
func gastar_en_pasiva(ruta_pasiva: String) -> void:
	if Utils.en_red() and not multiplayer.is_server():
		rpc_id(1, "_pedir_gastar_pasiva_red", ruta_pasiva)
		return
	_gastar_en_pasiva_por_ruta(ruta_pasiva)


func gastar_en_habilidad(ruta_habilidad: String) -> void:
	if Utils.en_red() and not multiplayer.is_server():
		rpc_id(1, "_pedir_gastar_habilidad_red", ruta_habilidad)
		return
	_gastar_en_habilidad_por_ruta(ruta_habilidad)


func _gastar_en_pasiva_por_ruta(ruta_pasiva: String) -> bool:
	var padre := get_parent()
	if padre == null:
		return false
	var experiencia := padre.get_node_or_null("ExperienciaComponente")
	if experiencia == null:
		return false
	for pasiva in experiencia.pasivas_stat:
		if pasiva and pasiva.resource_path == ruta_pasiva:
			return _gastar_en_pasiva_local(pasiva)
	return false


func _gastar_en_habilidad_por_ruta(ruta_habilidad: String) -> bool:
	var datos: DatosHabilidad = load(ruta_habilidad) as DatosHabilidad if ruta_habilidad != "" else null
	return _gastar_en_habilidad_local(datos)


## SERVIDOR: mismas verificaciones de dueño que el resto de los RPC "pedir"
## del proyecto (ver InventarioComponente._pedir_desbloqueo_pasiva_red). Si
## el gasto se concreta, confirma de vuelta al cliente dueño — necesita su
## PROPIA instancia/estado actualizado (no solo el del servidor), mismo
## motivo que _recibir_pasiva_red/_recibir_xp_red en Jugador.gd.
@rpc("any_peer", "reliable")
func _pedir_gastar_pasiva_red(ruta_pasiva: String) -> void:
	if not multiplayer.is_server():
		return
	var jugador := get_parent()
	if not jugador or not ("peer_id_dueño" in jugador):
		return
	if multiplayer.get_remote_sender_id() != jugador.peer_id_dueño:
		return
	if _gastar_en_pasiva_por_ruta(ruta_pasiva):
		var confirmaciones := jugador.get_node_or_null("ComponenteConfirmacionesRed")
		if confirmaciones:
			confirmaciones.rpc_id(jugador.peer_id_dueño, "_recibir_mejora_pasiva_red", ruta_pasiva)


@rpc("any_peer", "reliable")
func _pedir_gastar_habilidad_red(ruta_habilidad: String) -> void:
	if not multiplayer.is_server():
		return
	var jugador := get_parent()
	if not jugador or not ("peer_id_dueño" in jugador):
		return
	if multiplayer.get_remote_sender_id() != jugador.peer_id_dueño:
		return
	if _gastar_en_habilidad_por_ruta(ruta_habilidad):
		var confirmaciones := jugador.get_node_or_null("ComponenteConfirmacionesRed")
		if confirmaciones:
			confirmaciones.rpc_id(jugador.peer_id_dueño, "_recibir_mejora_habilidad_red", ruta_habilidad)


## Aplica el gasto DE VERDAD — reusado por gastar_en_pasiva() (fuera de
## red o ya siendo el servidor) y por el flujo RPC de arriba. true si el
## gasto se concretó.
func _gastar_en_pasiva_local(pasiva: PasivaStatDesbloqueo) -> bool:
	if pasiva == null or pasiva.bono == null:
		return false
	var ruta := pasiva.resource_path
	var tier_actual: int = niveles_pasivas.get(ruta, 0)
	if tier_actual >= pasiva.max_niveles:
		return false
	if puntos_disponibles() < pasiva.costo_puntos_por_nivel:
		return false
	var padre := get_parent()
	if padre == null:
		return false
	var experiencia := padre.get_node_or_null("ExperienciaComponente")
	if experiencia and experiencia.nivel < pasiva.nivel_requerido:
		return false
	var atributos := padre.get_node_or_null("AtributosComponente") as AtributosComponente
	if atributos == null:
		return false
	atributos.agregar_crecimiento_permanente(pasiva.bono)
	niveles_pasivas[ruta] = tier_actual + 1
	puntos_gastados += pasiva.costo_puntos_por_nivel
	BusEventos.mejora_comprada.emit(padre, "pasiva", pasiva.nombre)
	return true


## Análogo para habilidades activas — el costo/tope ahora son POR-RECURSO
## (ver DatosHabilidad.escalado/EscaladoHabilidad), no globales. Sin
## escalado configurado, la habilidad simplemente no es mejorable todavía.
func _gastar_en_habilidad_local(datos: DatosHabilidad) -> bool:
	if datos == null or datos.escalado == null:
		return false
	var ruta := datos.resource_path
	var nivel_actual: int = niveles_habilidades.get(ruta, 0)
	if 1 + nivel_actual >= datos.escalado.nivel_maximo:
		return false
	if puntos_disponibles() < datos.escalado.costo_puntos_por_nivel:
		return false
	var padre := get_parent()
	if padre == null:
		return false
	var experiencia := padre.get_node_or_null("ExperienciaComponente")
	if experiencia and experiencia.nivel < datos.nivel:
		return false
	var nivel_nuevo := nivel_actual + 1
	niveles_habilidades[ruta] = nivel_nuevo
	puntos_gastados += datos.escalado.costo_puntos_por_nivel
	# Si está equipada AHORA MISMO en algún slot, aplicar el nuevo nivel a
	# la instancia viva — sin esto, el gasto se descontaría pero la
	# habilidad seguiría pegando como antes hasta volver a equiparla (ver
	# SlotHabilidades._instanciar, que también lee esto al equipar).
	var slots := padre.get_node_or_null("SlotHabilidades")
	if slots:
		for i in slots.total_slots:
			var datos_equipados: DatosHabilidad = slots.obtener_datos(i)
			if datos_equipados and datos_equipados.resource_path == ruta:
				var instancia: HabilidadBase = slots.obtener(i)
				if instancia:
					instancia.aplicar_nivel_mejora(1 + nivel_nuevo)
	BusEventos.mejora_comprada.emit(padre, "habilidad", datos.nombre)
	return true


## API pública: respec completo — devuelve TODOS los puntos gastados
## (pasivas de estadística Y habilidades activas) a "disponibles", pedido
## del usuario ("un botón al lado de los puntos disponibles para
## reiniciarlos"). Mismo patrón cliente-pide/servidor-decide que gastar_en_
## pasiva/gastar_en_habilidad.
func reiniciar_puntos() -> void:
	if Utils.en_red() and not multiplayer.is_server():
		rpc_id(1, "_pedir_reiniciar_puntos_red")
		return
	_reiniciar_puntos_local()


@rpc("any_peer", "reliable")
func _pedir_reiniciar_puntos_red() -> void:
	if not multiplayer.is_server():
		return
	var jugador := get_parent()
	if not jugador or not ("peer_id_dueño" in jugador):
		return
	if multiplayer.get_remote_sender_id() != jugador.peer_id_dueño:
		return
	if _reiniciar_puntos_local():
		var confirmaciones := jugador.get_node_or_null("ComponenteConfirmacionesRed")
		if confirmaciones:
			confirmaciones.rpc_id(jugador.peer_id_dueño, "_recibir_reinicio_puntos_red")


## Aplica el reinicio DE VERDAD — reusado por reiniciar_puntos() (fuera de
## red o ya siendo el servidor) y por la confirmación RPC de vuelta al
## dueño (ver Jugador._recibir_reinicio_puntos_red). true si había algo que
## reiniciar.
func _reiniciar_puntos_local() -> bool:
	if puntos_gastados <= 0:
		return false
	var padre := get_parent()
	if padre == null:
		return false
	niveles_pasivas.clear()
	niveles_habilidades.clear()
	puntos_gastados = 0

	# Deshace el bono acumulado de las pasivas — agregar_crecimiento_
	# permanente() es puramente ADITIVO, así que vaciar niveles_pasivas acá
	# arriba no le resta nada a AtributosComponente por sí solo. Mismo
	# mecanismo que ya usa una reconexión para volver a la línea de base y
	# reaplicar SOLO el crecimiento por NIVEL (ver ExperienciaComponente.
	# restaurar_xp): acá no hay ningún tier de pasiva que reaplicar después
	# porque recién se vaciaron, así que el resultado es "como si nunca se
	# hubiera gastado nada", sin tocar el crecimiento ganado por XP.
	var experiencia := padre.get_node_or_null("ExperienciaComponente")
	if experiencia:
		experiencia.restaurar_xp(experiencia.xp_total)

	# Habilidades EQUIPADAS ahora mismo: sin esto seguían pegando con su
	# nivel viejo hasta volver a equiparlas (mismo motivo que _gastar_en_
	# habilidad_local reaplica al instante si ya está equipada).
	var slots := padre.get_node_or_null("SlotHabilidades")
	if slots:
		for i in slots.total_slots:
			var instancia: HabilidadBase = slots.obtener(i)
			if instancia:
				instancia.aplicar_nivel_mejora(1)

	BusEventos.mejora_comprada.emit(padre, "reinicio", "")
	return true


## Reaplica los tiers de pasiva YA COMPRADOS — necesario tras
## ExperienciaComponente.restaurar_xp() (reconexión), que resetea
## AtributosComponente a la línea de base y reaplica el crecimiento por
## NIVEL desde cero, pero no sabe nada de los tiers comprados con puntos
## (son independientes del nivel de personaje). [tabla_pasivas] es
## ExperienciaComponente.pasivas_stat del mismo jugador.
func reaplicar_pasivas_compradas(tabla_pasivas: Array) -> void:
	var padre := get_parent()
	if padre == null:
		return
	var atributos := padre.get_node_or_null("AtributosComponente") as AtributosComponente
	if atributos == null:
		return
	for pasiva in tabla_pasivas:
		if not pasiva or not pasiva.bono:
			continue
		var tiers: int = niveles_pasivas.get(pasiva.resource_path, 0)
		for i in tiers:
			atributos.agregar_crecimiento_permanente(pasiva.bono)
