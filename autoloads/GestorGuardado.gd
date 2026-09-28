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
## EN RED el progreso vive EN EL SERVIDOR, en una base SQLite
## (user://partidas.db, addons/godot-sqlite), una fila por Jugador.id_unico
## (un UUID persistente por instalación, NUNCA el nombre para mostrar; lo
## resuelve el SERVIDOR desde su copia del jugador, nunca de un dato del
## cliente). El payload es el mismo JSON que sin red; sin red se sigue usando
## el archivo plano RUTA_GUARDADO (no hay concurrencia que proteger).
##   - Guardar: el cliente serializa su espejo (fiel: vida, xp e inventario le
##     llegan replicados del servidor) y manda el JSON al servidor.
##   - Cargar: el servidor devuelve el JSON; el cliente aplica su espejo
##     (inventario, equipo y habilidades se re-sincronizan solos con el
##     servidor) y el servidor aplica lo autoritativo (XP, vida, posición).
##   - Al conectar, el cliente pide su partida (ver
##     Mundo._esperar_jugador_propio). Después se autoguarda cada
##     AUTOGUARDADO_SEGUNDOS y, con antirrebote, al instante cuando pasa algo
##     valioso: subir de nivel, ganar XP, loot, cambiar equipo.
##   - El servidor NO escribe a SQLite en cada envío: guarda el snapshot más
##     nuevo de cada jugador en memoria (_snapshots_pendientes) y lo vuelca
##     por lotes cada FLUSH_BD_SEGUNDOS, de inmediato cuando ese jugador se
##     desconecta (volcar_peer, ver ServidorDedicado) y al apagarse.

const RUTA_GUARDADO := "user://partida.save"
## Base SQLite del progreso EN RED — un solo archivo, todas las partidas.
const RUTA_BD_RED := "user://partidas.db"
const VERSION_GUARDADO := 1
## Tope del JSON aceptado por el servidor (anti-abuso): una partida legítima
## pesa ~1-2 KB.
const _MAX_BYTES_PARTIDA := 65536
## Cada cuántos segundos un cliente puro guarda solo su progreso. El snapshot
## pesa ~1-2 KB y el servidor no lo escribe a disco al recibirlo, así que
## mandarlo seguido cuesta casi nada y acota la pérdida por desconexión.
const AUTOGUARDADO_SEGUNDOS := 10.0
## Antirrebote de los guardados por evento (subir de nivel, loot, equipo...):
## varios eventos seguidos (abrir un cofre con 5 items) producen UN solo
## envío, no cinco.
const DEBOUNCE_EVENTO_SEGUNDOS := 2.0
## SERVIDOR: cada cuántos segundos vuelca el buffer de snapshots a SQLite. La
## desconexión de un peer fuerza SU volcada inmediata (ver volcar_peer).
const FLUSH_BD_SEGUNDOS := 60.0
## Tope de espera por la respuesta de cargar_partida() antes de asumir que la
## cuenta es nueva y destrabar el guardado (ver _esperando_carga_inicial).
## Bien por encima de DEBOUNCE_EVENTO_SEGUNDOS, que es justo lo que protege.
const ESPERA_CARGA_INICIAL_SEGUNDOS := 6.0

signal partida_guardada
signal partida_cargada

var _acumulador_autoguardado := 0.0
var _guardado_evento_pendiente := false
## Cliente puro en red: true mientras se espera la respuesta del servidor a
## cargar_partida() (o el timeout de arriba). Bloquea CUALQUIER
## guardar_partida(): al conectar, Mundo._esperar_jugador_propio() equipa el
## golpe_basico por defecto ANTES de pedir la partida, y ese equipar() dispara
## el guardado por evento. Si el antirrebote ganaba la carrera (red lenta),
## pisaba el progreso real en el servidor con un personaje recién creado.
var _esperando_carga_inicial := false
## SERVIDOR: snapshot más reciente de cada jugador que aún no tocó SQLite.
## id_unico -> {"nombre": String, "texto": String (JSON)}.
var _snapshots_pendientes: Dictionary = {}
var _acumulador_flush := 0.0
## Conexión SQLite única, abierta perezosamente y reutilizada (el servidor
## corre en un solo hilo).
## Sin tipo estático "SQLite" a propósito (ver _bd_red()): la clase la
## registra el GDExtension addons/godot-sqlite, que solo tiene binario para
## Windows/Linux. El build de Android no lo trae, y con el tipo estático este
## autoload no compilaría ahí (aunque ese código nunca corra en el cliente),
## tirando abajo todo el arranque.
var _bd = null


