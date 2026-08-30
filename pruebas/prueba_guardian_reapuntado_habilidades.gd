# =============================================================================
# Regresión: "el jefe no apunta las habilidades encima del jugador, algunas
# las tira antes y otras después". Barrido/Amague/Combo capturaban la
# dirección UNA sola vez al arrancar (0.6-0.7s antes de golpear de verdad)
# y nunca la volvían a leer — si el jugador se movía en el medio, el golpe
# salía apuntando a donde ESTABA, no a donde ESTÁ. Ahora los tres reapuntan
# en vivo (Barrido/Amague con _process() propio durante la pose, Combo
# recalculando en cada golpe de la cadena).
#
# Cada prueba arranca al jugador en una dirección, lo MUEVE a mitad de
# camino a otra completamente distinta, y confirma que el golpe conecta en
# la posición NUEVA (si siguiera apuntando a la vieja, no conectaría nada:
# está a 90°/180° de distancia, bien fuera del rectángulo/radio).
#   godot --headless --path . --script res://pruebas/prueba_guardian_reapuntado_habilidades.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _jefe
var _jugador
var _vida_jugador
var _memoria

var _barrido_reapunta_ok := false
var _amague_reapunta_ok := false
var _combo_reapunta_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		5:
			_jugador.global_position = Vector2(0, -150)  # al norte del jefe
			var barrido = _jefe.get_node("Habilidades/HabilidadBarridoGuardian")
			barrido.activar(Vector2.UP, 1.0)
		6:
			_jugador.global_position = Vector2(150, 0)  # se mueve al este
		90:
			# duracion_pose=0.6s del barrido, margen generoso.
			var perdida: float = 100000.0 - _vida_jugador.salud_actual
			_barrido_reapunta_ok = perdida > 0.0
			print("Barrido reapunta y conecta en la posición nueva (esperado true): %s (perdió %.1f)" % [
				_barrido_reapunta_ok, perdida])
			_vida_jugador.salud_actual = 100000.0
			_jugador.global_position = Vector2(0, -150)
			var amague = _jefe.get_node("Habilidades/HabilidadAmagueGuardian")
			amague.probabilidad_golpe_unico = 0.0  # forzar rama barrido, determinístico
			amague.activar(Vector2.UP, 1.0)
		91:
			_jugador.global_position = Vector2(150, 0)
		180:
			var perdida: float = 100000.0 - _vida_jugador.salud_actual
			_amague_reapunta_ok = perdida > 0.0
			print("Amague reapunta y conecta en la posición nueva (esperado true): %s (perdió %.1f)" % [
				_amague_reapunta_ok, perdida])
			_vida_jugador.salud_actual = 100000.0
			_jugador.global_position = Vector2(0, -150)
			var combo = _jefe.get_node("Habilidades/HabilidadComboGuardian")
			combo.cantidad_golpes = 3
			combo.intervalo_entre_golpes = 0.35
			combo.activar(Vector2.UP, 1.0)
		181:
			# Alcance real del combo (radio_golpe + alcance_golpe ≈ 116px) es
			# mucho menor que el largo del rectángulo de Barrido/Amague — más
			# cerca que en las pruebas de arriba, pero igual bien fuera del
			# radio del PRIMER golpe (apuntado al norte, que ya salió).
			_jugador.global_position = Vector2(90, 0)
		280:
			# 2 intervalos de 0.35s = 0.7s totales, margen generoso — para
			# entonces ya deberían haber salido el 2º y 3er golpe reapuntados
			# hacia la posición nueva.
			var perdida: float = 100000.0 - _vida_jugador.salud_actual
			_combo_reapunta_ok = perdida > 0.0
			print("Combo reapunta en golpes posteriores y conecta (esperado true): %s (perdió %.1f)" % [
				_combo_reapunta_ok, perdida])
			return _informar()
	return false


func _montar() -> void:
	var raiz := Node2D.new()
	root.add_child(raiz)
	current_scene = raiz

	var escena_jefe := load("res://escenas/enemigos/EnemigoGuardianQuebrado.tscn")
	_jefe = escena_jefe.instantiate()
	raiz.add_child(_jefe)
	_jefe.global_position = Vector2.ZERO

	var escena_jugador := load("res://escenas/jugador/Jugador.tscn") as PackedScene
	_jugador = escena_jugador.instantiate()
	_jugador.name = "1"
	raiz.add_child(_jugador)
	_vida_jugador = _jugador.get_node("VidaComponente")
	_vida_jugador.salud_maxima = 100000.0
	_vida_jugador.salud_actual = 100000.0
	_vida_jugador.cancelar_invulnerabilidad()

	_memoria = _jefe.get_node("ArbolComportamiento/MemoriaBT")
	_memoria.establecer("objetivo", _jugador)
	_jefe.get_node("ArbolComportamiento").activo = false


func _informar() -> bool:
	var exito := _barrido_reapunta_ok and _amague_reapunta_ok and _combo_reapunta_ok
	print("PRUEBA GUARDIAN REAPUNTADO HABILIDADES %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
