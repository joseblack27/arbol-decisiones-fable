extends Node
## GestorGuardado (autoload): guarda y carga el progreso del jugador en
## disco (formato JSON legible).
##
## Cubre: nivel actual, posición y vida del jugador, inventario, equipo,
## habilidades equipadas en los 4 slots y experiencia. NO guarda estados de
## mundo (mobs vivos/muertos, cooldowns de spawners, etc.) — al cargar, el
## nivel se reinstancia desde cero como si acabaras de entrar a él.
##
## Se dispara con F5 (guardar) / F9 (cargar) desde cualquier parte del
## juego, o con los botones "Guardar"/"Cargar" del panel OS
## (ver OsPrincipal.gd).
##
## EN RED el archivo vive EN EL SERVIDOR (decisión de diseño): una partida
## por jugador en user://partidas/<nombre>.save, identificada por su
## Jugador.nombre_visible (el nombre lo resuelve el SERVIDOR desde su copia
## del jugador — nunca se confía en un nombre mandado por el cliente).
##   - Guardar: el cliente serializa su espejo (fiel: vida/xp/inventario le
##     llegan replicados del servidor) y manda el JSON al servidor.
##   - Cargar: el servidor devuelve el JSON; el cliente aplica su espejo
##     (inventario/equipo/habilidades — se re-sincronizan solos al servidor
##     por los canales de siempre) y el servidor aplica lo autoritativo
##     (posición y vida, que replican solas hacia el cliente).
##   - Al conectar, el cliente pide su partida automáticamente (ver
##     Mundo._esperar_jugador_propio), y además se autoguarda cada
##     AUTOGUARDADO_SEGUNDOS.
## El "nivel_escena" guardado se ignora en red: el mundo es uno solo, el del
## servidor. Sin red, TODO sigue funcionando exactamente como siempre.

const RUTA_GUARDADO := "user://partida.save"
const CARPETA_PARTIDAS_RED := "user://partidas"
const VERSION_GUARDADO := 1
## Tope del JSON aceptado por el servidor (anti-abuso): una partida legítima
## pesa ~1-2 KB.
const _MAX_BYTES_PARTIDA := 65536
## Cada cuántos segundos un cliente puro guarda solo su progreso.
const AUTOGUARDADO_SEGUNDOS := 60.0

signal partida_guardada
signal partida_cargada

var _acumulador_autoguardado := 0.0


func _process(delta: float) -> void:
	# Autoguardado SOLO como cliente puro en red (un jugador conserva su
	# F5 manual de siempre; el servidor dedicado no tiene "su" jugador).
	if not (Utils.en_red() and not multiplayer.is_server()):
		return
	_acumulador_autoguardado += delta
	if _acumulador_autoguardado >= AUTOGUARDADO_SEGUNDOS:
		_acumulador_autoguardado = 0.0
		if _obtener_jugador() != null:
			guardar_partida()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F5:
		guardar_partida()
	elif event.keycode == KEY_F9:
		cargar_partida()


func existe_partida() -> bool:
	return FileAccess.file_exists(RUTA_GUARDADO)


func guardar_partida() -> void:
	var jugador := _obtener_jugador()
	if jugador == null:
		push_warning("GestorGuardado: no hay jugador en escena, no se puede guardar.")
		return

	var nivel := GestorNiveles.nivel_actual()
	var vida: VidaComponente = jugador.get_node_or_null("VidaComponente")

	var datos := {
		"version": VERSION_GUARDADO,
		"nivel_escena": nivel.scene_file_path if nivel else "",
		"jugador": {
			"posicion": [jugador.global_position.x, jugador.global_position.y],
			"vida_actual": vida.obtener_vida() if vida else 0.0,
		},
		"xp_total": GestorExperiencia.xp_total,
		"inventario": _serializar_items(GestorInventario.items),
		"equipo": _serializar_items(GestorEquipo.equipados),
		"habilidades": _serializar_habilidades(),
	}

	# En red (cliente puro) el archivo vive en el SERVIDOR — mandarle el
	# JSON allá en vez de escribir localmente.
	if Utils.en_red() and not multiplayer.is_server():
		rpc_id(1, "_guardar_partida_red", JSON.stringify(datos))
		partida_guardada.emit()
		return

	var archivo := FileAccess.open(RUTA_GUARDADO, FileAccess.WRITE)
	if archivo == null:
		push_error("GestorGuardado: no se pudo abrir '%s' para escribir (error %d)." % [RUTA_GUARDADO, FileAccess.get_open_error()])
		return
	archivo.store_string(JSON.stringify(datos))
	archivo.close()
	partida_guardada.emit()


