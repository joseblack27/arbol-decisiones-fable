extends Node

## true si el juego corre con un MultiplayerPeer de red real (ENet, servidor o
## cliente). multiplayer.has_multiplayer_peer() no sirve: en Godot 4 SIEMPRE da
## true, porque por defecto hay un OfflineMultiplayerPeer asignado. Usar esto
## en todo chequeo de "¿estoy en red?".
func en_red() -> bool:
	return not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)

## false SOLO en un cliente puro (en red y no servidor). Lo que aplica daño
## corre igual en el servidor y en cada cliente (predicción visual del propio
## golpe y réplica para espectadores, ver HabilidadBase.activar()), pero el
## número que calcula cada peer (con su propio randf() de crítico) no es el
## real. El número real lo emite VidaComponente._recibir_vida_red() a partir
## del delta de vida replicado; el resto no debe mostrar el suyo en un cliente
## puro (sí en el servidor y sin red, donde su cálculo ya es el real).
func debe_mostrar_dano_local() -> bool:
	return not (en_red() and not multiplayer.is_server())

## Puerto ENet del juego real (servidor dedicado en Docker y clientes). Es el
## valor por DEFECTO que precarga MenuInicio; Mundo.gd conecta con
## puerto_conexion.
const PUERTO_JUEGO := 8920

## Conexión elegida en MenuInicio.tscn (ver run/main_scene en project.godot).
## Vive en este autoload y no en MenuInicio porque esa escena se libera al
## pasar a Mundo.tscn, que la lee en Mundo._conectar_como_cliente().
## IP de LAN de la PC que corre el servidor Docker, precargada para no tener
## que escribirla desde el celular.
var ip_conexion := "192.168.40.27"
var puerto_conexion := PUERTO_JUEGO
## "" = usar nombre_jugador_local() de siempre (el de Windows/env var, ver
## abajo) — MenuInicio solo lo pisa si el jugador escribió algo distinto.
var nombre_conexion := ""
## PIN de la cuenta (ver GestorCuentas.resolver_cuenta): con PIN, la
## partida sigue al NOMBRE (cuenta en el servidor) y no al dispositivo —
## cambiar de celular ya no pierde el progreso. "" = sin cuenta, modo
## clásico por dispositivo (id_jugador_local).
var pin_conexion := ""
## Mensaje de error de la última conexión rechazada (PIN incorrecto...) —
## lo setea Jugador._rechazar_cuenta_red y lo muestra/limpia MenuInicio.
var error_conexion := ""

## true = este cliente se juega solo con BotIA.gd (lo agrega Jugador.gd en
## _ready()), para probar el servidor con varias instancias peleando por su
## cuenta. Lo tilda MenuInicio ("Controlar como bot") justo antes de cargar
## Mundo.tscn; a propósito NO se guarda en guardar_config.
var modo_bot := false

## Muestra en partida los datos de DIAGNÓSTICO (FPS, latencia, estado de
## conexión y log de red). Apagado por defecto: son herramientas de desarrollo.
## Se enciende desde MenuInicio o desde el panel de Configuración del OS (se
## guarda con el resto de la config), para diagnosticar en el celular sin
## recompilar.
var mostrar_depuracion := false

## Volumen de los efectos de sonido (0.0-1.0), del slider "Volumen SFX" de
## PanelConfiguracion. Lo vuelca al AudioServer GestorSonido.aplicar_volumen().
var volumen_sfx := 0.1

## Volumen de la música de fondo (0.0-1.0), del slider "Volumen Música" de
## PanelConfiguracion, separado de volumen_sfx. Lo vuelca al bus "Music"
## GestorMusica.aplicar_volumen().
var volumen_musica := 0.1

## SOLO para pruebas headless: el juego real es multijugador puro (Mundo
## reintenta conectarse para siempre), y las pruebas necesitan un jugador local
## determinista SIN tocar la red. Ver Mundo._arrancar_modo_prueba_local.
var modo_local_pruebas := false

## Nombre para mostrar del jugador de ESTA máquina (el nombre de usuario del
## sistema operativo; "Jugador" si no se puede leer). Cero configuración: en
## red viaja al servidor vía Jugador._registrar_identidad_red y se replica a
## todos los peers como Jugador.nombre_visible.
##
## OJO: es SOLO estético y puede repetirse entre jugadores. Para identidad
## real (la clave con la que el servidor guarda la partida) usar
## id_jugador_local(), NUNCA esto.
func nombre_jugador_local() -> String:
	if nombre_conexion != "":
		return nombre_conexion.substr(0, 24)
	for variable in ["USERNAME", "USER"]:  # Windows / Linux-Mac
		var nombre := OS.get_environment(variable).strip_edges()
		if nombre != "":
			return nombre.substr(0, 24)
	return "Jugador"


