extends Node

## true si el juego corre con un MultiplayerPeer de red real (ENetMultiplayerPeer
## como servidor o cliente conectado) — a diferencia de
## multiplayer.has_multiplayer_peer(), que en Godot 4 SIEMPRE da true (por
## defecto hay un OfflineMultiplayerPeer asignado, nunca null). Usar esto en
## cualquier chequeo de "¿estoy en red?" del plan de multijugador — ver
## Jugador.gd, HabilidadBase.gd, VidaComponente.gd, Enemigo.gd,
## ArbolComportamiento.gd, SpawnerMobs.gd.
func en_red() -> bool:
	return not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)

## false SOLO en un cliente puro (en red, y no soy el servidor) — todo el
## que aplica daño (Arañazo, Proyectil, GolpeBasico, AreaEfecto, HabilidadCarga,
## HabilidadCargaJugador, muro.gd, EfectoDoT) corre igual en servidor Y en
## cada cliente (predicción visual del propio golpe + réplica para
## espectadores, ver HabilidadBase.activar()/_reproducir_visual_red) — pero
## el número que calculan ahí (AtributosComponente.calcular_pipeline, con
## su propio randf() de crítico) es SOLO SUYO, no el real: cada peer sacaba
## un número distinto para el MISMO golpe. El único número real lo emite
## VidaComponente._recibir_vida_red() a partir del delta de vida ya
## replicado — por eso el resto NO debe mostrar el suyo en un cliente puro
## (sí en el servidor y en single-player, donde su cálculo YA es el real).
func debe_mostrar_dano_local() -> bool:
	return not (en_red() and not multiplayer.is_server())

## Puerto ENet fijo del juego real (servidor dedicado en Docker + clientes
## locales) — distinto del puerto usado por los prototipos en
## prototipos/red/, para poder correr ambos sin pisarse. Sigue siendo el
## valor por DEFECTO que precarga MenuInicio — puerto_conexion (abajo) es lo
## que Mundo.gd usa de verdad para conectar.
const PUERTO_JUEGO := 8920

## Configuración de conexión elegida en MenuInicio.tscn (pantalla previa a
## Mundo.tscn, ver run/main_scene en project.godot) — Mundo._conectar_como_
## cliente() los lee de acá en vez de tener la IP hardcodeada. Viven en este
## autoload (no en MenuInicio, que se libera al cambiar de escena) para
## sobrevivir el change_scene_to_file hacia Mundo.tscn.
## IP de LAN de la PC que corre el servidor Docker — precargada de
## entrada para no tener que escribirla cada vez desde el celular. Si el
## servidor pasa a otra máquina/red, cambiar esto (o simplemente escribir la
## IP nueva en MenuInicio, que sigue funcionando igual).
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

## true = este cliente se juega solo (ver BotIA.gd, agregado por Jugador.gd
## en _ready() cuando esto está prendido) en vez de esperar input real —
## pedido del usuario: probar el servidor con varias instancias de Godot
## conectadas a la vez, viendo bots recorrer el mapa y pelear contra mobs
## por su cuenta. Lo tilda MenuInicio (checkbox "Controlar como bot") justo
## antes de cargar Mundo.tscn — a propósito NO se persiste en guardar_config
## (arranca destildado siempre, no es una preferencia de usuario real).
var modo_bot := false

## Muestra en partida los datos de DIAGNÓSTICO (contador de FPS, latencia,
## estado de conexión y el panel de log de red). Apagado por defecto: son
## herramientas de desarrollo, no información de juego — flotaban sueltas
## sobre el mapa, sin panel detrás, encimándose entre sí e ilegibles sobre
## el terreno claro. Se enciende desde MenuInicio (se guarda junto al resto
## de la config, ver guardar_config()) y desde el panel de Configuración del
## OS, para poder diagnosticar en el celular sin recompilar.

var mostrar_depuracion := false

## SOLO para pruebas headless (prueba_niveles, prueba_muerte_jugador...): el
## juego real es multijugador puro — Mundo reintenta conectarse para siempre
## y jamás arranca sin servidor. Las pruebas necesitan lo contrario: un
## jugador local determinista SIN tocar la red (ni conectarse de verdad al
## servidor Docker si está corriendo). Ver Mundo._arrancar_modo_prueba_local.
var modo_local_pruebas := false

## Nombre para mostrar del jugador de ESTA máquina (el nombre de usuario del
## sistema operativo; "Jugador" si no se puede leer). Cero configuración: en
## red viaja al servidor vía Jugador._registrar_identidad_red y se replica a
## todos los peers como Jugador.nombre_visible.
##
## OJO: esto es SOLO estético — puede repetirse entre jugadores distintos
## sin ningún problema ("Jose" y "Jose" está bien). Para identidad real
## (la clave con la que el servidor guarda la partida de cada uno) usar
## id_jugador_local(), NUNCA esto — ver esa función para el porqué.
func nombre_jugador_local() -> String:
	if nombre_conexion != "":
		return nombre_conexion.substr(0, 24)
	for variable in ["USERNAME", "USER"]:  # Windows / Linux-Mac
		var nombre := OS.get_environment(variable).strip_edges()
		if nombre != "":
			return nombre.substr(0, 24)
	return "Jugador"


