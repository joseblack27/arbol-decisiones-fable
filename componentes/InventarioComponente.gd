extends Node
class_name InventarioComponente
## InventarioComponente — el inventario de ESTE jugador (Fase 1 del plan de
## migración a multijugador: cada jugador tiene el suyo propio, en vez de
## un único inventario global compartido).
##
## Misma lógica que tenía GestorInventario (autoload) — se movió acá tal
## cual, dato incluido. GestorInventario.gd sigue existiendo como fachada de
## compatibilidad (ver ese archivo) para no tener que tocar todo el código
## que ya lo usa (PanelInventario, Enemigo, GestorGuardado...).

## DatosItem.type == 3 ("equipable"): estos nunca se apilan, cada uno es
## una entrada propia (a futuro podrían llevar stats distintos por copia).
const TYPE_EQUIPABLE := 3

var items: Array[DatosItem] = []


## Añade un ítem al inventario. Si es apilable (no equipable) y ya hay uno
## igual (mismo nombre y tipo), suma cantidades en vez de crear una entrada
## nueva. "cantidad" por defecto usa la del propio recurso (item.quantity).
## Siempre duplica el recurso antes de guardarlo: el mismo DatosItem .tres
## puede estar referenciado en varias tablas de botín a la vez, y mutar su
## "quantity" directamente corrompería ese recurso compartido.
##
## silencioso=true omite BusEventos.item_agregado (no dispara el popup de
## "obtuviste X" en PanelNotificacionesLoot): lo usa GestorGuardado al
## restaurar una partida — esos ítems ya eran tuyos, no son botín nuevo, y
## sin este flag el jugador veía una ráfaga de notificaciones de TODO su
## inventario guardado apenas cargaba (reportado por el usuario).
func agregar_item(item: DatosItem, cantidad: int = -1, silencioso: bool = false) -> void:
	if item == null:
		return
	var cantidad_real := cantidad if cantidad > 0 else item.quantity

	if item.type != TYPE_EQUIPABLE:
		for existente in items:
			if existente.name == item.name and existente.type == item.type:
				existente.quantity += cantidad_real
				if not silencioso:
					BusEventos.item_agregado.emit(existente, cantidad_real)
					_notificar_recolectar(item)
				BusEventos.inventario_cambiado.emit()
				return

	var copia := item.duplicate() as DatosItem
	copia.quantity = cantidad_real
	# .duplicate() no conserva resource_path — estampar id_recurso ahora
	# (mientras "item", el original, todavía lo tiene) es la única ventana
	# para no perderlo. "item.id_recurso" de respaldo cubre el caso de
	# GestorGuardado.cargar_partida(), que ya pasa un item recién cargado
	# desde disco vía load(), con resource_path pero sin necesidad de volver
	# a resolverlo.
	copia.id_recurso = item.id_recurso if item.id_recurso != "" else item.resource_path
	items.append(copia)
	if not silencioso:
		BusEventos.item_agregado.emit(copia, cantidad_real)
		_notificar_recolectar(item)
	BusEventos.inventario_cambiado.emit()


## Objetivos de misión tipo RECOLECTAR (ver MisionesComponente.notificar_
## recolectar) — gateado por el mismo "not silencioso" que BusEventos.
## item_agregado: al restaurar una partida guardada estos ítems ya eran
## tuyos, no son botín nuevo, así que no deben re-acreditar progreso.
func _notificar_recolectar(item: DatosItem) -> void:
	var misiones := get_parent().get_node_or_null("MisionesComponente") if get_parent() else null
	if misiones:
		misiones.notificar_recolectar(item)


func quitar_item(item: DatosItem) -> void:
	items.erase(item)
	BusEventos.inventario_cambiado.emit()


func tiene_item(nombre: String) -> bool:
	for i in items:
		if i.name == nombre:
			return true
	return false