const _RUTA_ID_JUGADOR := "user://id_jugador.txt"
## Slots numerados para más de una ventana real en la MISMA PC (ver
## id_jugador_local()). El slot 0 es _RUTA_ID_JUGADOR de siempre (partidas ya
## guardadas); "_2", "_3"... son uno por ventana adicional.
const _RUTA_ID_JUGADOR_SLOT_N := "user://id_jugador_%d.txt"
const _RUTA_LOCK_SLOT_N := "user://id_jugador_%d.lock"
## Cuántas ventanas simultáneas en la misma PC se soportan antes de caer a una
## identidad de sesión sin persistir.
const _MAX_SLOTS_ID_JUGADOR := 8
## Un lock más viejo que esto se considera abandonado (la ventana se cerró o
## crasheó). Bastante más que _INTERVALO_HEARTBEAT_ID_JUGADOR, para no liberar
## el slot de una ventana viva por un tirón.
const _VENTANA_LOCK_ID_JUGADOR_SEGUNDOS := 6.0
const _INTERVALO_HEARTBEAT_ID_JUGADOR := 2.0

## UUID de bot para ESTA sesión (nunca se escribe a disco, ver
## id_jugador_local()). Vacío hasta la primera llamada en modo bot.
var _id_bot_actual := ""
## Cache: id_jugador_local() decide el slot UNA sola vez por proceso (el
## heartbeat necesita saber a qué archivo de lock seguir escribiéndole).
var _id_jugador_local_cache := ""

## Identidad ÚNICA y persistente de ESTE jugador en ESTA instalación: un UUID
## generado la primera vez y guardado en disco. El servidor lo usa como clave
## del archivo de guardado (ver GestorGuardado), así que no puede ser el nombre
## de usuario de Windows: "Usuario" o "Admin" se repiten y dos jugadores
## terminarían pisándose la partida.
##
## Viaja al servidor con el nombre (Jugador._registrar_identidad_red) pero
## nunca se muestra. No es autenticación (nada impide mandar el UUID de otro a
## propósito): solo elimina las colisiones accidentales.
func id_jugador_local() -> String:
	# "user://" es por INSTALACIÓN, no por proceso: todas las instancias en la
	# MISMA PC comparten id_jugador.txt, y dos bots (o un bot y el jugador real)
	# serían la misma cuenta reconectándose sin fin. Cada bot usa un UUID fresco
	# EN MEMORIA: una cuenta nueva cada vez que arranca.
	if modo_bot:
		if _id_bot_actual == "":
			_id_bot_actual = _generar_uuid()
		return _id_bot_actual
	if _id_jugador_local_cache != "":
		return _id_jugador_local_cache
	# Lo mismo con JUGADORES REALES sin PIN: dos ventanas en la misma PC con la
	# misma identidad se expulsan entre sí en bucle (ver
	# Jugador._expulsar_fantasma_de_la_misma_identidad). A diferencia de los
	# bots, acá el progreso importa: cada ventana adicional reclama su PROPIO
	# archivo numerado y lo mantiene vivo con un heartbeat mientras dure el
	# proceso, así cada una tiene una cuenta real y estable.
	for slot in _MAX_SLOTS_ID_JUGADOR:
		var ruta_id := _RUTA_ID_JUGADOR if slot == 0 else _RUTA_ID_JUGADOR_SLOT_N % slot
		var ruta_lock := _RUTA_LOCK_SLOT_N % slot
		if _lock_de_slot_activo(ruta_lock):
			continue  # otra ventana ya está usando este slot AHORA MISMO.
		_id_jugador_local_cache = _leer_o_crear_id_persistido(ruta_id)
		_iniciar_heartbeat_lock(ruta_lock)
		return _id_jugador_local_cache
	# Los _MAX_SLOTS_ID_JUGADOR están todos activos a la vez (rarísimo):
	# mejor una identidad de sesión sin persistir que romper la conexión.
	_id_jugador_local_cache = _generar_uuid()
	return _id_jugador_local_cache