const _RUTA_ID_JUGADOR := "user://id_jugador.txt"

## Identidad ÚNICA y persistente de ESTE jugador en ESTA instalación: un
## UUID generado una sola vez (la primera vez que el juego corre acá) y
## guardado en disco. Fase 0 del plan de escalado a MMO: antes esto era
## nombre_jugador_local() (el nombre de usuario de Windows) — con pocos
## jugadores de prueba nunca importó, pero con desconocidos reales es casi
## seguro que dos compartan un nombre de usuario común ("Usuario", "Admin",
## "PC", el nombre por defecto de muchas instalaciones de Windows), y como
## el servidor usa esa clave para el archivo de guardado (ver
## GestorGuardado._ruta_partida_de_peer), dos jugadores distintos terminaban
## compartiendo — y pisándose — la misma partida sin enterarse.
##
## Este UUID viaja al servidor junto con el nombre (Jugador._registrar_
## identidad_red) pero NUNCA se muestra en pantalla — es un identificador
## interno, no una cuenta con contraseña: no evita que alguien mande el UUID
## de otro a propósito (eso requeriría autenticación real, fuera de alcance
## acá), pero sí elimina las colisiones ACCIDENTALES, que eran el problema
## real a esta escala.
## UUID de bot para ESTA sesión — nunca tocar _RUTA_ID_JUGADOR (ver más
## abajo el porqué). Vacío hasta la primera llamada en modo bot.
var _id_bot_actual := ""

func id_jugador_local() -> String:
	# "user://" es por INSTALACIÓN, no por proceso — todas las instancias de
	# Godot corriendo en la MISMA PC (mismo usuario de Windows) comparten el
	# mismo id_jugador.txt. Sin este corte, 2+ bots (o un bot + el jugador
	# real) en la misma máquina terminaban con el MISMO id_jugador_local(),
	# así que el servidor los trataba como la MISMA cuenta reconectándose
	# una y otra vez — bug real reportado: "creaba el mundo en bucle...
	# movía a todos los jugadores a la misma posición". Un UUID fresco EN
	# MEMORIA (nunca escrito a disco) evita la colisión: cada bot es una
	# cuenta nueva cada vez que arranca, nunca comparte identidad con nadie.
	if modo_bot:
		if _id_bot_actual == "":
			_id_bot_actual = _generar_uuid()
		return _id_bot_actual
	if FileAccess.file_exists(_RUTA_ID_JUGADOR):
		var archivo := FileAccess.open(_RUTA_ID_JUGADOR, FileAccess.READ)
		var id := archivo.get_as_text().strip_edges()
		archivo.close()
		if id != "":
			return id
	var nuevo := _generar_uuid()
	var archivo := FileAccess.open(_RUTA_ID_JUGADOR, FileAccess.WRITE)
	if archivo:
		archivo.store_string(nuevo)
		archivo.close()
	return nuevo


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


## Atajo: el SlotHabilidades del jugador propio (ver jugador_local()). Antes
## la UI (UIHabilidad, IndicadorApunte, PanelDetalleHabilidad/Habilidades)
## usaba get_first_node_in_group("slot_habilidades") — con 2+ jugadores en
## el árbol, el "primero" podía ser el del OTRO jugador: los botones
## táctiles mostraban/equipaban la habilidad de quien no correspondía.
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


## "0.5s" en vez de "1s": %.0f redondea cualquier valor fraccionario a un
## entero, así que un intervalo/duración ajustado a algo como 0.5 se
## mostraba como "1s" (reportado en Aura: "tengo intervalo tick en 0,5 y
## allá sale 1s"). Compartido por cualquier descripción de buff que
## muestre segundos (Aura, Veneno, Curación...) para no repetir esta
## lógica en cada habilidad. Solo se ve el decimal cuando de verdad hace
## falta — un valor redondo como 1.0 sigue mostrando "1s", no "1.0s".
func formatear_segundos(valor: float) -> String:
	if is_equal_approx(valor, roundf(valor)):
		return "%ds" % int(valor)
	return "%.1fs" % valor


## Fila de íconos de los buffs de estado ACTIVOS de "buffs", centrada en el
## eje X local de "sobre" (el CanvasItem dueño del _draw que llama a esto),
## a la altura local "y" — compartido por Enemigo (fila arriba del nombre,
## por eso "y" != 0: comparte nodo con el texto del nombre) y Jugador (fila
## propia, "y" = 0.0 de sobra). Antes cada uno tenía su propia copia de este
## mismo bucle, ligeramente distinta.
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