## Usa un ítem consumible: aplica su efecto y saca UNA unidad del stack
## (el ítem entero si quantity ya era 1). La quita local siempre — mismo
## nivel de confianza que equipar (ver PanelInventario._equip_item, tampoco
## pasa por RPC). El efecto de curación SÍ es server-autoritativo (mismo
## motivo que VidaComponente.quitar_vida/agregar_vida): sin eso, un cliente
## podría curarse local mintiéndole el HP a los demás.
func usar_item(item: DatosItem) -> void:
	if item == null or not item.can_use:
		return
	# No desperdiciar consumibles que no aportarían nada: con la vida llena
	# una poción no se gasta, ni una jeringa con la energía llena. Un ítem
	# mixto (cura + energía) se usa si AL MENOS una de las dos falta.
	if not _consumible_util(item):
		return
	quitar_cantidad(item, 1)
	if item.curacion > 0.0:
		_pedir_curacion(item.curacion)
	if item.energia > 0.0:
		_pedir_energia(item.energia)
	if item.experiencia > 0:
		_pedir_experiencia(item.experiencia)
	if item.escena_pasiva != null:
		_pedir_desbloqueo_pasiva(item.escena_pasiva.resource_path)


## true si usar este ítem tendría algún efecto real ahora mismo. Los ítems
## sin efectos conocidos (curacion y energia en 0) se consumen como siempre
## — no hay forma de saber si "sirven", mejor no bloquearlos.
## El chequeo usa el espejo local de vida/energía (en red llegan replicados
## del servidor): puede desfasarse unos puntos por latencia, pero el peor
## caso es gastar una poción con 99.9% de vida — aceptable.
func _consumible_util(item: DatosItem) -> bool:
	if item.curacion <= 0.0 and item.energia <= 0.0:
		return true
	var padre := get_parent()
	if padre == null:
		return true
	if item.curacion > 0.0:
		var vida := padre.get_node_or_null("VidaComponente") as VidaComponente
		if vida == null or vida.obtener_vida() < vida.obtener_vida_maxima():
			return true
	if item.energia > 0.0:
		var energia := padre.get_node_or_null("EnergiaComponente") as EnergiaComponente
		if energia == null or not energia.tiene_energia(energia.energia_maxima):
			return true
	return false


## Saca "cantidad" unidades de un ítem apilado — generaliza lo que antes
## era _quitar_una_unidad (cantidad=1, único caso que existía) para que
## TiendaComponente.vender_item() pueda sacar de a varias unidades en una
## sola operación. Siempre decrementa quantity de verdad (nunca la deja
## "atascada" en 1) para que cualquiera que solo tenga una referencia al
## ítem — como una casilla de la barra rápida de consumibles, que lo saca
## de "items" al soltarlo ahí — pueda saber si se agotó mirando
## item.quantity <= 0, sin depender de si sigue en esta lista o no.
## items.erase() es un no-op inofensivo si el ítem no está acá (ya vive en
## una casilla rápida). false sin tocar nada si no hay tanto como se pide
## (venta/uso a medias no debería pasar nunca).
func quitar_cantidad(item: DatosItem, cantidad: int) -> bool:
	if item == null or cantidad <= 0 or item.quantity < cantidad:
		return false
	item.quantity -= cantidad
	if item.quantity <= 0:
		items.erase(item)
	BusEventos.inventario_cambiado.emit()
	return true


func _pedir_curacion(cantidad: float) -> void:
	if Utils.en_red() and not multiplayer.is_server():
		rpc_id(1, "_pedir_curacion_red", cantidad)
		return
	_curar_local(cantidad)


func _curar_local(cantidad: float) -> void:
	var vida := get_parent().get_node_or_null("VidaComponente") as VidaComponente
	if vida:
		vida.agregar_vida(cantidad)


## SERVIDOR: el dueño de este inventario pide curarse (poción, botiquín...)
## — se verifica que quien llama sea de verdad el dueño (mismo criterio que
## HabilidadBase._activar_red) antes de aplicar la curación real.
@rpc("any_peer", "reliable")
func _pedir_curacion_red(cantidad: float) -> void:
	if not multiplayer.is_server():
		return
	var jugador := get_parent()
	if not jugador or not ("peer_id_dueño" in jugador):
		return
	if multiplayer.get_remote_sender_id() != jugador.peer_id_dueño:
		return
	_curar_local(cantidad)


