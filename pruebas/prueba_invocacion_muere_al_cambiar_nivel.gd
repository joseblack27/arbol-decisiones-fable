# =============================================================================
# Prueba: el aliado invocado tiene que desvanecerse si su dueño cambia de
# nivel (cruza un portal) — pedido del usuario: "quiero que la invo muera si
# el jugador cambia de zona".
#
# El primer intento (chequear esto dentro de _physics_process, comparando
# nivel_de_jugador(dueño) contra el nivel propio en cada tick) NO alcanzaba:
# en cuanto el dueño se va y el nivel viejo se queda sin jugadores,
# GestorNiveles._actualizar_actividad_niveles() le pone PROCESS_MODE_DISABLED
# a TODO su subárbol para ahorrar CPU — el _physics_process del aliado deja
# de correr antes de poder notar el cambio, así que se quedaba vivo (aunque
# congelado) para siempre. Solución real: GestorNiveles.jugador_cambio_de_
# nivel, emitida en mover_peer_a_nivel mientras el nivel viejo TODAVÍA está
# despierto.
#
# Reusa el montaje multi-nivel de prueba_niveles_por_jugador.gd
# (GestorNiveles.preparar_servidor + mover_peer_a_nivel) para tener niveles
# reales cargados a la vez, igual que el servidor dedicado.
#   godot --headless --path . --script res://pruebas/prueba_invocacion_muere_al_cambiar_nivel.gd
# =============================================================================
extends SceneTree

const PRADERA := "res://escenas/niveles/NivelPradera.tscn"
const CUEVA := "res://escenas/niveles/NivelCueva.tscn"

var _gestor
var _jugador_a: CharacterBody2D
var _jugador_b: CharacterBody2D
var _aliado
var _fotogramas := 0

var _sigue_vivo_antes_de_viajar := false
var _muere_al_cambiar_nivel := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		3:
			_sigue_vivo_antes_de_viajar = is_instance_valid(_aliado) and not _aliado._muerto
			print("El aliado sigue vivo mientras el dueño no cambia de nivel (esperado true): %s" % \
				_sigue_vivo_antes_de_viajar)
			# jugador_b se queda en la Pradera: el nivel NO se vacía al viajar
			# jugador_a, así que esto prueba la señal en sí, no un efecto
			# colateral de que el nivel se haya dormido.
			_gestor.mover_peer_a_nivel(1, CUEVA)
		4:
			_muere_al_cambiar_nivel = not is_instance_valid(_aliado) or _aliado._muerto
			print("El aliado muere al cambiar el dueño de nivel (esperado true): %s" % _muere_al_cambiar_nivel)
			return _informar()
	return false


func _montar() -> void:
	_gestor = root.get_node("/root/GestorNiveles")
	var escena := Node2D.new()
	root.add_child(escena)
	current_scene = escena

	var contenedor := Node2D.new()
	contenedor.name = "ContenedorNivel"
	escena.add_child(contenedor)
	var jugadores := Node2D.new()
	jugadores.name = "Jugadores"
	escena.add_child(jugadores)

	# Igual que ServidorDedicado: registra el contenedor y prepara el nivel
	# inicial con la maquinaria real de niveles (no un doble aislado).
	_gestor.registrar(contenedor, null)
	_gestor.preparar_servidor(PRADERA)

	var escena_jugador := load("res://escenas/jugador/Jugador.tscn") as PackedScene
	# El nombre del nodo ES el peer id (ver Jugador.gd/GestorNiveles.nivel_de_jugador).
	_jugador_a = escena_jugador.instantiate()
	_jugador_a.name = "1"
	jugadores.add_child(_jugador_a)
	_jugador_b = escena_jugador.instantiate()
	_jugador_b.name = "2"
	jugadores.add_child(_jugador_b)
	_gestor.colocar_jugador_nuevo(1, _jugador_a)
	_gestor.colocar_jugador_nuevo(2, _jugador_b)

	var nivel = _gestor.nivel_de_jugador(_jugador_a)
	var enemigos: Node = nivel.get_node_or_null("Enemigos")

	var escena_aliado := load("res://escenas/enemigos/AliadoInvocado.tscn") as PackedScene
	_aliado = escena_aliado.instantiate()
	_aliado.dueño = _jugador_a
	# Bien larga a propósito: si "muere", tiene que ser por el cambio de
	# nivel, no porque coincida con que venció sola su duración.
	_aliado.activar(30.0)
	enemigos.add_child(_aliado, true)
	_aliado.global_position = _jugador_a.global_position


func _informar() -> bool:
	var exito := _sigue_vivo_antes_de_viajar and _muere_al_cambiar_nivel
	print("PRUEBA INVOCACION MUERE AL CAMBIAR NIVEL %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