func _leer_o_crear_id_persistido(ruta: String) -> String:
	if FileAccess.file_exists(ruta):
		var archivo := FileAccess.open(ruta, FileAccess.READ)
		var id := archivo.get_as_text().strip_edges()
		archivo.close()
		if id != "":
			return id
	var nuevo := _generar_uuid()
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo:
		archivo.store_string(nuevo)
		archivo.close()
	return nuevo


## true si "ruta" tiene un heartbeat MÁS RECIENTE que
## _VENTANA_LOCK_ID_JUGADOR_SEGUNDOS — es decir, otra ventana en esta PC
## está usando ese slot ahora mismo. Un lock viejo (ventana cerrada sin
## avisar, o crasheada) se trata como libre.
func _lock_de_slot_activo(ruta: String) -> bool:
	if not FileAccess.file_exists(ruta):
		return false
	var archivo := FileAccess.open(ruta, FileAccess.READ)
	var texto := archivo.get_as_text().strip_edges()
	archivo.close()
	if texto == "":
		return false
	return (Time.get_unix_time_from_system() - texto.to_float()) < _VENTANA_LOCK_ID_JUGADOR_SEGUNDOS


## Escribe el primer heartbeat YA (para que una segunda ventana que arranque
## un instante después ya vea el lock activo) y programa los siguientes.
func _iniciar_heartbeat_lock(ruta: String) -> void:
	_escribir_heartbeat_lock(ruta)
	var temporizador := Timer.new()
	temporizador.wait_time = _INTERVALO_HEARTBEAT_ID_JUGADOR
	temporizador.autostart = true
	temporizador.timeout.connect(_escribir_heartbeat_lock.bind(ruta))
	add_child(temporizador)


func _escribir_heartbeat_lock(ruta: String) -> void:
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo:
		archivo.store_string(str(Time.get_unix_time_from_system()))
		archivo.close()


## UUID v4-like: 128 bits al azar formateados como 8-4-4-4-12 en hex. No
## necesita ser criptográficamente perfecto (no es un secreto ni una
## contraseña) — solo tener suficiente entropía para que dos instalaciones
## distintas jamás generen el mismo por casualidad.
func _generar_uuid() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var bytes := PackedByteArray()
	for _i in 16:
		bytes.append(rng.randi() % 256)
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [
		hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4),
		hex.substr(16, 4), hex.substr(20, 12),
	]


## Nombre legible de cualquier entidad para logs/UI: usa nombre_visible si
## el nodo lo tiene con valor (jugadores), y si no cae al nombre de nodo de
## siempre (mobs, y jugadores cuyo nombre aún no llegó por red).
func nombre_visible(nodo: Node) -> String:
	if nodo == null or not is_instance_valid(nodo):
		return "???"
	if "nombre_visible" in nodo:
		var n: String = str(nodo.get("nombre_visible")).strip_edges()
		if n != "":
			return n
	return String(nodo.name)

## Devuelve el nodo Jugador que corresponde a ESTE peer. Con varios
## jugadores en el mismo árbol (multijugador real), el primero del grupo
## "jugadores" puede ser cualquiera — hay que filtrar por peer_id_dueño.
## Fuera de red (un solo jugador de siempre) cae al primero del grupo, el
## comportamiento de toda la vida. Usado por los facades GestorInventario/
## GestorEquipo/GestorExperiencia para no delegar en el jugador equivocado.
func jugador_local() -> Node:
	if not en_red():
		return get_tree().get_first_node_in_group("jugadores")
	var id := multiplayer.get_unique_id()
	for j in get_tree().get_nodes_in_group("jugadores"):
		if "peer_id_dueño" in j and j.peer_id_dueño == id:
			return j
	return null


## SERVIDOR, dentro de un RPC "any_peer": true solo si lo mandó el dueño real de
## "dueño" (un Jugador, con peer_id_dueño). Toda RPC que actúe en nombre de un
## jugador tiene que cortar con esto: "any_peer" deja que cualquiera la llame,
## y sin el chequeo un cliente modificado podría actuar por otro jugador.
## Sin red o fuera del servidor da false (sin red, el peer "offline" de Godot
## también se considera servidor, y no hay RPC que validar).
func pedido_del_dueño(dueño: Node) -> bool:
	if not en_red() or not multiplayer.is_server():
		return false
	if not is_instance_valid(dueño) or not ("peer_id_dueño" in dueño):
		return false
	return multiplayer.get_remote_sender_id() == dueño.peer_id_dueño


