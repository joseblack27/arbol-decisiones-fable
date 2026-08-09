extends Node
class_name MisionesComponente
## Progreso de misiones de ESTE jugador — mismo patrón cliente-pide/
## servidor-decide que MejorasComponente/TiendaComponente para aceptar y
## completar. Las DEFINICIONES de misión (DatosMision/DatosObjetivoMision)
## son plantillas COMPARTIDAS sin estado propio (ver el comentario en
## DatosMision.gd) — el progreso real vive acá, por jugador, indexado por
## DatosMision.id.

## id_mision -> {"estado": Enums.Mision.Estado, "objetivos": {id_objetivo: cantidad_actual}}
var progreso: Dictionary = {}


func estado_de(id_mision: String) -> Enums.Mision.Estado:
	if not progreso.has(id_mision):
		return Enums.Mision.Estado.BLOQUEADA
	return progreso[id_mision]["estado"]


## Repara entradas COMPLETADA "viejas" de misiones que AHORA son
## repetibles — completarla de verdad (ver _completar_mision_local) ya
## resetea sola en las próximas veces, pero una partida guardada ANTES de
## que la misión se marcara repetible (o antes de que este mecanismo
## existiera) quedó con estado COMPLETADA congelado para siempre; sin este
## arreglo el NPC nunca la volvía a ofrecer aunque la definición diga
## repetible=true. Se llama al restaurar una partida (ver GestorGuardado.
## _restaurar_misiones) — cubre los 3 caminos de restauración porque esa
## es la única función que arma "progreso" en los tres.
func reparar_completadas_repetibles() -> void:
	for id_mision in progreso.keys().duplicate():
		var entrada: Dictionary = progreso[id_mision]
		if entrada.get("estado") != Enums.Mision.Estado.COMPLETADA:
			continue
		var datos: DatosMision = GestorMisiones.obtener_por_id(id_mision)
		if datos and datos.repetible:
			progreso.erase(id_mision)


func progreso_objetivo(id_mision: String, id_objetivo: String) -> int:
	if not progreso.has(id_mision):
		return 0
	return progreso[id_mision]["objetivos"].get(id_objetivo, 0)


# =============================================================================
# Aceptar
# =============================================================================

func aceptar_mision(datos: DatosMision) -> void:
	if datos == null:
		return
	if Utils.en_red() and not multiplayer.is_server():
		rpc_id(1, "_pedir_aceptar_mision_red", datos.id)
		return
	_aceptar_mision_por_id(datos.id)


func _aceptar_mision_por_id(id_mision: String) -> bool:
	return _aceptar_mision_local(GestorMisiones.obtener_por_id(id_mision))


@rpc("any_peer", "reliable")
func _pedir_aceptar_mision_red(id_mision: String) -> void:
	if not multiplayer.is_server():
		return
	var jugador := get_parent()
	if not jugador or not ("peer_id_dueño" in jugador):
		return
	if multiplayer.get_remote_sender_id() != jugador.peer_id_dueño:
		return
	if _aceptar_mision_por_id(id_mision):
		var confirmaciones := jugador.get_node_or_null("ComponenteConfirmacionesRed")
		if confirmaciones:
			confirmaciones.rpc_id(jugador.peer_id_dueño, "_recibir_mision_aceptada_red", id_mision)


## Aplica DE VERDAD — reusado por aceptar_mision() (fuera de red o ya
## siendo el servidor) y por el flujo RPC. true si se concretó.
func _aceptar_mision_local(datos: DatosMision) -> bool:
	if datos == null or datos.id == "":
		return false
	if progreso.has(datos.id):
		return false  # ya aceptada (o completada) — no reiniciar progreso.
	var padre := get_parent()
	if padre == null:
		return false
	var experiencia := padre.get_node_or_null("ExperienciaComponente")
	if experiencia and experiencia.nivel < datos.nivel_requerido:
		return false
	var objetivos := {}
	for objetivo in datos.objetivos:
		if objetivo:
			objetivos[objetivo.id] = 0
	progreso[datos.id] = {"estado": Enums.Mision.Estado.EN_PROGRESO, "objetivos": objetivos}
	BusEventos.mision_aceptada.emit(padre, datos.id)
	return true


# =============================================================================
# Completar
# =============================================================================

func completar_mision(datos: DatosMision) -> void:
	if datos == null:
		return
	if Utils.en_red() and not multiplayer.is_server():
		rpc_id(1, "_pedir_completar_mision_red", datos.id)
		return
	_completar_mision_por_id(datos.id)


func _completar_mision_por_id(id_mision: String) -> bool:
	return _completar_mision_local(GestorMisiones.obtener_por_id(id_mision))