func _ready() -> void:
	# Diferido: GestorBarraRapida se declara DESPUÉS de este autoload en
	# project.godot — en este _ready() todavía no existe.
	_conectar_eventos_guardado.call_deferred()


## Guardado por EVENTO (cliente puro): lo valioso no espera al tick periódico.
## Al subir de nivel, recoger loot o cambiar el equipo, el snapshot viaja al
## servidor enseguida (con antirrebote, ver _guardar_por_evento).
func _conectar_eventos_guardado() -> void:
	BusEventos.nivel_subido.connect(func(_n): _guardar_por_evento())
	BusEventos.xp_agregada.connect(func(_c, _t): _guardar_por_evento())
	BusEventos.item_agregado.connect(func(_i, _c): _guardar_por_evento())
	BusEventos.equipo_cambiado.connect(func(_e): _guardar_por_evento())
	BusEventos.habilidad_equipada.connect(func(_e, _s, _h): _guardar_por_evento())
	GestorBarraRapida.casilla_cambiada.connect(func(_i): _guardar_por_evento())
	BusEventos.pasiva_desbloqueada.connect(func(_e, _n, _d): _guardar_por_evento())
	BusEventos.mejora_comprada.connect(func(_e, _t, _n): _guardar_por_evento())


func _process(delta: float) -> void:
	# SERVIDOR dedicado: volcar el buffer de snapshots a SQLite por lotes.
	if Utils.en_red() and multiplayer.is_server():
		_acumulador_flush += delta
		if _acumulador_flush >= FLUSH_BD_SEGUNDOS:
			_acumulador_flush = 0.0
			_volcar_pendientes()
		return
	# Autoguardado SOLO como cliente puro en red (un jugador conserva su
	# F5 manual de siempre; el servidor dedicado no tiene "su" jugador).
	if not Utils.en_red():
		return
	_acumulador_autoguardado += delta
	if _acumulador_autoguardado >= AUTOGUARDADO_SEGUNDOS:
		_acumulador_autoguardado = 0.0
		if _obtener_jugador() != null:
			guardar_partida()


