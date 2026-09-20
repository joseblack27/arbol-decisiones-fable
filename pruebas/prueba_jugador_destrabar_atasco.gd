# =============================================================================
# Regresión (bug reportado en juego real, 20 sep 2026): incluso después de
# suavizar el escalón cóncavo del Hormiguero (ver
# bug-hormiguero-escalon-concavo-tunel) y arreglar Parpadeo (ver
# bug-parpadeo-rayo-vs-forma-real), insistir mucho con Carga/Parpadeo
# contra la MISMA esquina todavía podía dejar al jugador incrustado en
# geometría del mapa -- un caso límite geométrico cada vez más raro pero
# no eliminado del todo. Se agregaron DOS redes de seguridad genéricas en
# Jugador.gd:
#   1. _esta_incrustado_en_pared() + _intentar_destrabar(): si el cuerpo
#      queda REALMENTE incrustado (no solo en contacto), se reubica solo
#      en el punto libre más cercano.
#   2. _verificar_sin_avanzar_y_forzar() (pedido explícito del usuario):
#      sin llegar a un solape real, si el jugador quiere moverse, NO está
#      bajo un estado que lo inmovilice a propósito (Cepo, aturdido, ver
#      componente_movimiento._contador_inmovilizacion) y aun así no
#      avanza durante un rato más largo, primero se intenta FORZAR el
#      movimiento en la dirección que está pidiendo (barrido de forma
#      real, mismo criterio que HabilidadParpadeo) y solo si eso tampoco
#      encuentra nada, se cae al mismo _intentar_destrabar() de arriba.
#
# Se llaman los métodos DIRECTO (sin pasar por _physics_process real) para
# no depender de cuándo corre el próximo fotograma físico de Godot --
# move_and_slide() real podría resolver un solape profundo por su cuenta
# en un solo paso (probado a mano armando esta prueba), lo que haría la
# prueba dependiente de un timing que no hace falta involucrar: lo que
# importa probar acá es la LÓGICA de detección/recuperación en sí, no el
# camino completo de la física real.
#   godot --headless --path . --script res://pruebas/prueba_jugador_destrabar_atasco.gd
# =============================================================================
extends SceneTree

var _f := 0
var _jugador
var _muro: StaticBody2D
var _muros_caja: Array[StaticBody2D] = []
const _RADIO_JUGADOR := 10.0  # CircleShape2D_8vwo7 (Jugador.tscn), default de Godot.
const _POS_CAMPO_ABIERTO := Vector2(1000, 1000)
const _POS_INMOVILIZADO := Vector2(1000, 1200)
const _POS_CAJA := Vector2(2000, 2000)
const _HUECO_CAJA := 18.0
const _MARCO_CAJA := 50.0

var _no_incrustado_al_solo_tocar_ok := false
var _si_incrustado_con_solape_real_ok := false
var _no_dispara_antes_del_umbral_ok := false
var _dispara_y_reubica_tras_umbral_ok := false
var _fuerza_movimiento_en_direccion_ok := false
var _inmovilizado_no_dispara_ok := false
var _cae_a_destrabar_si_direccion_bloqueada_ok := false