## Atajo: el SlotHabilidades del jugador propio (ver jugador_local()). Con 2+
## jugadores en el árbol, get_first_node_in_group("slot_habilidades") podía
## devolver el del OTRO jugador.
func slot_habilidades_local() -> SlotHabilidades:
	var jugador := jugador_local()
	if jugador == null:
		return null
	# Por tipo, no por nombre fijo: algunas pruebas arman su SlotHabilidades
	# a mano (load(...).new()) sin ponerle "SlotHabilidades" de nombre.
	for hijo in jugador.get_children():
		if hijo is SlotHabilidades:
			return hijo
	return null


## Atajo: el PasivasComponente del jugador propio (ver jugador_local()) —
## mismo criterio que slot_habilidades_local(), por tipo y no por nombre
## fijo (pruebas arman uno a mano con load(...).new()).
func pasivas_componente_local() -> PasivasComponente:
	var jugador := jugador_local()
	if jugador == null:
		return null
	for hijo in jugador.get_children():
		if hijo is PasivasComponente:
			return hijo
	return null


## Atajo: el MejorasComponente del jugador propio (ver jugador_local()) —
## mismo criterio que pasivas_componente_local().
func mejoras_componente_local() -> MejorasComponente:
	var jugador := jugador_local()
	if jugador == null:
		return null
	for hijo in jugador.get_children():
		if hijo is MejorasComponente:
			return hijo
	return null


## Atajo: el CreditosComponente del jugador propio (ver jugador_local()) —
## mismo criterio que mejoras_componente_local().
func creditos_componente_local() -> CreditosComponente:
	var jugador := jugador_local()
	if jugador == null:
		return null
	for hijo in jugador.get_children():
		if hijo is CreditosComponente:
			return hijo
	return null


## Atajo: el TiendaComponente del jugador propio (ver jugador_local()) —
## mismo criterio que mejoras_componente_local().
func tienda_componente_local() -> TiendaComponente:
	var jugador := jugador_local()
	if jugador == null:
		return null
	for hijo in jugador.get_children():
		if hijo is TiendaComponente:
			return hijo
	return null


## Atajo: el InventarioComponente del jugador propio (ver jugador_local()) —
## mismo criterio que mejoras_componente_local().
func inventario_componente_local() -> InventarioComponente:
	var jugador := jugador_local()
	if jugador == null:
		return null
	for hijo in jugador.get_children():
		if hijo is InventarioComponente:
			return hijo
	return null


## Atajo: el MisionesComponente del jugador propio (ver jugador_local()) —
## mismo criterio que mejoras_componente_local().
func misiones_componente_local() -> MisionesComponente:
	var jugador := jugador_local()
	if jugador == null:
		return null
	for hijo in jugador.get_children():
		if hijo is MisionesComponente:
			return hijo
	return null


## Atajo: el CofresComponente del jugador propio (ver jugador_local()) —
## mismo criterio que misiones_componente_local().
func cofres_componente_local() -> CofresComponente:
	var jugador := jugador_local()
	if jugador == null:
		return null
	for hijo in jugador.get_children():
		if hijo is CofresComponente:
			return hijo
	return null


func snake_to_pascal(text: String) -> String:
	var parts = text.split("_")
	var result := ""

	for p in parts:
		if p.length() > 0:
			result += p.capitalize()

	return result


## "0.5s" en vez de "1s" (%.0f redondea cualquier fracción a entero); un valor
## redondo sigue mostrando "1s", no "1.0s". Compartido por las descripciones de
## buffs que muestran segundos (Aura, Veneno, Curación...).
func formatear_segundos(valor: float) -> String:
	if is_equal_approx(valor, roundf(valor)):
		return "%ds" % int(valor)
	return "%.1fs" % valor