## Espejo exacto del camino de curación, para consumibles de energía
## (jeringa de adrenalina): en red la energía real la decide el servidor
## (EnergiaComponente ya la replica solo hacia el cliente).
func _pedir_energia(cantidad: float) -> void:
	if Utils.en_red() and not multiplayer.is_server():
		rpc_id(1, "_pedir_energia_red", cantidad)
		return
	_energia_local(cantidad)


func _energia_local(cantidad: float) -> void:
	var energia := get_parent().get_node_or_null("EnergiaComponente") as EnergiaComponente
	if energia:
		energia.agregar_energia(cantidad)


## SERVIDOR: mismas verificaciones de dueño que _pedir_curacion_red.
@rpc("any_peer", "reliable")
func _pedir_energia_red(cantidad: float) -> void:
	if not multiplayer.is_server():
		return
	var jugador := get_parent()
	if not jugador or not ("peer_id_dueño" in jugador):
		return
	if multiplayer.get_remote_sender_id() != jugador.peer_id_dueño:
		return
	_energia_local(cantidad)


## Consumibles que dan XP (tickets) — a diferencia de vida/energía (que se
## replican solas cada tanto, ver VidaComponente/EnergiaComponente),
## ExperienciaComponente no tiene ningún canal de réplica periódica: el
## único aviso que le llega al cliente dueño de un cambio de XP decidido
## en el servidor es un RPC explícito (mismo que ya manda Enemigo._otorgar
## _xp() al matar un mob, vía ComponenteConfirmacionesRed) — sin reenviarlo
## acá también, el cliente que usó el ítem vería gastarse el ticket sin que
## su XP subiera nunca en pantalla.
func _pedir_experiencia(cantidad: int) -> void:
	if Utils.en_red() and not multiplayer.is_server():
		rpc_id(1, "_pedir_experiencia_red", cantidad)
		return
	_experiencia_local(cantidad)


func _experiencia_local(cantidad: int) -> void:
	var experiencia := get_parent().get_node_or_null("ExperienciaComponente")
	if experiencia:
		experiencia.agregar_xp(cantidad)


## SERVIDOR: mismas verificaciones de dueño que _pedir_curacion_red. A
## diferencia de esos dos, acá SÍ hace falta reenviarle la confirmación al
## cliente dueño (ver comentario de _pedir_experiencia) — ComponenteConfirm
## acionesRed ya expone _recibir_xp_red para esto mismo (lo usa Enemigo.gd
## al otorgar XP por matar un mob), así que no hace falta un RPC nuevo del
## lado del cliente, solo llamar al que ya existe.
@rpc("any_peer", "reliable")
func _pedir_experiencia_red(cantidad: int) -> void:
	if not multiplayer.is_server():
		return
	var jugador := get_parent()
	if not jugador or not ("peer_id_dueño" in jugador):
		return
	if multiplayer.get_remote_sender_id() != jugador.peer_id_dueño:
		return
	_experiencia_local(cantidad)
	var confirmaciones := jugador.get_node_or_null("ComponenteConfirmacionesRed")
	if confirmaciones:
		confirmaciones.rpc_id(jugador.peer_id_dueño, "_recibir_xp_red", cantidad)


## Desbloqueo de una pasiva de GATILLO (ítem especial, ver DatosItem
## .escena_pasiva) — mismo patrón que _pedir_experiencia: PasivaBase tiene
## que existir de verdad en el cliente dueño (no solo en el servidor) para
## que su predicción visual funcione (ver PasivaBase), así que hace falta
## la confirmación de vuelta, igual que con la XP.
func _pedir_desbloqueo_pasiva(ruta_escena: String) -> void:
	if Utils.en_red() and not multiplayer.is_server():
		rpc_id(1, "_pedir_desbloqueo_pasiva_red", ruta_escena)
		return
	_desbloquear_pasiva_local(ruta_escena)