## Cliente puro: agenda UN guardado dentro de DEBOUNCE_EVENTO_SEGUNDOS —
## los eventos que lleguen mientras tanto quedan cubiertos por ese mismo
## envío. Fuera de red no hace nada (un jugador conserva su F5 manual).
func _guardar_por_evento() -> void:
	if not (Utils.en_red() and not multiplayer.is_server()):
		return
	if _guardado_evento_pendiente:
		return
	_guardado_evento_pendiente = true
	get_tree().create_timer(DEBOUNCE_EVENTO_SEGUNDOS).timeout.connect(func():
		_guardado_evento_pendiente = false
		if Utils.en_red() and not multiplayer.is_server() and _obtener_jugador() != null:
			_acumulador_autoguardado = 0.0
			guardar_partida()
	)


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
		"pasivas": _serializar_pasivas(),
		"mejoras": _serializar_mejoras(),
		"creditos": _serializar_creditos(),
		"misiones": _serializar_misiones(),
		"cofres": _serializar_cofres(),
	}

	# En red (cliente puro) el archivo vive en el SERVIDOR — mandarle el
	# JSON allá en vez de escribir localmente. Mientras se espera la carga
	# inicial (ver _esperando_carga_inicial), este "datos" todavía no
	# refleja la partida real recién pedida — descartar en vez de pisarla.
	if Utils.en_red() and not multiplayer.is_server():
		if _esperando_carga_inicial:
			return
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
	# seguir en _recibir_partida_red cuando llegue. Bloquear cualquier
	# guardado hasta entonces (ver _esperando_carga_inicial); si no hay
	# respuesta en ESPERA_CARGA_INICIAL_SEGUNDOS, asumimos cuenta nueva sin
	# partida guardada y se destraba solo.
	if Utils.en_red() and not multiplayer.is_server():
		_esperando_carga_inicial = true
		rpc_id(1, "_pedir_partida_red")
		get_tree().create_timer(ESPERA_CARGA_INICIAL_SEGUNDOS).timeout.connect(func():
			_esperando_carga_inicial = false
		)
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
	# ANTES de _restaurar_habilidades(): SlotHabilidades._instanciar() lee
	# el nivel de mejora comprado al equipar (ver GestorGuardado
	# ._restaurar_mejoras para el orden completo).
	_restaurar_mejoras(datos.get("mejoras", {}))
	_restaurar_creditos(datos.get("creditos", {}))
	_restaurar_misiones(datos.get("misiones", {}))
	_restaurar_cofres(datos.get("cofres", {}))

	GestorInventario.items.clear()
	for entrada in datos.get("inventario", []):
		var item := _cargar_item(entrada)
		if item:
			GestorInventario.agregar_item(item, entrada.get("cantidad", 1), true)

	_restaurar_equipo(datos.get("equipo", []))
	_restaurar_habilidades(datos.get("habilidades", []))
	_restaurar_barra_rapida(datos.get("barra_rapida", []))
	_restaurar_pasivas(datos.get("pasivas", []))

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
	# Estampar id_recurso: load() trae el .tres de fábrica, con id_recurso
	# vacío (solo se estampa en las copias duplicadas, ver
	# InventarioComponente.agregar_item). EquipoComponente._sincronizar_equipo_red()
	# le manda id_recurso al servidor; vacío, el servidor descartaba el ítem en
	# silencio y calculaba el daño SIN el bono del arma.
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


## Guarda solo el id_recurso de cada casilla de la barra rápida ("" si está
## vacía). Al restaurar se busca el ítem YA restaurado en GestorInventario
## (ver _restaurar_barra_rapida) en vez de cargar una copia desconectada, así
## la cantidad de la barra es la misma referencia que ve el inventario.
func _serializar_barra_rapida() -> Array:
	var lista := []
	for item: DatosItem in GestorBarraRapida.casillas:
		lista.append(item.id_recurso if item and item.id_recurso != "" else "")
	return lista


## Pasivas de GATILLO desbloqueadas (ver PasivasComponente). A diferencia de
## los ítems, se guarda la ruta de la ESCENA de la pasiva, que nunca se
## duplica (mismo criterio que _serializar_habilidades). Las pasivas de
## ESTADÍSTICA (ExperienciaComponente.pasivas_stat) no se guardan: se
## re-derivan del nivel, como vida_maxima y energia_maxima.
func _serializar_pasivas() -> Array:
	var pasivas := Utils.pasivas_componente_local()
	if pasivas == null:
		return []
	return pasivas.gatillo_desbloqueadas.duplicate()


## [jugador] explícito para el camino SERVIDOR (ver
## _restaurar_estado_autoritativo): ahí Utils.pasivas_componente_local()
## resolvería el jugador equivocado. Sin [jugador], resuelve el local.
func _restaurar_pasivas(rutas: Array, jugador: Node = null) -> void:
	var pasivas: PasivasComponente = null
	if jugador != null:
		pasivas = jugador.get_node_or_null("PasivasComponente") as PasivasComponente
	else:
		pasivas = Utils.pasivas_componente_local()
	if pasivas == null:
		return
	for ruta in rutas:
		var ruta_str := str(ruta)
		if ruta_str != "" and ResourceLoader.exists(ruta_str):
			pasivas.desbloquear_gatillo(ruta_str, false)