## Fila de íconos de los buffs de estado ACTIVOS de "buffs", centrada en el eje
## X local de "sobre" (el CanvasItem dueño del _draw que llama a esto), a la
## altura local "y". La usan Enemigo (fila arriba del nombre, en el mismo nodo
## que el texto) y Jugador (fila propia).
func dibujar_iconos_estado(sobre: CanvasItem, buffs: BuffsComponente, activos: Array[String],
		tamano: float, separacion: float, color_contorno: Color, y: float = 0.0) -> void:
	if buffs == null or activos.is_empty():
		return
	var iconos: Array[Texture2D] = []
	for id in activos:
		var buff := buffs.obtener(id)
		if buff != null and buff.icono != null:
			iconos.append(buff.icono)
	if iconos.is_empty():
		return
	var ancho_total := iconos.size() * tamano + (iconos.size() - 1) * separacion
	var x := -ancho_total / 2.0
	for icono in iconos:
		var rect := Rect2(Vector2(x, y), Vector2(tamano, tamano))
		sobre.draw_rect(rect, color_contorno)
		sobre.draw_texture_rect(icono, rect, false)
		x += tamano + separacion


## Texto y estado del botón "Mejorar" de una habilidad o pasiva: un texto claro
## para cada caso (nivel máximo, sin puntos, cuánto cuesta). Compartido por
## PanelDetalleHabilidad y PanelDetallePasiva.
func actualizar_boton_mejorar(boton: Button, al_tope: bool, sin_puntos: bool, costo: int) -> void:
	if al_tope:
		boton.text = "Nivel máximo"
	elif sin_puntos:
		boton.text = "Sin puntos suficientes"
	else:
		boton.text = "Mejorar (%d punto%s)" % [costo, "s" if costo != 1 else ""]
	boton.disabled = al_tope or sin_puntos


## Los dos estilos de fondo de las filas seleccionables de la lista de
## habilidades/pasivas (ItemHabilidad, ItemPasiva): blanco al presionar o
## enfocar, negro en reposo.
func crear_estilos_fila_seleccionable() -> Dictionary:
	var presionado := StyleBoxFlat.new()
	presionado.bg_color = Color.WHITE
	presionado.set_border_width_all(1)
	presionado.border_color = Color(0, 0, 0)

	var reposo := StyleBoxFlat.new()
	reposo.bg_color = Color.BLACK
	reposo.set_border_width_all(1)
	reposo.border_color = Color(0.267, 0.267, 0.267)

	return {"presionado": presionado, "reposo": reposo}


## Colorea todas las etiquetas de "labels" con "color" — usado por las
## mismas filas seleccionables de arriba para invertir el texto a negro
## cuando el fondo pasa a blanco (seleccionada/presionada), y de vuelta a
## blanco sobre fondo negro (reposo).
func colorear_labels(labels: Array[Label], color: Color) -> void:
	for label in labels:
		label.add_theme_color_override("font_color", color)


## Aplica "estilo" (ver crear_estilos_fila_seleccionable) a boton, para los
## estados "pressed" y "focus" — usado por las mismas filas seleccionables.
func aplicar_fondo_fila(boton: Button, estilo: StyleBoxFlat) -> void:
	boton.add_theme_stylebox_override("pressed", estilo)
	boton.add_theme_stylebox_override("focus", estilo)


# ── Preferencias persistentes ────────────────────────────────────────────────
## Archivo de las preferencias del jugador entre sesiones. Vive acá, junto a
## las variables que guarda, para que MenuInicio y el panel de Configuración
## del OS compartan una sola implementación.
const RUTA_CONFIG := "user://config_conexion.cfg"


## Vuelca las preferencias actuales al disco. Llamar SOLO al confirmar un
## cambio (no mientras el jugador escribe).
func guardar_config() -> void:
	var config := ConfigFile.new()
	config.set_value("conexion", "ip", ip_conexion)
	config.set_value("conexion", "puerto", puerto_conexion)
	config.set_value("conexion", "nombre", nombre_conexion)
	config.set_value("conexion", "pin", pin_conexion)
	config.set_value("conexion", "depuracion", mostrar_depuracion)
	config.set_value("conexion", "volumen_sfx", volumen_sfx)
	config.set_value("conexion", "volumen_musica", volumen_musica)
	config.save(RUTA_CONFIG)