func cargar_partida() -> void:
	# En red (cliente puro): la partida está en el servidor — pedirla y
	# seguir en _recibir_partida_red cuando llegue.
	if Utils.en_red() and not multiplayer.is_server():
		rpc_id(1, "_pedir_partida_red")
		return

	if not existe_partida():
		push_warning("GestorGuardado: no hay ninguna partida guardada.")
		return

	var archivo := FileAccess.open(RUTA_GUARDADO, FileAccess.READ)
	if archivo == null:
		push_error("GestorGuardado: no se pudo abrir '%s' para leer (error %d)." % [RUTA_GUARDADO, FileAccess.get_open_error()])
		return
	var texto := archivo.get_as_text()
	archivo.close()

	var resultado: Variant = JSON.parse_string(texto)
	if typeof(resultado) != TYPE_DICTIONARY:
		push_error("GestorGuardado: archivo de guardado corrupto o ilegible.")
		return
	var datos: Dictionary = resultado

	var nivel_destino: String = datos.get("nivel_escena", "")
	var nivel_actual := GestorNiveles.nivel_actual()
	var ya_en_ese_nivel := nivel_destino == "" or (nivel_actual != null and nivel_actual.scene_file_path == nivel_destino)

	if ya_en_ese_nivel:
		_aplicar_datos_partida(datos)
	else:
		# GestorNiveles.cambiar_nivel() reposiciona al jugador en el punto de
		# aparición del nivel nuevo — hay que esperar a que termine para
		# recién ahí pisar esa posición con la guardada.
		GestorNiveles.nivel_cargado.connect(_al_cambiar_nivel.bind(datos), CONNECT_ONE_SHOT)
		GestorNiveles.cambiar_nivel(nivel_destino)


func _al_cambiar_nivel(_nivel: NivelBase, datos: Dictionary) -> void:
	_aplicar_datos_partida(datos)


func _aplicar_datos_partida(datos: Dictionary) -> void:
	var jugador := _obtener_jugador()
	if jugador == null:
		return

	var datos_jugador: Dictionary = datos.get("jugador", {})
	var pos: Array = datos_jugador.get("posicion", [])
	if pos.size() == 2:
		jugador.global_position = Vector2(pos[0], pos[1])
		if jugador.has_method(&"resetear_camara"):
			jugador.call(&"resetear_camara")

	var vida: VidaComponente = jugador.get_node_or_null("VidaComponente")
	if vida:
		vida.restaurar_vida(datos_jugador.get("vida_actual", vida.obtener_vida_maxima()))

	GestorExperiencia.xp_total = datos.get("xp_total", 0)

	GestorInventario.items.clear()
	for entrada in datos.get("inventario", []):
		var item := _cargar_item(entrada)
		if item:
			GestorInventario.agregar_item(item, entrada.get("cantidad", 1), true)

	_restaurar_equipo(datos.get("equipo", []))
	_restaurar_habilidades(datos.get("habilidades", []))

	partida_cargada.emit()


func _serializar_items(items: Array) -> Array:
	var lista := []
	for item: DatosItem in items:
		if item == null or item.id_recurso == "":
			continue
		lista.append({"id_recurso": item.id_recurso, "cantidad": item.quantity})
	return lista


func _cargar_item(entrada: Dictionary) -> DatosItem:
	var ruta: String = entrada.get("id_recurso", "")
	if ruta == "" or not ResourceLoader.exists(ruta):
		return null
	return load(ruta) as DatosItem


func _restaurar_equipo(entradas: Array) -> void:
	var panel := get_tree().get_root().find_child("PanelInventario", true, false)
	if panel == null or not panel.has_method("restaurar_equipo"):
		return
	var items: Array[DatosItem] = []
	for entrada in entradas:
		var item := _cargar_item(entrada)
		if item:
			items.append(item)
	panel.call("restaurar_equipo", items)


## A diferencia de DatosItem, un DatosHabilidad NUNCA se duplica (SlotHabilidades
## solo guarda la referencia que ya trae su "catalogo") — su resource_path es
## siempre válido, sin necesitar el mismo truco de id_recurso que los ítems.
func _serializar_habilidades() -> Array:
	var slots := Utils.slot_habilidades_local()
	var lista := []
	if slots == null:
		return lista
	for i in 4:
		var datos: DatosHabilidad = slots.obtener_datos(i)
		lista.append(datos.resource_path if datos else "")
	return lista


func _restaurar_habilidades(rutas: Array) -> void:
	var slots := Utils.slot_habilidades_local()
	if slots == null:
		return
	for i in 4:
		var ruta: String = rutas[i] if i < rutas.size() else ""
		if ruta != "" and ResourceLoader.exists(ruta):
			slots.equipar(i, load(ruta) as DatosHabilidad)
		else:
			slots.equipar(i, null)


func _obtener_jugador() -> Node2D:
	return Utils.jugador_local() as Node2D


# =============================================================================
# MODO RED — el archivo vive en el servidor, una partida por jugador
# =============================================================================

## SERVIDOR: recibe el JSON del cliente y lo escribe en la partida de ESE
## jugador (identificado por el nombre_visible de su copia autoritativa).
@rpc("any_peer", "reliable")
func _guardar_partida_red(texto: String) -> void:
	if not multiplayer.is_server():
		return
	if texto.length() > _MAX_BYTES_PARTIDA:
		return
	# Validar que sea JSON de verdad antes de escribirlo (basura fuera).
	if typeof(JSON.parse_string(texto)) != TYPE_DICTIONARY:
		return
	var ruta := _ruta_partida_de_peer(multiplayer.get_remote_sender_id())
	if ruta == "":
		return
	DirAccess.make_dir_recursive_absolute(CARPETA_PARTIDAS_RED)
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		push_error("GestorGuardado: no se pudo escribir '%s' (error %d)." % [ruta, FileAccess.get_open_error()])
		return
	archivo.store_string(texto)
	archivo.close()