## Puntos de mejora (ver MejorasComponente): un Dictionary anidado que se
## persiste tal cual (puntos_gastados y los niveles comprados, indexados por
## resource_path).
func _serializar_mejoras() -> Dictionary:
	var mejoras := Utils.mejoras_componente_local()
	if mejoras == null:
		return {}
	return {
		"puntos_gastados": mejoras.puntos_gastados,
		"niveles_pasivas": mejoras.niveles_pasivas.duplicate(),
		"niveles_habilidades": mejoras.niveles_habilidades.duplicate(),
	}


## [jugador] explícito para el camino SERVIDOR (mismo motivo que
## _restaurar_pasivas).
## IMPORTANTE: llamar DESPUÉS de restaurar la XP y ANTES de
## _restaurar_habilidades(): SlotHabilidades._instanciar() lee
## MejorasComponente.nivel_habilidad() al equipar, y los tiers de pasiva
## comprados se reaplican sobre el reseteo que hizo restaurar_xp() (ver
## MejorasComponente.reaplicar_pasivas_compradas).
func _restaurar_mejoras(datos: Dictionary, jugador: Node = null) -> void:
	var jugador_real := jugador if jugador != null else Utils.jugador_local()
	if jugador_real == null:
		return
	var mejoras := jugador_real.get_node_or_null("MejorasComponente") as MejorasComponente
	if mejoras == null:
		return
	mejoras.puntos_gastados = int(datos.get("puntos_gastados", 0))
	mejoras.niveles_pasivas = (datos.get("niveles_pasivas", {}) as Dictionary).duplicate()
	mejoras.niveles_habilidades = (datos.get("niveles_habilidades", {}) as Dictionary).duplicate()
	var experiencia := jugador_real.get_node_or_null("ExperienciaComponente")
	if experiencia:
		mejoras.reaplicar_pasivas_compradas(experiencia.pasivas_stat)


func _serializar_creditos() -> Dictionary:
	var creditos := Utils.creditos_componente_local()
	if creditos == null:
		return {}
	return {"valor": creditos.obtener_creditos()}


## [jugador] explícito para el camino SERVIDOR (mismo motivo que
## _restaurar_mejoras).
func _restaurar_creditos(datos: Dictionary, jugador: Node = null) -> void:
	var jugador_real := jugador if jugador != null else Utils.jugador_local()
	if jugador_real == null:
		return
	var creditos := jugador_real.get_node_or_null("CreditosComponente") as CreditosComponente
	if creditos == null:
		return
	creditos._fijar_creditos_local(int(datos.get("valor", 0)))


## .duplicate(true): "progreso" tiene Dictionaries ANIDADOS (objetivos), y una
## copia superficial compartiría esas referencias con el componente en vivo.
func _serializar_misiones() -> Dictionary:
	var misiones := Utils.misiones_componente_local()
	if misiones == null:
		return {}
	return misiones.progreso.duplicate(true)


## [jugador] explícito para el camino SERVIDOR (mismo motivo que
## _restaurar_mejoras).
func _restaurar_misiones(datos: Dictionary, jugador: Node = null) -> void:
	var jugador_real := jugador if jugador != null else Utils.jugador_local()
	if jugador_real == null:
		return
	var misiones := jugador_real.get_node_or_null("MisionesComponente") as MisionesComponente
	if misiones == null:
		return
	misiones.progreso = datos.duplicate(true)
	# Misiones completadas antes de marcarse repetibles quedaron en COMPLETADA
	# y el NPC no las volvería a ofrecer (ver
	# MisionesComponente.reparar_completadas_repetibles).
	misiones.reparar_completadas_repetibles()


## id_cofre -> lista de ítems ({id_recurso, cantidad}, como
## _serializar_items). Lista DENSA: la posición no significa nada (ver
## CofresComponente).
func _serializar_cofres() -> Dictionary:
	var cofres := Utils.cofres_componente_local()
	if cofres == null:
		return {}
	var resultado := {}
	for id_cofre in cofres.contenidos:
		resultado[id_cofre] = _serializar_items(cofres.contenidos[id_cofre])
	return resultado