@rpc("any_peer", "reliable")
func _pedir_completar_mision_red(id_mision: String) -> void:
	if not multiplayer.is_server():
		return
	var jugador := get_parent()
	if not jugador or not ("peer_id_dueño" in jugador):
		return
	if multiplayer.get_remote_sender_id() != jugador.peer_id_dueño:
		return
	if _completar_mision_por_id(id_mision):
		var confirmaciones := jugador.get_node_or_null("ComponenteConfirmacionesRed")
		if confirmaciones:
			confirmaciones.rpc_id(jugador.peer_id_dueño, "_recibir_mision_completada_red", id_mision)


## Revalida TODO server-side — nunca confía en que el cliente diga "ya
## terminé": vuelve a chequear el progreso guardado en ESTE componente
## contra las cantidad_meta reales de la definición.
func _completar_mision_local(datos: DatosMision) -> bool:
	if datos == null or not progreso.has(datos.id):
		return false
	var entrada: Dictionary = progreso[datos.id]
	if entrada["estado"] != Enums.Mision.Estado.EN_PROGRESO:
		return false
	if not objetivos_completos(datos.id):
		return false
	var padre := get_parent()
	if padre:
		_otorgar_recompensas(padre, datos.recompensas)
		BusEventos.mision_completada.emit(padre, datos.id)
	if datos.repetible:
		# Vuelve a "nunca aceptada" — GestorMisiones sigue teniendo la
		# DEFINICIÓN, así que el NPC puede volver a ofrecerla como si
		# fuera la primera vez (pedido del usuario: "que se resetee cada
		# vez que la termine y pueda volverla a hacer").
		progreso.erase(datos.id)
	else:
		entrada["estado"] = Enums.Mision.Estado.COMPLETADA
	return true


## true si TODOS los objetivos de una misión EN_PROGRESO ya están
## cumplidos — no implica que ya se haya completado de verdad (eso
## requiere pasar por completar_mision(), que además otorga recompensas y
## resetea si es repetible). Público porque PanelDialogo lo necesita para
## decidir cuándo ofrecer la opción de "entregar" (ver Enums.Dialogo.
## CondicionMision.LISTA_PARA_ENTREGAR) sin duplicar este chequeo.
func objetivos_completos(id_mision: String) -> bool:
	if not progreso.has(id_mision):
		return false
	var datos: DatosMision = GestorMisiones.obtener_por_id(id_mision)
	if datos == null:
		return false
	var entrada: Dictionary = progreso[id_mision]
	for objetivo in datos.objetivos:
		if objetivo == null:
			continue
		var actual: int = entrada["objetivos"].get(objetivo.id, 0)
		if actual < objetivo.cantidad_meta:
			return false
	return true


func _otorgar_recompensas(padre: Node, recompensas: DatosRecompensaMision) -> void:
	if recompensas == null:
		return
	if recompensas.xp > 0:
		var experiencia := padre.get_node_or_null("ExperienciaComponente")
		if experiencia:
			experiencia.agregar_xp(recompensas.xp)
	if recompensas.creditos > 0:
		var creditos := padre.get_node_or_null("CreditosComponente") as CreditosComponente
		if creditos:
			creditos.agregar_creditos(recompensas.creditos)
	var inventario := padre.get_node_or_null("InventarioComponente")
	if inventario:
		for entrada_item in recompensas.items:
			if entrada_item and entrada_item.item:
				inventario.agregar_item(entrada_item.item, entrada_item.cantidad)


# =============================================================================
# Abandonar — no necesita RPC: solo borra progreso PROPIO, no hay una
# copia autoritativa distinta que validar contra (a diferencia de aceptar/
# completar). Se aplica igual en cualquier contexto.
# =============================================================================

func abandonar_mision(id_mision: String) -> void:
	progreso.erase(id_mision)


# =============================================================================
# Progreso automático — despacho DIRECTO, no BusEventos (ver el comentario
# en autoloads/BusEventos.gd, sección MISIONES: es una única instancia de
# autoload compartida por TODOS los Jugador.tscn que vive el servidor a la
# vez — un listener ahí no podría saber a CUÁL jugador acreditarle nada).
# =============================================================================

## Enemigo._notificar_objetivo_matar() llama esto en el MisionesComponente
## del atacante correcto (mismo despacho que ya usa Enemigo._otorgar_xp/
## _otorgar_item_al_atacante) con el EnemigoDatos del que acaba de morir.
func notificar_matar(datos_enemigo: EnemigoDatos) -> void:
	if datos_enemigo == null:
		return
	_avanzar_objetivos(Enums.Mision.TipoObjetivo.MATAR, datos_enemigo.obtener_id())


## InventarioComponente.agregar_item() llama esto cuando ESTE jugador
## recibe un ítem nuevo (gateado ahí por "not silencioso", para no
## re-acreditar progreso al restaurar una partida guardada).
func notificar_recolectar(item: DatosItem) -> void:
	if item == null:
		return
	_avanzar_objetivos(Enums.Mision.TipoObjetivo.RECOLECTAR, item.name)