## SERVIDOR: el cliente pide su partida — si existe, se la devuelve.
@rpc("any_peer", "reliable")
func _pedir_partida_red() -> void:
	if not multiplayer.is_server():
		return
	var quien := multiplayer.get_remote_sender_id()
	var ruta := _ruta_partida_de_peer(quien)
	if ruta == "" or not FileAccess.file_exists(ruta):
		return  # sin partida guardada: el cliente arranca de cero, sin error.
	var archivo := FileAccess.open(ruta, FileAccess.READ)
	if archivo == null:
		return
	var texto := archivo.get_as_text()
	archivo.close()
	rpc_id(quien, "_recibir_partida_red", texto)


## CLIENTE: llegó la partida guardada — aplicar el espejo local (inventario,
## equipo, habilidades, XP: se re-sincronizan solos al servidor por los
## canales de siempre) y pedirle al servidor que aplique lo autoritativo
## (posición y vida — replican de vuelta solas). El nivel guardado se ignora:
## en red el mundo es uno solo, el del servidor.
@rpc("authority", "reliable")
func _recibir_partida_red(texto: String) -> void:
	var resultado: Variant = JSON.parse_string(texto)
	if typeof(resultado) != TYPE_DICTIONARY:
		push_error("GestorGuardado: la partida recibida del servidor está corrupta.")
		return
	var datos: Dictionary = resultado

	GestorExperiencia.xp_total = datos.get("xp_total", 0)
	GestorInventario.items.clear()
	for entrada in datos.get("inventario", []):
		var item := _cargar_item(entrada)
		if item:
			GestorInventario.agregar_item(item, entrada.get("cantidad", 1), true)
	_restaurar_equipo(datos.get("equipo", []))
	_restaurar_habilidades(datos.get("habilidades", []))

	var datos_jugador: Dictionary = datos.get("jugador", {})
	var pos: Array = datos_jugador.get("posicion", [])
	var vida: float = datos_jugador.get("vida_actual", 0.0)
	if pos.size() == 2:
		var destino := Vector2(pos[0], pos[1])
		rpc_id(1, "_aplicar_estado_red", destino, vida)
		# Salto local inmediato (sin lerp): cargar partida es un
		# teletransporte, como reaparecer — deslizarse por medio mapa hasta
		# la posición guardada se vería como un fantasma. El servidor aplica
		# la misma posición con autoridad (RPC de arriba) y la réplica
		# siguiente coincide con este salto.
		var jugador := _obtener_jugador()
		if jugador != null:
			jugador.global_position = destino
			if "_posicion_replicada" in jugador:
				jugador.set("_posicion_replicada", destino)
			if jugador.has_method(&"resetear_camara"):
				jugador.call(&"resetear_camara")

	partida_cargada.emit()


## SERVIDOR: aplica posición y vida guardadas a la copia autoritativa del
## jugador que las pidió. La posición replica por el Sync y la vida por
## restaurar_vida (ver VidaComponente) — el cliente las ve solas.
@rpc("any_peer", "reliable")
func _aplicar_estado_red(pos: Vector2, vida: float) -> void:
	if not multiplayer.is_server():
		return
	var jugador := _jugador_de_peer(multiplayer.get_remote_sender_id())
	if jugador == null:
		return
	jugador.global_position = pos
	var componente := jugador.get_node_or_null("VidaComponente") as VidaComponente
	if componente:
		# Nunca cargar un muerto: mínimo 1 de vida.
		componente.restaurar_vida(maxf(vida, 1.0))


## Ruta del archivo de partida de un peer, derivada del nombre_visible de SU
## copia autoritativa en el servidor (jamás de un dato mandado por el
## cliente). "" si el jugador no existe o su nombre aún no llegó.
func _ruta_partida_de_peer(peer_id: int) -> String:
	var jugador := _jugador_de_peer(peer_id)
	if jugador == null:
		return ""
	var nombre := str(jugador.get("nombre_visible")).strip_edges()
	if nombre == "":
		return ""
	# Solo caracteres seguros para nombre de archivo (a-z, 0-9, _ y -).
	var limpio := ""
	for c in nombre.to_lower():
		var seguro: bool = (c >= "a" and c <= "z") or (c >= "0" and c <= "9") \
			or c == "_" or c == "-"
		limpio += c if seguro else "_"
	return "%s/%s.save" % [CARPETA_PARTIDAS_RED, limpio]


func _jugador_de_peer(peer_id: int) -> Node2D:
	for jugador in get_tree().get_nodes_in_group("jugadores"):
		if String(jugador.name) == str(peer_id):
			return jugador as Node2D
	return null