## Lee las preferencias guardadas. Si no hay archivo (primera vez en este
## dispositivo), deja los valores de fábrica que ya trae este autoload.
func cargar_config() -> void:
	var config := ConfigFile.new()
	if config.load(RUTA_CONFIG) != OK:
		return
	ip_conexion       = config.get_value("conexion", "ip", ip_conexion)
	puerto_conexion   = config.get_value("conexion", "puerto", puerto_conexion)
	nombre_conexion   = config.get_value("conexion", "nombre", nombre_conexion)
	pin_conexion      = config.get_value("conexion", "pin", pin_conexion)
	mostrar_depuracion = config.get_value("conexion", "depuracion", mostrar_depuracion)
	volumen_sfx = config.get_value("conexion", "volumen_sfx", volumen_sfx)
	volumen_musica = config.get_value("conexion", "volumen_musica", volumen_musica)
	# GestorSonido/GestorMusica ya aplicaron el volumen por defecto en su
	# propio _ready() (arrancan ANTES de que MenuInicio llame acá) — hay que
	# volver a aplicarlo ahora que se leyó el de verdad, o el jugador escucha
	# el volumen de fábrica hasta el próximo cambio manual.
	GestorSonido.aplicar_volumen()
	GestorMusica.aplicar_volumen()


## Espera hasta que la malla de navegación DEL NIVEL de "nodo" responda
## consultas de verdad: recién cargado un nivel, la malla tarda unos
## physics_frame en sincronizar, y hasta entonces cualquier consulta devuelve
## Vector2.ZERO. La usan SpawnerMobs y los enemigos colocados a mano en una
## escena (que sin esto no se movían ni atacaban al entrar al nivel).
##
## OJO: ni map_get_iteration_id() != 0 ni "que el iteration_id no cambie
## durante N físicas" alcanzan: en un nivel grande el motor hace VARIAS pasadas
## de sincronización y se queda quieto entre una y otra. Por eso se le pregunta
## a la malla si ya contesta consultas (ver _malla_de_nivel_responde). Sin
## malla real (prueba aislada) vuelve enseguida.
const FRAMES_ESPERA_MALLA := 90
const _DISTANCIA_SONDA_MALLA := 1_000_000.0

func esperar_malla_de_nivel_lista(nodo: Node) -> void:
	# Ceder SIEMPRE al menos una física: llamar esto desde _ready() y volver
	# sin ningún await puede pisar código que asuma que ya pasó una física.
	await nodo.get_tree().physics_frame
	var mapa := GestorNiveles.mapa_navegacion_de(nodo)
	var intentos := 0
	while not _malla_de_nivel_responde(mapa) and intentos < FRAMES_ESPERA_MALLA:
		await nodo.get_tree().physics_frame
		intentos += 1


func _malla_de_nivel_responde(mapa: RID) -> bool:
	if NavigationServer2D.map_get_regions(mapa).is_empty():
		return true
	var sonda := Vector2(_DISTANCIA_SONDA_MALLA, _DISTANCIA_SONDA_MALLA)
	return NavigationServer2D.map_get_closest_point(mapa, sonda) != Vector2.ZERO


## Orden y etiqueta en español de cada campo de AtributosBase que se muestra en
## el detalle de un ítem (PanelInventario y PanelTienda). Solo se listan los
## bonos que el ítem realmente aporta (valor != 0).
const ETIQUETAS_ATRIBUTOS_ITEM := [
	["danos", "Daños"],
	["potencia", "Potencia"],
	["impacto", "Impacto"],
	["afliccion", "Aflicción"],
	["impulso", "Impulso"],
	["probabilidad_critico", "Prob. Crítico"],
	["dano_critico", "Daño Crítico"],
	["defensa", "Defensa"],
	["tenacidad", "Tenacidad"],
	["fortaleza", "Fortaleza"],
	["resistencia_fisica", "Resist. Física"],
	["resistencia_aire", "Resist. Aire"],
	["resistencia_agua", "Resist. Agua"],
	["resistencia_fuego", "Resist. Fuego"],
	["resistencia_tierra", "Resist. Tierra"],
]

## Reconstruye, dentro de "vbox", una fila por cada característica != 0 de
## "item": primero "Vida" si es un consumible con curación (ver DatosItem.
## curacion), después cada bono de equipo != 0 (nombre a la izquierda,
## valor a la derecha). free() inmediato (no queue_free): son filas nuevas
## sin señales ni procesos pendientes, y así la lista queda consistente en
## el mismo fotograma en que cambia el ítem seleccionado.
func llenar_caracteristicas_item(vbox: VBoxContainer, item: DatosItem) -> void:
	for hijo in vbox.get_children():
		hijo.free()
	if item == null:
		return
	if item.curacion > 0.0:
		_agregar_fila_caracteristica_item(vbox, "Vida", item.curacion)
	if item.bonos != null:
		for par in ETIQUETAS_ATRIBUTOS_ITEM:
			var campo: String = par[0]
			var etiqueta: String = par[1]
			var valor: float = item.bonos.get(campo)
			if valor == 0.0:
				continue
			_agregar_fila_caracteristica_item(vbox, etiqueta, valor)
	if item.conjunto != null:
		_agregar_fila_conjunto(vbox, item.conjunto)