## Público — para misiones secuenciales (ver DatosMision.secuencial), un
## objetivo solo cuenta una vez que TODOS los anteriores en el orden del
## array ya están cumplidos (ej. "matar 3 arañas" antes de que un golpe a
## la reina cuente para "matar a la reina"). Con secuencial=false (default)
## siempre da true, sin mirar nada más — mismo comportamiento de siempre.
## PanelMisiones usa esto mismo para no listar (todavía) el objetivo cuyo
## turno no llegó.
func objetivo_habilitado(datos: DatosMision, id_objetivo: String) -> bool:
	if not datos.secuencial:
		return true
	for previo in datos.objetivos:
		if previo == null:
			continue
		if previo.id == id_objetivo:
			return true
		if progreso_objetivo(datos.id, previo.id) < previo.cantidad_meta:
			return false
	return true


func _avanzar_objetivos(tipo: Enums.Mision.TipoObjetivo, id_meta: String) -> void:
	# Solo donde el cálculo es el real (servidor, o un jugador sin red) —
	# mismo criterio que EnergiaComponente._process. InventarioComponente.
	# agregar_item() TAMBIÉN corre en el cliente puro (al aplicar el eco de
	# botín sobre su propia copia espejo) — sin este gate, un cliente se
	# autoacreditaría el progreso de RECOLECTAR por su cuenta, duplicando
	# el conteo real que ya viene confirmado por el servidor (ver
	# _avisar_progreso_al_dueño/_aplicar_progreso_local).
	if Utils.en_red() and not multiplayer.is_server():
		return
	for id_mision in progreso.keys():
		var entrada: Dictionary = progreso[id_mision]
		if entrada["estado"] != Enums.Mision.Estado.EN_PROGRESO:
			continue
		var datos: DatosMision = GestorMisiones.obtener_por_id(id_mision)
		if datos == null:
			continue
		for objetivo in datos.objetivos:
			if objetivo == null or objetivo.tipo != tipo or objetivo.id_meta != id_meta:
				continue
			if not objetivo_habilitado(datos, objetivo.id):
				continue
			var actual: int = entrada["objetivos"].get(objetivo.id, 0)
			if actual >= objetivo.cantidad_meta:
				continue
			var nuevo := actual + 1
			entrada["objetivos"][objetivo.id] = nuevo
			var padre := get_parent()
			if padre:
				BusEventos.mision_progreso_actualizado.emit(
						padre, id_mision, objetivo.id, nuevo, objetivo.cantidad_meta)
			_avisar_progreso_al_dueño(id_mision, objetivo.id, nuevo)


func _avisar_progreso_al_dueño(id_mision: String, id_objetivo: String, actual: int) -> void:
	if not (Utils.en_red() and multiplayer.is_server()):
		return
	var jugador := get_parent()
	if not jugador or not ("peer_id_dueño" in jugador):
		return
	var confirmaciones := jugador.get_node_or_null("ComponenteConfirmacionesRed")
	if confirmaciones:
		confirmaciones.rpc_id(jugador.peer_id_dueño, "_recibir_progreso_mision_red", id_mision, id_objetivo, actual)


## Usado por ComponenteConfirmacionesRed._recibir_progreso_mision_red — el
## cliente dueño fija el mismo progreso que ya calculó el servidor (SET
## absoluto, no incremento — así se autocorrige aunque el cliente ya se
## hubiera adelantado prediciendo de más).
##
## Emite mision_progreso_actualizado ACÁ TAMBIÉN (no solo en
## _avanzar_objetivos): ese emit corre del lado SERVIDOR, en su copia
## espejo del jugador — nadie mira un panel ahí. La única forma de que
## PanelMisiones (que vive en el CLIENTE) se entere y se refresque solo
## es que este método, el que corre en la copia del cliente al recibir la
## confirmación, también avise. Sin esto el progreso quedaba bien
## guardado pero la UI nunca se enteraba (reportado: "al matar lobos no
## se actualiza la mision").
func _aplicar_progreso_local(id_mision: String, id_objetivo: String, actual: int) -> void:
	if not progreso.has(id_mision):
		return
	progreso[id_mision]["objetivos"][id_objetivo] = actual
	var padre := get_parent()
	if padre == null:
		return
	var requerido := 0
	var datos: DatosMision = GestorMisiones.obtener_por_id(id_mision)
	if datos:
		for objetivo in datos.objetivos:
			if objetivo and objetivo.id == id_objetivo:
				requerido = objetivo.cantidad_meta
				break
	BusEventos.mision_progreso_actualizado.emit(padre, id_mision, id_objetivo, actual, requerido)