## [jugador] explícito para el camino SERVIDOR (mismo motivo que
## _restaurar_mejoras). Reemplaza contenidos ENTERO: restaurar nunca vuelve a
## sortear el botín inicial (ver CofresComponente.obtener_contenido, que solo
## siembra la primera vez que un id no está).
## [datos] sin tipar a propósito: las partidas del formato viejo traen una
## Array de ids ya abiertos, y tiparlo como Dictionary reventaría al cargarlas.
## Ese formato se descarta.
func _restaurar_cofres(datos, jugador: Node = null) -> void:
	if not datos is Dictionary:
		return
	var jugador_real := jugador if jugador != null else Utils.jugador_local()
	if jugador_real == null:
		return
	var cofres := jugador_real.get_node_or_null("CofresComponente") as CofresComponente
	if cofres == null:
		return
	cofres.contenidos.clear()
	for id_cofre in datos:
		var casillas: Array[DatosItem] = []
		for entrada in datos[id_cofre]:
			var item: DatosItem = _cargar_item(entrada) if entrada is Dictionary else null
			if item:
				# Copia propia con la cantidad guardada: nunca mutar el recurso de
				# fábrica compartido (mismo motivo que InventarioComponente.agregar_item).
				item = item.duplicate() as DatosItem
				item.quantity = (entrada as Dictionary).get("cantidad", 1)
				casillas.append(item)
		cofres.contenidos[id_cofre] = casillas


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
	for i in slots.total_slots:
		var datos: DatosHabilidad = slots.obtener_datos(i)
		lista.append(datos.resource_path if datos else "")
	return lista


func _restaurar_habilidades(rutas: Array) -> void:
	var slots := Utils.slot_habilidades_local()
	if slots == null:
		return
	for i in slots.total_slots:
		var ruta: String = rutas[i] if i < rutas.size() else ""
		# Partidas guardadas antes del renombre de la carpeta
		# (habilidades_ui -> habilidades): sin este remapeo, quedarían todos
		# los slots vacíos.
		ruta = ruta.replace("res://recursos/habilidades_ui/", "res://recursos/habilidades/")
		if ruta != "" and ResourceLoader.exists(ruta):
			slots.equipar(i, load(ruta) as DatosHabilidad)
		else:
			slots.equipar(i, null)


func _obtener_jugador() -> Node2D:
	return Utils.jugador_local() as Node2D


# =============================================================================
# MODO RED — SQLite en el servidor, una fila por jugador
# =============================================================================

## Conexión abierta y con la tabla lista (la crea la primera vez). Solo tiene
## sentido del lado del SERVIDOR. ClassDB.instantiate() y no "SQLite.new()" a
## propósito, para que este autoload compile en un build sin el addon nativo
## (ver "_bd" arriba). GestorCuentas.gd usa esta MISMA conexión para su tabla
## "cuentas" (ver GestorCuentas._asegurar_tabla()).
func _bd_red():
	if _bd == null:
		if not ClassDB.class_exists("SQLite"):
			push_error("GestorGuardado: SQLite no disponible en esta build (¿cliente sin el addon nativo?).")
			return null
		_bd = ClassDB.instantiate("SQLite")
		_bd.path = RUTA_BD_RED
		_bd.open_db()
		# nombre_visible es columna aparte (no solo dentro del JSON) para poder
		# consultar "¿quién es este UUID?" sin parsear el JSON de cada fila.
		_bd.query("""
			CREATE TABLE IF NOT EXISTS partidas (
				id_unico TEXT PRIMARY KEY,
				nombre_visible TEXT,
				datos_json TEXT NOT NULL,
				actualizado TEXT NOT NULL
			);
		""")
	return _bd


