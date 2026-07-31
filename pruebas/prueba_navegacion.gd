# =============================================================================
# Prueba de navegación: en la pradera, se ordena al lobo ir a un destino y se
# verifica que (a) la malla de navegación existe, (b) el agente calcula una
# ruta con varios puntos y (c) el lobo avanza hacia el destino.
#   godot --headless --path . --script res://pruebas/prueba_navegacion.gd
#
# El lobo lo pone la prueba, no SpawnerMobs: los mobs del spawner salen de un
# sorteo (tipo al azar de lista_mobs, posición al azar en radio_spawn), así
# que esperar a que aparezca un lobo hacía depender la prueba de dos dados —
# ~1 de cada 10 corridas no generaba ninguno, y cuando sí, sus vecinos podían
# caer al lado y la evasión RVO del agente (max_speed 100 > los 80 px/s del
# lobo) lo empujaba en círculos en vez de dejarlo ir al destino. Lo que esta
# prueba mira es el pathfinding, no el spawner (para eso están
# prueba_spawner_mobs y prueba_spawner_posicion_valida), así que el spawner se
# apaga y el escenario queda quieto y repetible.
# =============================================================================
extends SceneTree

const _ESCENA_LOBO := "res://escenas/enemigos/EnemigoLobo.tscn"

## Dónde se planta el lobo y hacia dónde se lo manda. Ambos puntos se validan
## contra la malla antes de medir nada (ver _preparar_lobo): si el nivel
## cambiara y alguno quedara fuera de lo transitable, la prueba lo dice con esas
## palabras en vez de fallar como si navegar estuviera roto.
const _ORIGEN_LOBO := Vector2.ZERO
const _DESPLAZAMIENTO_DESTINO := Vector2(300, 0)
## Distancia (px) máxima entre un punto y la malla para considerarlo transitable
## (misma tolerancia que usa SpawnerMobs para validar sus puntos de spawn).
const _TOLERANCIA_MALLA := 6.0

## Tope de físicas esperando a que la malla conteste consultas de posición.
const _FISICAS_ESPERA_MALLA := 180
## Tope de físicas para el trayecto. A velocidad_base=80 px/s hacen falta unas
## 225 para los 300 px; el resto es margen, NO un cronómetro ajustado: la
## medición corta apenas el agente avisa que llegó, así que este tope solo
## entra en juego cuando algo está de verdad roto.
const _FISICAS_MAXIMAS_TRAYECTO := 900

## Punto-sonda fuera de cualquier mapa, para preguntarle a la malla si ya está
## sincronizada (ver _malla_responde).
const _DISTANCIA_SONDA := 1_000_000.0

## Techo duro de fotogramas: pase lo que pase, esta prueba TERMINA.
## Los topes de arriba cubren las esperas previstas, pero no un error de script
## que aborte _process() a mitad todos los fotogramas (una escena que no carga,
## un nodo que no está): ahí nunca se llegaría a quit() y el SceneTree seguiría
## girando para siempre. Pasó de verdad con la versión anterior de esta prueba:
## _informar() reventaba con el lobo en null y el proceso quedó 50 minutos vivo
## sin emitir veredicto. Y el timeout de correr_todas.sh no salva: mata al .exe
## de consola, pero el proceso hijo de Godot (el que hace el trabajo) queda
## huérfano y sigue corriendo.
const _FOTOGRAMAS_TOPE_DURO := 3000

var _fotogramas := 0
var _fisicas := 0
var _fisicas_al_comandar := 0
var _lobo: CharacterBody2D
var _movimiento: Node
var _agente: NavigationAgent2D
var _destino := Vector2.ZERO
var _distancia_inicial := 0.0
var _comandado := false


func _init() -> void:
	# El movimiento ocurre en _physics_process, pero este script corre en el
	# bucle de idle: contar fotogramas de idle como si fueran físicas era medir
	# con una regla que se estira sola. El presupuesto se lleva en físicas.
	physics_frame.connect(func() -> void: _fisicas += 1)


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas > _FOTOGRAMAS_TOPE_DURO:
		print("FALLO: la prueba no llegó a ningún veredicto en %d fotogramas "
			% _FOTOGRAMAS_TOPE_DURO + "(revisá los errores de script de arriba).")
		print("PRUEBA NAVEGACIÓN FALLIDA")
		quit(1)
		return true
	if _fotogramas == 1:
		_montar()
		return false
	if not _comandado:
		return _esperar_malla_y_comandar()
	if _agente.is_navigation_finished() \
			or _fisicas - _fisicas_al_comandar >= _FISICAS_MAXIMAS_TRAYECTO:
		return _informar()
	return false


