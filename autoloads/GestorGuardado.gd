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
## EN RED el progreso vive EN EL SERVIDOR (decisión de diseño), en una base
## SQLite real (user://partidas.db, addons/godot-sqlite — Fase 2 del plan de
## escalado a MMO: reemplaza el archivo-por-jugador anterior, que no daba
## pie a nada más que guardar/cargar — sin transacciones seguras, sin poder
## consultar "¿quién tiene más XP?" ni construir herramientas de moderación
## más adelante). Cada fila se identifica por Jugador.id_unico (un UUID
## persistente por instalación, NUNCA el nombre para mostrar — ver
## Utils.id_jugador_local() para el porqué; lo resuelve el SERVIDOR desde su
## copia del jugador, nunca se confía en un dato mandado directo por el
## cliente). El PAYLOAD sigue siendo el mismo JSON de siempre — cambia DÓNDE
## se guarda, no el protocolo cliente↔servidor ni el modo un jugador
## (RUTA_GUARDADO, sin tocar: sigue en archivo plano, sin necesidad real de
## una base de datos ahí — no hay concurrencia que proteger).
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
## Base SQLite del progreso EN RED — un solo archivo, todas las partidas.
const RUTA_BD_RED := "user://partidas.db"
const VERSION_GUARDADO := 1
## Tope del JSON aceptado por el servidor (anti-abuso): una partida legítima
## pesa ~1-2 KB.
const _MAX_BYTES_PARTIDA := 65536
## Cada cuántos segundos un cliente puro guarda solo su progreso.
const AUTOGUARDADO_SEGUNDOS := 60.0

signal partida_guardada
signal partida_cargada

var _acumulador_autoguardado := 0.0
## Conexión SQLite única, abierta perezosamente y reutilizada — el
## servidor corre en un solo hilo (el bucle principal de Godot), así que no
## hace falta pool de conexiones ni nada más elaborado.
var _bd: SQLite = null


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
		"barra_rapida": _serializar_barra_rapida(),
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
	_restaurar_barra_rapida(datos.get("barra_rapida", []))

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
	var item := load(ruta) as DatosItem
	# Estampar id_recurso (bug reportado: espada equipada tras cargar
	# partida mostraba 18-20 de daño en la habilidad pero solo pegaba
	# 10-12 de verdad). load() trae el .tres ORIGINAL tal cual está en
	# disco — su id_recurso viene vacío, porque ese campo normalmente solo
	# se estampa en copias duplicadas en tiempo de ejecución (ver
	# InventarioComponente.agregar_item), nunca en el recurso de fábrica.
	# EquipoComponente._sincronizar_equipo_red() manda item.id_recurso al
	# SERVIDOR para que sepa qué tiene puesto cada jugador (ver ese
	# archivo) — con id_recurso vacío, el servidor descartaba la espada en
	# silencio y calculaba el daño real SIN el bono del arma, mientras el
	# cliente (que trabaja con el objeto en mano, sin pasar por red) sí lo
	# aplicaba bien en la vista previa. De ahí el número más alto en la UI
	# que en el golpe de verdad.
	if item and item.id_recurso == "":
		item.id_recurso = ruta
	return item


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


## Guarda solo la referencia al recurso (id_recurso) de cada una de las 4
## casillas de la barra rápida — "" si está vacía. Al restaurar, se busca el
## ítem YA restaurado en GestorInventario.items con ese id_recurso (ver
## _restaurar_barra_rapida) en vez de cargar una copia nueva y desconectada:
## así la cantidad que muestra la barra sigue siendo la misma referencia que
## ve el inventario general, sin desincronizarse.
func _serializar_barra_rapida() -> Array:
	var lista := []
	for item: DatosItem in GestorBarraRapida.casillas:
		lista.append(item.id_recurso if item and item.id_recurso != "" else "")
	return lista


func _restaurar_barra_rapida(rutas: Array) -> void:
	for i in GestorBarraRapida.CANTIDAD_CASILLAS:
		var ruta: String = rutas[i] if i < rutas.size() else ""
		var item := _buscar_item_por_recurso(ruta) if ruta != "" else null
		GestorBarraRapida.asignar(i, item)


func _buscar_item_por_recurso(ruta: String) -> DatosItem:
	for item: DatosItem in GestorInventario.items:
		if item and item.id_recurso == ruta:
			return item
	return null


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
# MODO RED — SQLite real en el servidor (Fase 2), una fila por jugador
# =============================================================================

## Conexión abierta y con la tabla lista, creándola la primera vez que hace
## falta. Solo tiene sentido llamarla del lado del SERVIDOR.
func _bd_red() -> SQLite:
	if _bd == null:
		_bd = SQLite.new()
		_bd.path = RUTA_BD_RED
		_bd.open_db()
		# nombre_visible es columna aparte (no solo dentro del JSON) a
		# propósito: permite construir a futuro herramientas de admin/
		# consulta ("¿quién es este UUID?") sin tener que parsear el JSON de
		# cada fila — el beneficio real de pasar a una base de datos.
		_bd.query("""
			CREATE TABLE IF NOT EXISTS partidas (
				id_unico TEXT PRIMARY KEY,
				nombre_visible TEXT,
				datos_json TEXT NOT NULL,
				actualizado TEXT NOT NULL
			);
		""")
	return _bd