## SERVIDOR: recibe el JSON del cliente y lo deja en el buffer en memoria
## (_snapshots_pendientes), sin tocar el disco. A SQLite llega después, por
## lotes cada FLUSH_BD_SEGUNDOS o enseguida si ESE peer se desconecta
## (volcar_peer). La fila se identifica por id_unico, nunca por un dato
## mandado por el cliente.
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
	_snapshots_pendientes[id] = {
		"nombre": Utils.nombre_visible(jugador),
		"texto": texto,
	}


## SERVIDOR: escribe UNA fila en SQLite (upsert). query_with_bindings: los
## valores viajan como parámetros, nunca concatenados al SQL — evita
## cualquier inyección aunque nombre_visible venga en última instancia del
## cliente (ver Jugador._registrar_identidad_red).
func _escribir_snapshot_bd(id: String, nombre: String, texto: String) -> void:
	var bd = _bd_red()
	if bd == null:
		return
	bd.query_with_bindings(
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


## SERVIDOR: vuelca TODO el buffer a SQLite en una sola transacción y lo
## vacía. Corre cada FLUSH_BD_SEGUNDOS (ver _process) y al apagarse el
## servidor (_exit_tree).
func _volcar_pendientes() -> void:
	if _snapshots_pendientes.is_empty():
		return
	var bd = _bd_red()
	if bd == null:
		return
	bd.query("BEGIN;")
	for id: String in _snapshots_pendientes:
		var entrada: Dictionary = _snapshots_pendientes[id]
		_escribir_snapshot_bd(id, entrada["nombre"], entrada["texto"])
	bd.query("COMMIT;")
	_snapshots_pendientes.clear()


## SERVIDOR: vuelca de inmediato el snapshot pendiente del peer que se
## desconecta, para no perder el último tramo. Llamar ANTES de liberar su nodo
## Jugador (ver ServidorDedicado._al_desconectar): _jugador_de_peer lo necesita
## vivo para resolver su id_unico.
func volcar_peer(peer_id: int) -> void:
	var jugador := _jugador_de_peer(peer_id)
	var id := _id_unico_limpio(jugador)
	if id == "" or not _snapshots_pendientes.has(id):
		return
	var entrada: Dictionary = _snapshots_pendientes[id]
	_escribir_snapshot_bd(id, entrada["nombre"], entrada["texto"])
	_snapshots_pendientes.erase(id)


## Último recurso al apagarse el servidor (docker stop, reinicio limpio):
## nada pendiente se queda sin escribir. En cliente/un jugador el buffer
## siempre está vacío — no hace nada.
func _exit_tree() -> void:
	_volcar_pendientes()


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
	# Primero el buffer en memoria: si el jugador reconectó antes del
	# volcado periódico, ahí está su versión más nueva (la de SQLite puede
	# tener hasta FLUSH_BD_SEGUNDOS de atraso).
	if _snapshots_pendientes.has(id):
		var pendiente: String = _snapshots_pendientes[id]["texto"]
		_restaurar_estado_autoritativo(jugador, pendiente)
		rpc_id(quien, "_recibir_partida_red", pendiente)
		return
	var bd = _bd_red()
	if bd == null:
		return
	bd.query_with_bindings("SELECT datos_json FROM partidas WHERE id_unico = ?;", [id])
	if bd.query_result.is_empty():
		return  # sin partida guardada: el cliente arranca de cero, sin error.
	var texto: String = bd.query_result[0]["datos_json"]
	_restaurar_estado_autoritativo(jugador, texto)
	rpc_id(quien, "_recibir_partida_red", texto)


## SERVIDOR: reconstruye acá mismo lo que el jugador autoritativo necesita de
## la partida guardada: XP (y con ella vida_maxima/energia_maxima, ver
## ExperienciaComponente.restaurar_xp), mejoras, pasivas y vida actual. No
## depende de que el cliente lo mande de vuelta: un APK viejo contra un
## servidor nuevo dejaría al jugador autoritativo en nivel 1 (vida y energía
## tope 100), y el máximo real vive en el servidor.
##
## El orden importa: primero la XP (el crecimiento por nivel cura de paso) y
## después la vida guardada, que pisa esa curación con el valor real contra
## el salud_maxima correcto.
func _restaurar_estado_autoritativo(jugador: Node2D, texto: String) -> void:
	if jugador == null:
		return
	var resultado: Variant = JSON.parse_string(texto)
	if typeof(resultado) != TYPE_DICTIONARY:
		return
	var datos: Dictionary = resultado

	var experiencia := jugador.get_node_or_null("ExperienciaComponente")
	if experiencia:
		experiencia.restaurar_xp(int(datos.get("xp_total", 0)))

	# Puntos de mejora: el AUTORITATIVO (el que calcula daño y recarga)
	# tiene que tenerlos aplicados, no solo el espejo del cliente.
	_restaurar_mejoras(datos.get("mejoras", {}), jugador)
	_restaurar_creditos(datos.get("creditos", {}), jugador)
	_restaurar_misiones(datos.get("misiones", {}), jugador)
	_restaurar_cofres(datos.get("cofres", {}), jugador)

	# Pasivas de GATILLO: no se re-derivan de nada, y sin esto el servidor
	# no tendría ninguna instancia real (el efecto dejaba de pasar tras
	# reconectar, aunque la UI del cliente las mostrara).
	_restaurar_pasivas(datos.get("pasivas", []), jugador)

	var datos_jugador: Dictionary = datos.get("jugador", {})
	var vida_guardada: float = datos_jugador.get("vida_actual", 0.0)
	var componente := jugador.get_node_or_null("VidaComponente") as VidaComponente
	if componente and vida_guardada > 0.0:
		# Nunca cargar un muerto: mínimo 1 de vida (mismo criterio que
		# _aplicar_estado_red).
		componente.restaurar_vida(maxf(vida_guardada, 1.0))


## CLIENTE: llegó la partida guardada. Aplica el espejo local (inventario,
## equipo, habilidades, XP) y le pide al servidor lo autoritativo. El nivel
## guardado se respeta pidiéndole la mudanza al servidor (ver más abajo).
@rpc("authority", "reliable")
func _recibir_partida_red(texto: String) -> void:
	_esperando_carga_inicial = false
	var resultado: Variant = JSON.parse_string(texto)
	if typeof(resultado) != TYPE_DICTIONARY:
		push_error("GestorGuardado: la partida recibida del servidor está corrupta.")
		return
	var datos: Dictionary = resultado

	GestorExperiencia.xp_total = datos.get("xp_total", 0)
	# ANTES de _restaurar_habilidades() — ver GestorGuardado._restaurar_mejoras.
	_restaurar_mejoras(datos.get("mejoras", {}))
	_restaurar_creditos(datos.get("creditos", {}))
	_restaurar_misiones(datos.get("misiones", {}))
	_restaurar_cofres(datos.get("cofres", {}))
	GestorInventario.items.clear()
	for entrada in datos.get("inventario", []):
		var item := _cargar_item(entrada)
		if item:
			GestorInventario.agregar_item(item, entrada.get("cantidad", 1), true)
	# El equipo y las habilidades se re-sincronizan solos por sus propios
	# flujos (_restaurar_equipo → GestorEquipo.actualizar →
	# EquipoComponente._sincronizar_equipo_red, y análogo en
	# _restaurar_habilidades). El inventario suelto no tiene uno equivalente:
	# hay que pedirlo a mano, o el servidor no sabe qué hay en él tras
	# reconectar (y no deja vender).
	var inventario_local := Utils.inventario_componente_local()
	if inventario_local:
		inventario_local.sincronizar_con_servidor()
	_restaurar_equipo(datos.get("equipo", []))
	_restaurar_habilidades(datos.get("habilidades", []))
	_restaurar_barra_rapida(datos.get("barra_rapida", []))
	_restaurar_pasivas(datos.get("pasivas", []))

	# El nivel guardado se respeta: cada jugador tiene el suyo (ver
	# GestorNiveles), así que si se desconectó en la cueva, vuelve a la cueva.
	#
	# Con mudanza NO se restaura la posición: está en coordenadas de ese nivel
	# (cada nivel vive desplazado) y aplicarla durante la mudanza sería una
	# carrera contra el teletransporte del servidor. Se aparece en el punto de
	# llegada, como con cualquier portal.
	var se_muda := false
	var ruta_guardada: String = datos.get("nivel_escena", "")
	var nivel_puesto := GestorNiveles.nivel_actual()
	var ruta_puesta := nivel_puesto.scene_file_path if nivel_puesto else ""
	if ruta_guardada != "" and ruta_guardada != ruta_puesta:
		GestorNiveles.pedir_mudarse_a(ruta_guardada)
		se_muda = true

	var datos_jugador: Dictionary = datos.get("jugador", {})
	var pos: Array = datos_jugador.get("posicion", [])
	var vida: float = datos_jugador.get("vida_actual", 0.0)
	var hay_posicion := pos.size() == 2
	var destino := Vector2(pos[0], pos[1]) if hay_posicion else Vector2.ZERO

	# El RPC sale SIEMPRE, con mudanza o sin ella: además de la posición
	# lleva la XP, de la que dependen vida_maxima y energia_maxima del
	# jugador AUTORITATIVO (ver _aplicar_estado_red). Si solo saliera sin
	# mudanza, quien reconectara fuera del nivel inicial quedaría en el
	# servidor con los topes de nivel 1.
	rpc_id(1, "_aplicar_estado_red", destino, vida,
		datos.get("xp_total", 0), hay_posicion and not se_muda)

	if hay_posicion and not se_muda:
		# Salto local inmediato (sin lerp): cargar partida es un
		# teletransporte, como reaparecer. El servidor aplica la misma
		# posición con autoridad (RPC de arriba).
		var jugador := _obtener_jugador()
		if jugador != null:
			jugador.global_position = destino
			if "_posicion_replicada" in jugador:
				jugador.set("_posicion_replicada", destino)
			if jugador.has_method(&"resetear_camara"):
				jugador.call(&"resetear_camara")

	partida_cargada.emit()


## SERVIDOR: aplica posición, XP y vida guardadas a la copia autoritativa del
## jugador que las pidió; el cliente las ve por la réplica.
##
## La XP va acá porque ExperienciaComponente.restaurar_xp() vuelve a aplicar
## el crecimiento de cada nivel alcanzado (vida_maxima, energia_maxima,
## atributos), y eso vive en el SERVIDOR: sin esto, un jugador reconectado
## tenía topes de nivel 1 y las curaciones no subían nada. Va ANTES de la
## vida porque el crecimiento cura de paso y restaurar_vida() pisa ese valor.
##
## aplicar_posicion en false = el cliente se está MUDANDO de nivel: la
## posición guardada es del nivel viejo y pisarla sería una carrera contra el
## teletransporte del portal. La XP y la vida se aplican igual.
@rpc("any_peer", "reliable")
func _aplicar_estado_red(pos: Vector2, vida: float, xp_total: int = 0,
		aplicar_posicion: bool = true) -> void:
	if not multiplayer.is_server():
		return
	var jugador := _jugador_de_peer(multiplayer.get_remote_sender_id())
	if jugador == null:
		return
	if aplicar_posicion:
		jugador.global_position = pos
	var experiencia := jugador.get_node_or_null("ExperienciaComponente")
	if experiencia:
		experiencia.restaurar_xp(xp_total)
	var componente := jugador.get_node_or_null("VidaComponente") as VidaComponente
	if componente:
		# Nunca cargar un muerto: mínimo 1 de vida.
		componente.restaurar_vida(maxf(vida, 1.0))


## Clave de la fila en la tabla "partidas", derivada de id_unico (NUNCA de
## nombre_visible, que se repite entre jugadores; ver
## Utils.id_jugador_local()). Siempre de SU copia autoritativa en el servidor,
## jamás de un dato leído de un paquete de red. "" si el jugador no existe o
## su identidad aún no llegó (ventana corta justo al conectar).
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