## Texto/estado del botón "Mejorar" de una habilidad o pasiva — un estado
## claro para cada caso (nivel máximo / sin puntos / cuánto cuesta subir),
## en vez de mostrar siempre el mismo texto de costo sin importar por qué
## está deshabilitado (pedido del usuario). Compartido por
## PanelDetalleHabilidad y PanelDetallePasiva — antes cada uno tenía su
## propia copia de este mismo if/elif/else, y ya se desincronizaron una vez.
func actualizar_boton_mejorar(boton: Button, al_tope: bool, sin_puntos: bool, costo: int) -> void:
	if al_tope:
		boton.text = "Nivel máximo"
	elif sin_puntos:
		boton.text = "Sin puntos suficientes"
	else:
		boton.text = "Mejorar (%d punto%s)" % [costo, "s" if costo != 1 else ""]
	boton.disabled = al_tope or sin_puntos


## Los dos estilos de fondo que usan las filas seleccionables de la lista
## de habilidades/pasivas (ItemHabilidad, ItemPasiva): blanco al presionar/
## enfocar, negro en reposo — antes cada una construía los mismos
## StyleBoxFlat a mano, por separado.
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
## Archivo donde viven las preferencias del jugador entre sesiones. Vivía
## como método privado de MenuInicio, pero esa escena se libera al entrar al
## juego (change_scene_to_file), así que el panel de Configuración del OS no
## podía reusarla: quedaba duplicar la lista de claves en dos lados y que se
## desincronizaran con el tiempo. Acá, junto a las variables que guarda, hay
## una sola implementación para los dos.
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


## Espera hasta que la malla de navegación DEL NIVEL de "nodo" responda
## consultas de verdad, no solo que exista — recién cargado un nivel, la
## malla tarda unos physics_frame en terminar de bakear/sincronizar, y hasta
## entonces cualquier consulta de posición devuelve Vector2.ZERO ("no
## encontrado"). Extraído de SpawnerMobs (que ya esperaba esto antes de
## generar cualquier mob) para que CUALQUIER enemigo "colocado a mano" en
## una escena (ver EnemigoArañaReina, el único caso hoy — no pasa por
## SpawnerMobs así que nunca tenía esta espera) pueda usar el mismo
## mecanismo: reportado "no se mueve, no ataca" al pelear apenas se entra al
## nivel, con la malla todavía sin sincronizar.
##
## OJO: map_get_iteration_id() != 0 NO basta, y "que el iteration_id no
## cambie durante N físicas" TAMPOCO — en un nivel grande el motor hace
## VARIAS pasadas de sincronización y se queda quieto ENTRE pasada y pasada
## (en Pradera, el id se mantiene en 1 unas 7 físicas seguidas antes de
## saltar a 2, la sincronización real) — cualquier contador de estabilidad
## corto corta justo en esa meseta y cree estar listo. Por eso se le
## pregunta a la malla lo único que de verdad importa: ¿ya contesta
## consultas? (ver _malla_de_nivel_responde). Sin malla real (mundo sin
## nivel, prueba aislada) vuelve enseguida.
const FRAMES_ESPERA_MALLA := 90
const _DISTANCIA_SONDA_MALLA := 1_000_000.0

func esperar_malla_de_nivel_lista(nodo: Node) -> void:
	# Ceder SIEMPRE al menos una física: llamar esto desde _ready() (el nodo
	# todavía se está armando) y volver sin ningún await puede pisar código
	# que asuma que ya pasó al menos un físico.
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


## Orden y etiqueta en español de cada campo de AtributosBase que se muestra
## en el detalle de un ítem — extraído de PanelInventario (único dueño
## original) porque PanelTienda necesita exactamente lo mismo al elegir un
## equipable propio para vender. Solo se listan los bonos que el ítem
## realmente aporta (valor != 0).
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


func _agregar_fila_caracteristica_item(vbox: VBoxContainer, etiqueta: String, valor: float) -> void:
	var fila := HBoxContainer.new()
	var nombre := Label.new()
	nombre.text = etiqueta
	nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cantidad := Label.new()
	cantidad.text = ("+%s" % _formatear_valor_caracteristica(valor)) if valor > 0.0 else _formatear_valor_caracteristica(valor)
	cantidad.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fila.add_child(nombre)
	fila.add_child(cantidad)
	vbox.add_child(fila)


## Evita el ".0" final en bonos con valor entero (10.0 -> "10"); conserva
## decimales cuando el bono realmente los tiene (2.5 -> "2.5").
func _formatear_valor_caracteristica(valor: float) -> String:
	if valor == floor(valor):
		return str(int(valor))
	return str(valor)
