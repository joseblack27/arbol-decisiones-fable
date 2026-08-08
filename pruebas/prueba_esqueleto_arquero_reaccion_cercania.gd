# =============================================================================
# Prueba de la reacción del Esqueleto Arquero cuando el jugador invade su
# espacio (distancia_peligro=120, ver EnemigoEsqueletoArquero.gd).
#
# NO se prueba fijando una semilla de azar y contando fotogramas hasta la
# 2ª decisión: entre medio corren otros sistemas del juego (deambular de
# otros mobs, tiradas de crítico, etc.) que también consumen randf() y
# corren la secuencia — una prueba así sería frágil y fallaría sola sin
# que nada esté roto. En cambio, cada rama se prueba invocando el método
# directo (mismo criterio que otras pruebas del proyecto, p. ej. la de
# mordida del Lobo llama habilidad_carga.activar() directo, sin pasar por
# el árbol de comportamiento completo):
#   1. Cadencia rápida: duracion_recuperacion baja a normal/1.5 y
#      _restablecer_cadencia_normal() la devuelve.
#   2. Retirada: dash en dirección contraria al jugador, hasta ~200px, y
#      duracion_recuperacion queda en la normal al terminar ("sigue
#      atacando normal" — pedido explícito del usuario).
# Por separado, un chequeo de integración confirma que estar "demasiado
# cerca" de verdad dispara ALGUNA reacción (sin importar cuál).
#   godot --headless --path . --script res://pruebas/prueba_esqueleto_arquero_reaccion_cercania.gd
# =============================================================================
extends SceneTree

var _mob
var _jugador
var _fotogramas := 0
var _fase := 0
var _recuperacion_normal := 0.0
var _pos_inicio_retirada := Vector2.ZERO

var _ok_cadencia := false
var _ok_retirada := false
var _ok_integracion := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fase:
		0:
			_montar()
			_fase = 1
		1:
			_probar_cadencia_rapida()
			_fase = 2
		2:
			if _probar_retirada():
				_fase = 3
		3:
			if _probar_integracion():
				_fase = 4
		4:
			return _informar()
	return false


func _montar() -> void:
	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)
	_jugador.global_position = Vector2.ZERO

	_mob = (load("res://escenas/enemigos/EnemigoEsqueletoArquero.tscn") as PackedScene).instantiate()
	_recuperacion_normal = _mob.get_node("ArbolComportamiento/Selector/Atacar").duracion_recuperacion
	root.add_child(_mob)
	_mob.global_position = Vector2(300, 0)
	_mob.memoria.establecer("objetivo", _jugador)
	_mob.memoria.establecer("jugador_detectado", true)


func _probar_cadencia_rapida() -> void:
	_mob._activar_cadencia_rapida()
	var rapida: float = _mob._accion_atacar.duracion_recuperacion
	_mob._restablecer_cadencia_normal()
	var restaurada: float = _mob._accion_atacar.duracion_recuperacion
	_ok_cadencia = absf(rapida - _recuperacion_normal / 1.5) < 0.001 \
		and absf(restaurada - _recuperacion_normal) < 0.001
	print("Cadencia normal=%.3f rápida=%.3f (esperada %.3f) restaurada=%.3f" % [
		_recuperacion_normal, rapida, _recuperacion_normal / 1.5, restaurada
	])


## Llama _iniciar_retirada() directo y deja correr la física real (el dash
## se procesa en _physics_process, no de un solo golpe) hasta que termine
## sola o hasta un tope de seguridad.
var _frames_retirada := 0

func _probar_retirada() -> bool:
	if _frames_retirada == 0:
		_pos_inicio_retirada = _mob.global_position
		_mob._iniciar_retirada(_jugador)
	_frames_retirada += 1
	if _mob._en_retirada and _frames_retirada < 200:
		return false
	var distancia_recorrida: float = _mob.global_position.distance_to(_pos_inicio_retirada)
	var cadencia_ok: bool = absf(_mob._accion_atacar.duracion_recuperacion - _recuperacion_normal) < 0.001
	# Margen holgado alrededor de _DISTANCIA_RETIRADA (200): el dash corta al
	# superarla, así que siempre se pasa un poco del valor exacto.
	_ok_retirada = distancia_recorrida > 170.0 and distancia_recorrida < 250.0 \
		and not _mob._en_retirada and cadencia_ok
	print("Retirada: recorrió %.1fpx (esperado ~200) en %d fotogramas, en_retirada=%s, cadencia normal=%s" % [
		distancia_recorrida, _frames_retirada, _mob._en_retirada, cadencia_ok
	])
	return true


## Reubica al arquero pegado al jugador (bien dentro de distancia_peligro) y
## confirma que reacciona de alguna de las dos formas (no le importa cuál) —
## la mecánica de "cada 5s" en sí anda.
##
## Reestablece memoria["objetivo"]/"jugador_detectado" acá (no solo confiar
## en lo que dejó _montar()): la retirada de la fase anterior aleja al mob
## hasta ~500px del jugador (300px iniciales + ~200px de dash), pasando el
## distancia_abandono (500) de AccionPerseguir — el árbol de comportamiento
## sigue corriendo DURANTE el dash (_en_retirada solo le saca el control del
## movimiento, no le apaga el tick), así que en la ventana entre que termina
## la retirada y que esta fase reubica al mob, un tick de AccionPerseguir
## puede alcanzar a limpiar memoria["objetivo"] a null. Sin esto la prueba
## quedaba intermitente por una carrera ajena a lo que quiere probar.
var _frames_integracion := 0
const _TOPE_FRAMES_INTEGRACION := 90

func _probar_integracion() -> bool:
	if _frames_integracion == 0:
		_mob.global_position = _jugador.global_position + Vector2(50, 0)
		_mob.memoria.establecer("objetivo", _jugador)
		_mob.memoria.establecer("jugador_detectado", true)
		_mob._tiempo_restante_decision = 0.0
		_mob._estaba_cerca = false
	_frames_integracion += 1

	var reacciono: bool = _mob._en_retirada \
		or absf(_mob._accion_atacar.duracion_recuperacion - _recuperacion_normal) > 0.001
	if not reacciono and _frames_integracion < _TOPE_FRAMES_INTEGRACION:
		return false

	_ok_integracion = reacciono
	print("Integración: tras estar pegado al jugador, reaccionó (retirada o cadencia)? %s (en %d fotogramas)" % [
		reacciono, _frames_integracion])
	return true


func _informar() -> bool:
	var exito := _ok_cadencia and _ok_retirada and _ok_integracion
	print("PRUEBA ESQUELETO ARQUERO REACCIÓN CERCANÍA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