## Tramos de conjunto y sus bonos (el nombre del conjunto se muestra arriba,
## junto a Tipo/Cantidad; ver PanelInventario._update_details). Las piezas
## puestas se cuentan desde GestorEquipo y no desde "item", así sirve igual
## mirando un ítem sin equipar o uno en la vidriera de un NPC (PanelTienda), y
## se entiende de un vistazo cuánto falta para el próximo tramo.
func _agregar_fila_conjunto(vbox: VBoxContainer, conjunto: ConjuntoDatos) -> void:
	var piezas_equipadas := 0
	for equipado in GestorEquipo.equipados:
		if equipado and equipado.conjunto == conjunto:
			piezas_equipadas += 1

	# Un pequeño espacio para que las estadísticas del objeto y los bonos de
	# conjunto se lean como dos bloques separados.
	var espaciador := Control.new()
	espaciador.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(espaciador)

	for tramo in conjunto.tramos:
		var activo: bool = piezas_equipadas >= tramo.piezas_requeridas
		var texto_estado := "✓" if activo else "(%d/%d)" % [piezas_equipadas, tramo.piezas_requeridas]
		_agregar_fila_indentada(vbox, "%d piezas" % tramo.piezas_requeridas, texto_estado)

		# Una fila por bono de cada tramo, para que se sepa QUÉ otorga.
		if tramo.bonos:
			for par in ETIQUETAS_ATRIBUTOS_ITEM:
				var campo: String = par[0]
				var etiqueta: String = par[1]
				var valor: float = tramo.bonos.get(campo)
				if valor == 0.0:
					continue
				var texto_valor := ("+%s" % _formatear_valor_caracteristica(valor)) if valor > 0.0 else _formatear_valor_caracteristica(valor)
				_agregar_fila_indentada(vbox, etiqueta, texto_valor)


## theme_override_font_sizes en un Control ancestro NO se hereda a los hijos:
## cada Label resuelve su propio tamaño. Las filas armadas por código lo
## aplican acá; las estáticas del .tscn tienen su propio override con el mismo
## valor en PanelInventario.tscn.
const _TAMANO_FUENTE_CARACTERISTICAS := 10


## Fila de conjunto, con el mismo margen izquierdo que
## _agregar_fila_caracteristica_item. Función propia porque acá el valor ya
## viene como texto ("✓", "(2/4)"), no como float con el "+" automático.
func _agregar_fila_indentada(vbox: VBoxContainer, etiqueta: String, valor_texto: String) -> void:
	var fila := HBoxContainer.new()
	var nombre := Label.new()
	nombre.text = etiqueta
	nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nombre.add_theme_font_size_override("font_size", _TAMANO_FUENTE_CARACTERISTICAS)
	var valor := Label.new()
	valor.text = valor_texto
	valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	valor.add_theme_font_size_override("font_size", _TAMANO_FUENTE_CARACTERISTICAS)
	fila.add_child(nombre)
	fila.add_child(valor)
	vbox.add_child(fila)


func _agregar_fila_caracteristica_item(vbox: VBoxContainer, etiqueta: String, valor: float) -> void:
	var fila := HBoxContainer.new()
	var nombre := Label.new()
	nombre.text = etiqueta
	nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nombre.add_theme_font_size_override("font_size", _TAMANO_FUENTE_CARACTERISTICAS)
	var cantidad := Label.new()
	cantidad.text = ("+%s" % _formatear_valor_caracteristica(valor)) if valor > 0.0 else _formatear_valor_caracteristica(valor)
	cantidad.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cantidad.add_theme_font_size_override("font_size", _TAMANO_FUENTE_CARACTERISTICAS)
	fila.add_child(nombre)
	fila.add_child(cantidad)
	vbox.add_child(fila)


## Evita el ".0" final en bonos con valor entero (10.0 -> "10"); conserva
## decimales cuando el bono realmente los tiene (2.5 -> "2.5").
func _formatear_valor_caracteristica(valor: float) -> String:
	if valor == floor(valor):
		return str(int(valor))
	return str(valor)