## Instancia la pradera con SpawnerMobs apagado ANTES de que el nivel entre al
## árbol (una vez dentro ya habría generado su tanda inicial).
func _montar() -> void:
	var nivel := (load("res://escenas/niveles/NivelPradera.tscn") as PackedScene).instantiate()
	var spawner := nivel.get_node_or_null("Enemigos/SpawnerMobs")
	if spawner != null:
		spawner.set("cantidad_inicial", 0)
		spawner.set("activo", false)
	root.add_child(nivel)
	current_scene = nivel


func _esperar_malla_y_comandar() -> bool:
	# El mapa del NIVEL, no el del mundo: desde que conviven varios niveles
	# a la vez cada uno tiene el suyo (ver NivelBase._crear_mapa_navegacion).
	var mapa := _mapa_del_nivel()
	if not _malla_responde(mapa):
		if _fisicas < _FISICAS_ESPERA_MALLA:
			return false
		print("FALLO: la malla de navegación no respondió consultas en %d físicas."
			% _FISICAS_ESPERA_MALLA)
		print("PRUEBA NAVEGACIÓN FALLIDA")
		quit(1)
		return true
	return _preparar_lobo(mapa)


## true cuando la malla ya contesta consultas de posición de verdad. Sondear un
## punto absurdamente lejano la delata: sincronizada devuelve su vértice
## transitable más cercano (jamás el origen del mundo), a medio hornear devuelve
## el Vector2.ZERO de "no encontrado" — y con ese ZERO de por medio el agente
## calcularía rutas contra un mapa incompleto.
func _malla_responde(mapa: RID) -> bool:
	if NavigationServer2D.map_get_regions(mapa).is_empty():
		return false
	return NavigationServer2D.map_get_closest_point(
		mapa, Vector2(_DISTANCIA_SONDA, _DISTANCIA_SONDA)
	) != Vector2.ZERO


func _preparar_lobo(mapa: RID) -> bool:
	_destino = _ORIGEN_LOBO + _DESPLAZAMIENTO_DESTINO
	for descripcion: Array in [["origen", _ORIGEN_LOBO], ["destino", _destino]]:
		var punto: Vector2 = descripcion[1]
		if punto.distance_to(NavigationServer2D.map_get_closest_point(mapa, punto)) \
				> _TOLERANCIA_MALLA:
			print("FALLO: el %s de la prueba (%s) no cae sobre la malla de la pradera."
				% [descripcion[0], punto])
			print("PRUEBA NAVEGACIÓN FALLIDA")
			quit(1)
			return true

	_lobo = (load(_ESCENA_LOBO) as PackedScene).instantiate()
	current_scene.get_node("Enemigos").add_child(_lobo)
	_lobo.global_position = _ORIGEN_LOBO
	# Apagar su IA para que el comando de la prueba no compita con el árbol.
	var ia := _lobo.get_node_or_null("ArbolComportamiento")
	if ia != null:
		ia.set("activo", false)
	_movimiento = _lobo.get_node("MovimientoComponente")

	_distancia_inicial = _lobo.global_position.distance_to(_destino)
	_movimiento.comandar_destino(_destino)
	_agente = _movimiento.get("agente_navegacion") as NavigationAgent2D
	_fisicas_al_comandar = _fisicas
	_comandado = true
	return false


func _informar() -> bool:
	var mapa := _mapa_del_nivel()
	var regiones := NavigationServer2D.map_get_regions(mapa).size()
	# Desde el componente: funciona igual con agente de escena o auto-creado.
	var puntos_ruta := _agente.get_current_navigation_path().size()
	var distancia_final := _lobo.global_position.distance_to(_destino)
	print("Regiones de navegación en el mapa: %d" % regiones)
	print("Puntos en la ruta del agente: %d" % puntos_ruta)
	print("Distancia al destino: %.0f -> %.0f (en %d físicas)" % [
		_distancia_inicial, distancia_final, _fisicas - _fisicas_al_comandar,
	])
	var exito := regiones > 0 and puntos_ruta >= 2 \
		and distancia_final < _distancia_inicial * 0.5
	print("PRUEBA NAVEGACIÓN %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true


## El mapa de navegación del nivel cargado. Cada nivel tiene el suyo desde que
## el servidor puede tener varios cargados a la vez, así que el del mundo
## (get_world_2d().navigation_map) ya no tiene ninguna región.
func _mapa_del_nivel() -> RID:
	# El nivel se cuelga directo de root en esta prueba (no hay contenedor
	# registrado en GestorNiveles), así que se lo busca ahí.
	for hijo in root.get_children():
		if hijo.has_method("mapa_navegacion"):
			return hijo.call("mapa_navegacion")
	return root.get_world_2d().navigation_map
