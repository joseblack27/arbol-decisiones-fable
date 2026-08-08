# =============================================================================
# Prueba de hacia dónde MIRA el lobo mientras prepara su embestida.
#
# Reportado por el usuario: "si el lobo está mirando hacia arriba y yo voy
# caminando hacia abajo y entro en su visión, se prepara para atacar pero se
# queda mirando hacia arriba, que fue donde me vio; aunque yo ya esté debajo
# cuando lanza el ataque, el sprite sigue siendo el de arriba a pesar de
# lanzarse hacia abajo".
#
# Causa: HabilidadCarga SÍ reapunta la embestida durante la preparación y
# actualizaba "direccion" del lobo — pero Enemigo._aplicar_presentacion da
# prioridad a "direccion_mirada", y AccionAtacar deja de refrescarla mientras
# hay un ataque en curso (corta antes). El intento de la habilidad quedaba
# pisado por una mirada vieja, y el sprite con ella.
#
# Verifica:
#   1. Durante la PREPARACIÓN la mirada sigue al objetivo: si el jugador se
#      pasa al otro lado, el lobo se da vuelta.
#   2. El blend de animación (lo que de verdad se ve) sigue esa mirada.
#   3. Arrancado el DASH la mirada se CONGELA en la dirección de la embestida:
#      un mob volando en línea recta no debe girar a mirar hacia atrás al
#      rebasar al jugador (comportamiento buscado, no un descuido).
#   godot --headless --path . --script res://pruebas/prueba_mirada_carga_lobo.gd
# =============================================================================
extends SceneTree

const ARRIBA := Vector2(0, -1)

var _f := 0
var _mob
var _jugador: CharacterBody2D
var _carga
var _tree: AnimationTree

var _mirada_al_empezar := Vector2.ZERO
var _mirada_en_dash := Vector2.ZERO

var _sigue_en_preparacion := false
var _blend_acompaña := false
var _congela_en_dash := false
var _vio_dash := false
var _giro_en_dash := false


func _process(_d: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar()
		2:
			# El lobo lo ve ARRIBA y empieza a preparar la embestida hacia ahí.
			_carga.activar(ARRIBA, 1.0)
			_mirada_al_empezar = _mob.direccion_mirada
		4:
			# El jugador cruza y queda DEBAJO del lobo, todavía en preparación.
			_jugador.global_position = Vector2(0, 300)
		# duracion_preparacion = 1s (60 fotogramas): acá sigue preparando.
		40:
			var mirada: Vector2 = _mob.direccion_mirada
			_sigue_en_preparacion = _carga.esta_preparando() and mirada.y > 0.5
			print("Preparando y ya mirando HACIA ABAJO (esperado true, mirada=%s, empezó en %s): %s" % [
				mirada, _mirada_al_empezar, _sigue_en_preparacion])
			var blend = _tree.get("parameters/IDLE/blend_position")
			_blend_acompaña = blend is Vector2 and (blend as Vector2).y > 0.5
			print("El blend de animación acompaña a la mirada (esperado true, %s): %s" % [
				blend, _blend_acompaña])
	# El dash es corto y su duración depende de la distancia recorrida, así
	# que la fase 3 se sigue por ESTADO y no por número de fotograma.
	if _carga.esta_cargando():
		if not _vio_dash:
			_vio_dash = true
			_mirada_en_dash = _mob.direccion_mirada
			# El jugador se va al otro lado en pleno vuelo: la mirada NO debe
			# seguirlo, el lobo va lanzado en línea recta.
			_jugador.global_position = Vector2(0, -600)
		elif _mob.direccion_mirada != _mirada_en_dash:
			_giro_en_dash = true
	elif _vio_dash:
		_congela_en_dash = not _giro_en_dash
		print("En pleno dash la mirada quedó congelada en %s (esperado true): %s" % [
			_mirada_en_dash, _congela_en_dash])
		return _informar()
	if _f > 400:
		print("FALLO: nunca se llegó a ver el dash.")
		return _informar()
	return false


func _montar() -> void:
	var escena := Node2D.new()
	root.add_child(escena)
	current_scene = escena

	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	escena.add_child(_jugador)
	_jugador.global_position = Vector2(0, -300)
	# Sin la protección de aparición: un invulnerable no es objetivo válido
	# para la visión de los mobs (ver VisionComponente._intentar_registrar).
	_jugador.get_node("VidaComponente").cancelar_invulnerabilidad()

	_mob = (load("res://escenas/enemigos/EnemigoLobo.tscn") as PackedScene).instantiate()
	escena.add_child(_mob)
	_mob.global_position = Vector2.ZERO
	# Se apaga el árbol de comportamiento: acá interesa SOLO qué hace la
	# habilidad con la mirada, sin que la IA mueva al lobo y cambie la
	# geometría a mitad de la medición.
	var arbol = _mob.get_node("ArbolComportamiento")
	arbol.activo = false
	_mob.memoria.establecer("objetivo", _jugador)

	_carga = _mob.get_node("Habilidades/HabilidadCarga")
	_tree = _mob.get_node("AnimacionComponente/AnimationTree")


func _informar() -> bool:
	var exito := _sigue_en_preparacion and _blend_acompaña and _congela_en_dash
	print("PRUEBA MIRADA CARGA LOBO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