## SERVIDOR: recibe el JSON del cliente y lo guarda (INSERT u UPDATE según
## corresponda) en la fila de ESE jugador, identificado por su id_unico —
## nunca por un dato mandado directo por el cliente.
@rpc("any_peer", "reliable")
func _guardar_partida_red(texto: String) -> void:
	if not multiplayer.is_server():
		return
	if texto.length() > _MAX_BYTES_PARTIDA:
		return
	# Validar que sea JSON de verdad antes de guardarlo (basura fuera).
	if typeof(JSON.parse_string(texto)) != TYPE_DICTIONARY:
		return
	var jugador := _jugador_de_peer(multiplayer.get_remote_sender_id())
	var id := _id_unico_limpio(jugador)
	if id == "":
		return
	var nombre := Utils.nombre_visible(jugador)
	# query_with_bindings: los valores viajan como parámetros, nunca
	# concatenados al SQL — evita cualquier inyección aunque nombre_visible
	# venga en última instancia del cliente (ver Jugador._registrar_
	# identidad_red). ON CONFLICT: upsert en una sola sentencia, atómico.
	_bd_red().query_with_bindings(
		"""
		INSERT INTO partidas (id_unico, nombre_visible, datos_json, actualizado)
		VALUES (?, ?, ?, ?)
		ON CONFLICT(id_unico) DO UPDATE SET
			nombre_visible = excluded.nombre_visible,
			datos_json = excluded.datos_json,
			actualizado = excluded.actualizado;
		""",
		[id, nombre, texto, Time.get_datetime_string_from_system(true)]
	)


## SERVIDOR: el cliente pide su partida — si existe una fila para su
## id_unico, se la devuelve.
@rpc("any_peer", "reliable")
func _pedir_partida_red() -> void:
	if not multiplayer.is_server():
		return
	var quien := multiplayer.get_remote_sender_id()
	var jugador := _jugador_de_peer(quien)
	var id := _id_unico_limpio(jugador)
	if id == "":
		return
	var bd := _bd_red()
	bd.query_with_bindings("SELECT datos_json FROM partidas WHERE id_unico = ?;", [id])
	if bd.query_result.is_empty():
		return  # sin partida guardada: el cliente arranca de cero, sin error.
	var texto: String = bd.query_result[0]["datos_json"]
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
	_restaurar_barra_rapida(datos.get("barra_rapida", []))

	var datos_jugador: Dictionary = datos.get("jugador", {})
	var pos: Array = datos_jugador.get("posicion", [])
	var vida: float = datos_jugador.get("vida_actual", 0.0)
	if pos.size() == 2:
		var destino := Vector2(pos[0], pos[1])
		rpc_id(1, "_aplicar_estado_red", destino, vida, datos.get("xp_total", 0))
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
##
## xp_total también viaja acá (no solo al cliente, vía GestorExperiencia más
## arriba): ExperienciaComponente.restaurar_xp() vuelve a aplicar el
## crecimiento de CADA nivel ya alcanzado (vida_maxima/energia_maxima/
## atributos, ver ExperienciaComponente._aplicar_crecimiento_nivel), y eso
## es autoritativo — vive en el SERVIDOR, no en el cliente. Sin esto, el
## servidor reconstruía al jugador reconectado con las estadísticas de
## nivel 1 (vida_maxima=100 siempre) mientras el cliente mostraba su nivel
## real: cualquier curación se topaba con un salud_maxima falso y no
## aplicaba nada (reportado: "me comí 5 zanahorias y la vida no subía").
## Se restaura ANTES de vida a propósito: el crecimiento por nivel también
## cura de paso (ver _aplicar_crecimiento_nivel), y restaurar_vida() de
## abajo pisa ese valor con el real guardado, ya con el salud_maxima
## correcto.
@rpc("any_peer", "reliable")
func _aplicar_estado_red(pos: Vector2, vida: float, xp_total: int = 0) -> void:
	if not multiplayer.is_server():
		return
	var jugador := _jugador_de_peer(multiplayer.get_remote_sender_id())
	if jugador == null:
		return
	jugador.global_position = pos
	var experiencia := jugador.get_node_or_null("ExperienciaComponente")
	if experiencia:
		experiencia.restaurar_xp(xp_total)
	var componente := jugador.get_node_or_null("VidaComponente") as VidaComponente
	if componente:
		# Nunca cargar un muerto: mínimo 1 de vida.
		componente.restaurar_vida(maxf(vida, 1.0))


## Clave real de una fila en la tabla "partidas", derivada de id_unico
## (Fase 0 del plan de escalado a MMO: NUNCA de nombre_visible — el nombre
## de Windows se repite entre jugadores distintos: "Usuario", "Admin",
## "PC"... y dos jugadores con el mismo nombre terminaban compartiendo, sin
## saberlo, la misma partida guardada. id_unico es un UUID que cada cliente
## genera y guarda una sola vez en su propio disco, ver Utils.
## id_jugador_local()). Siempre de SU copia autoritativa en el servidor,
## jamás de un dato leído directo de un paquete de red. "" si el jugador no
## existe o su identidad aún no llegó (ventana muy corta justo al conectar).
func _id_unico_limpio(jugador: Node) -> String:
	if jugador == null:
		return ""
	var id := str(jugador.get("id_unico")).strip_edges()
	if id == "":
		return ""
	# Solo caracteres seguros (a-z, 0-9, _ y -) — el UUID ya solo trae eso,
	# pero no vale la pena confiar ciegamente en un valor de origen cliente.
	var limpio := ""
	for c in id.to_lower():
		var seguro: bool = (c >= "a" and c <= "z") or (c >= "0" and c <= "9") \
			or c == "_" or c == "-"
		limpio += c if seguro else "_"
	return limpio


func _jugador_de_peer(peer_id: int) -> Node2D:
	for jugador in get_tree().get_nodes_in_group("jugadores"):
		if String(jugador.name) == str(peer_id):
			return jugador as Node2D
	return null