func _process(_delta: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar()
		# Margen de un par de fotogramas para que el servidor de física
		# registre de verdad los StaticBody2D recién agregados antes de
		# consultarlos con intersect_shape()/cast_motion() -- sin esto, el
		# primer chequeo podía dar "libre" aunque el muro ya estuviera
		# puesto en el árbol.
		3:
			_probar_contacto_normal_no_dispara()
			_probar_solape_real_se_detecta()
			_probar_umbral_y_reubicacion()
			_probar_fuerza_movimiento_en_direccion()
			_probar_inmovilizado_no_dispara()
			_probar_cae_a_destrabar_si_direccion_bloqueada()
			return _informar()
	return false


func _montar() -> void:
	var escena := Node2D.new()
	root.add_child(escena)
	current_scene = escena

	# Jugador.tscn PRIMERO -- fuerza que los autoloads que usan las
	# habilidades ya estén resueltos (ver memoria del proyecto).
	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	escena.add_child(_jugador)

	# Un solo muro grande a la derecha, borde izquierdo en x=100.
	_muro = StaticBody2D.new()
	_muro.collision_layer = 1
	_muro.global_position = Vector2(200, 0)
	var forma := CollisionShape2D.new()
	forma.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(200, 200)
	forma.shape = rect
	_muro.add_child(forma)
	escena.add_child(_muro)

	# Caja/marco de 4 paredes (bien lejos de todo lo demás) con un hueco en
	# el medio apenas más grande que el jugador -- mismo criterio que la
	# prueba de esquinas: encierra sin solapar, para probar la caída a
	# _intentar_destrabar() cuando la dirección pedida también está
	# bloqueada (a diferencia de _POS_CAMPO_ABIERTO, sin nada alrededor).
	_agregar_muro_caja(Rect2(-_MARCO_CAJA, -_MARCO_CAJA, _MARCO_CAJA - _HUECO_CAJA, _MARCO_CAJA * 2))  # izq
	_agregar_muro_caja(Rect2(_HUECO_CAJA, -_MARCO_CAJA, _MARCO_CAJA - _HUECO_CAJA, _MARCO_CAJA * 2))   # der
	_agregar_muro_caja(Rect2(-_HUECO_CAJA, -_MARCO_CAJA, _HUECO_CAJA * 2, _MARCO_CAJA - _HUECO_CAJA))  # arriba
	_agregar_muro_caja(Rect2(-_HUECO_CAJA, _HUECO_CAJA, _HUECO_CAJA * 2, _MARCO_CAJA - _HUECO_CAJA))   # abajo


func _agregar_muro_caja(rect_local: Rect2) -> void:
	var muro := StaticBody2D.new()
	muro.collision_layer = 1
	muro.global_position = _POS_CAJA + rect_local.position + rect_local.size / 2.0
	var forma := CollisionShape2D.new()
	forma.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = rect_local.size
	forma.shape = rect
	muro.add_child(forma)
	current_scene.add_child(muro)
	_muros_caja.append(muro)


func _probar_contacto_normal_no_dispara() -> void:
	# Justo tocando el borde del muro (x=100), sin penetrar -- contacto
	# normal (como pararse contra una pared a propósito), NO debería
	# contar como "incrustado".
	_jugador.global_position = Vector2(100.0 - _RADIO_JUGADOR, 0)
	_no_incrustado_al_solo_tocar_ok = not _jugador._esta_incrustado_en_pared()
	print("Tocar la pared de refilón, sin penetrar, NO cuenta como incrustado (esperado true): %s" % \
		_no_incrustado_al_solo_tocar_ok)


func _probar_solape_real_se_detecta() -> void:
	# 5px adentro del muro (más que _ATASCO_MARGEN_ACHIQUE=3) -- solape real.
	_jugador.global_position = Vector2(100.0 - _RADIO_JUGADOR + 5.0, 0)
	_si_incrustado_con_solape_real_ok = _jugador._esta_incrustado_en_pared()
	print("5px adentro de la pared SÍ cuenta como incrustado (esperado true): %s" % \
		_si_incrustado_con_solape_real_ok)


func _probar_umbral_y_reubicacion() -> void:
	# Reusa la posición incrustada del chequeo anterior.
	_jugador._tiempo_incrustado_atasco = 0.0
	_jugador._verificar_atasco_y_destrabar(0.01)
	_no_dispara_antes_del_umbral_ok = _jugador.global_position.x < 100.0
	print("Un solo fotograma incrustado todavía no dispara la reubicación (esperado true): %s" % \
		_no_dispara_antes_del_umbral_ok)

	# Forzar que ya pasó el umbral sostenido, sin esperar el tiempo real.
	_jugador._tiempo_incrustado_atasco = 999.0
	_jugador._verificar_atasco_y_destrabar(0.01)
	var pos_final = _jugador.global_position
	var punto_mas_cercano := Vector2(clampf(pos_final.x, 100.0, 300.0), clampf(pos_final.y, -100.0, 100.0))
	var se_solapa: bool = pos_final.distance_to(punto_mas_cercano) < _RADIO_JUGADOR
	_dispara_y_reubica_tras_umbral_ok = not se_solapa
	print("Tras pasar el umbral, se reubica fuera del muro (esperado true, pos=%s): %s" % [
		pos_final, _dispara_y_reubica_tras_umbral_ok])


## Campo abierto, sin ningún muro cerca -- el jugador "no avanza" (se
## fuerza el reloj interno) queriendo ir hacia la derecha; como ahí no hay
## nada bloqueando de verdad, _intentar_forzar_movimiento() debería
## encontrar los 48px completos libres y empujarlo ahí directo.
func _probar_fuerza_movimiento_en_direccion() -> void:
	_jugador.global_position = _POS_CAMPO_ABIERTO
	_jugador.direccion = Vector2.RIGHT
	_jugador._posicion_referencia_sin_avanzar = _POS_CAMPO_ABIERTO
	_jugador._tiempo_sin_avanzar_atasco = 999.0
	_jugador._verificar_atasco_y_destrabar(0.01)
	var avance = _jugador.global_position.distance_to(_POS_CAMPO_ABIERTO)
	_fuerza_movimiento_en_direccion_ok = avance > 40.0
	print("Sin nada bloqueando, se fuerza el movimiento en la dirección pedida (esperado true, avanzó %.1fpx): %s" % [
		avance, _fuerza_movimiento_en_direccion_ok])


## Mismo campo abierto, pero el jugador está inmovilizado (Cepo/aturdido,
## ver componente_movimiento._contador_inmovilizacion) -- NO debe disparar
## nada, ni forzar movimiento ni reubicar: es un estado alterado a
## propósito, no un bug.
func _probar_inmovilizado_no_dispara() -> void:
	_jugador.global_position = _POS_INMOVILIZADO
	_jugador.direccion = Vector2.RIGHT
	_jugador.componente_movimiento._contador_inmovilizacion = 1
	_jugador._posicion_referencia_sin_avanzar = _POS_INMOVILIZADO
	_jugador._tiempo_sin_avanzar_atasco = 999.0
	_jugador._verificar_atasco_y_destrabar(0.01)
	var avance = _jugador.global_position.distance_to(_POS_INMOVILIZADO)
	_inmovilizado_no_dispara_ok = avance < 1.0
	print("Inmovilizado a propósito (Cepo/aturdido) NO dispara nada (esperado true, avanzó %.1fpx): %s" % [
		avance, _inmovilizado_no_dispara_ok])
	_jugador.componente_movimiento._contador_inmovilizacion = 0


## Encerrado en la caja (ver _agregar_muro_caja), apuntando derecho hacia
## una de sus paredes -- _intentar_forzar_movimiento() no debería
## encontrar ni 8px libres en esa dirección exacta, así que tiene que
## caer a _intentar_destrabar() (cualquier hueco libre cercano) en vez de
## quedarse sin hacer nada.
func _probar_cae_a_destrabar_si_direccion_bloqueada() -> void:
	_jugador.global_position = _POS_CAJA
	_jugador.direccion = Vector2.RIGHT  # Derecho contra la pared derecha de la caja.
	_jugador._posicion_referencia_sin_avanzar = _POS_CAJA
	_jugador._tiempo_sin_avanzar_atasco = 999.0
	_jugador._verificar_atasco_y_destrabar(0.01)
	var pos_final = _jugador.global_position
	var se_solapa := false
	for muro in _muros_caja:
		var forma := (muro.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
		var medio := forma.size / 2.0
		var min_r: Vector2 = muro.global_position - medio
		var max_r: Vector2 = muro.global_position + medio
		var punto_mas_cercano := Vector2(clampf(pos_final.x, min_r.x, max_r.x), clampf(pos_final.y, min_r.y, max_r.y))
		if pos_final.distance_to(punto_mas_cercano) < _RADIO_JUGADOR:
			se_solapa = true
			break
	_cae_a_destrabar_si_direccion_bloqueada_ok = not se_solapa
	print("Con la dirección pedida bloqueada, cae a destrabar en cualquier hueco libre (esperado true, pos=%s): %s" % [
		pos_final, _cae_a_destrabar_si_direccion_bloqueada_ok])


func _informar() -> bool:
	var exito := _no_incrustado_al_solo_tocar_ok and _si_incrustado_con_solape_real_ok \
		and _no_dispara_antes_del_umbral_ok and _dispara_y_reubica_tras_umbral_ok \
		and _fuerza_movimiento_en_direccion_ok and _inmovilizado_no_dispara_ok \
		and _cae_a_destrabar_si_direccion_bloqueada_ok
	print("PRUEBA JUGADOR DESTRABAR ATASCO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