func _desbloquear_pasiva_local(ruta_escena: String) -> void:
	var pasivas := get_parent().get_node_or_null("PasivasComponente") as PasivasComponente
	if pasivas:
		pasivas.desbloquear_gatillo(ruta_escena)


## SERVIDOR: mismas verificaciones de dueño que _pedir_curacion_red.
@rpc("any_peer", "reliable")
func _pedir_desbloqueo_pasiva_red(ruta_escena: String) -> void:
	if not multiplayer.is_server():
		return
	var jugador := get_parent()
	if not jugador or not ("peer_id_dueño" in jugador):
		return
	if multiplayer.get_remote_sender_id() != jugador.peer_id_dueño:
		return
	_desbloquear_pasiva_local(ruta_escena)
	var confirmaciones := jugador.get_node_or_null("ComponenteConfirmacionesRed")
	if confirmaciones:
		confirmaciones.rpc_id(jugador.peer_id_dueño, "_recibir_pasiva_red", ruta_escena)


## Bug real reportado: "el botón de vender no hace nada". Causa: cargar
## partida (o reconectarse) solo llena el ESPEJO del cliente (ver
## GestorGuardado._recibir_partida_red) — a diferencia del equipo (ver
## EquipoComponente._sincronizar_equipo_red) y las habilidades, el
## inventario SUELTO nunca tenía un canal de vuelta al servidor. El
## servidor AUTORITATIVO (el que de verdad valida "¿tenés esto?", ver
## TiendaComponente.vender_item/_vender_local) se quedaba con "items"
## VACÍO tras reconectar, aunque el cliente mostrara el inventario
## completo — vender pedía el RPC bien, pero _buscar_por_recurso nunca
## encontraba nada porque del lado del servidor no había nada que buscar.
## Mismo patrón de "cliente manda su espejo, servidor lo toma como
## verdadero" que ya usa el equipo — solo tiene sentido pedirlo UNA VEZ,
## justo después de que GestorGuardado termina de llenar el espejo local
## (no en cada agregar_item(): eso mandaría el inventario ENTERO por cada
## ítem sumado, carísimo con inventarios grandes).
func sincronizar_con_servidor() -> void:
	if not Utils.en_red() or multiplayer.is_server():
		return
	var jugador := get_parent()
	if not is_instance_valid(jugador) or not ("peer_id_dueño" in jugador):
		return
	if jugador.peer_id_dueño != multiplayer.get_unique_id():
		return
	var rutas: PackedStringArray = []
	var cantidades: PackedInt32Array = []
	for item: DatosItem in items:
		if item == null or item.id_recurso == "":
			continue
		rutas.append(item.id_recurso)
		cantidades.append(item.quantity)
	rpc_id(1, "_pedir_sincronizar_red", rutas, cantidades)


## SERVIDOR: mismas verificaciones de dueño que el resto de los RPC "pedir"
## — reemplaza ENTERO el inventario autoritativo por lo que el cliente dice
## tener. Confiar así en el cliente es el mismo criterio que ya usa
## EquipoComponente._equipar_red: solo se acepta justo después de un
## cargar-partida/reconexión (nunca en medio de una compra/venta/loot
## normal, que siguen validándose contra el propio InventarioComponente del
## servidor como siempre).
@rpc("any_peer", "reliable")
func _pedir_sincronizar_red(rutas: PackedStringArray, cantidades: PackedInt32Array) -> void:
	if not multiplayer.is_server():
		return
	var jugador := get_parent()
	if not jugador or not ("peer_id_dueño" in jugador):
		return
	if multiplayer.get_remote_sender_id() != jugador.peer_id_dueño:
		return
	items.clear()
	for i in rutas.size():
		var ruta := rutas[i]
		if ruta == "" or not ResourceLoader.exists(ruta):
			continue
		var item := load(ruta) as DatosItem
		if item == null:
			continue
		var cantidad := cantidades[i] if i < cantidades.size() else 1
		agregar_item(item, cantidad, true)
