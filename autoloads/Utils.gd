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
## prototipos/red/, para poder correr ambos sin pisarse.
const PUERTO_JUEGO := 8920

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
func id_jugador_local() -> String:
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


func snake_to_pascal(text: String) -> String:
	var parts = text.split("_")
	var result := ""

	for p in parts:
		if p.length() > 0:
			result += p.capitalize()

	return result
