# =============================================================================
# Regresión: "los amagues tampoco muestran el area de golpe" — mismo fix
# que HabilidadBarridoGuardian (ver prueba_guardian_barrido_indicador.gd),
# aplicado a HabilidadAmagueGuardian: aparece un IndicadorZonaEfecto
# (rectángulo) durante la pose, sea cual sea la rama que termine
# resolviendo (barrido real o golpe único) — no delata cuál, solo por
# dónde.
#   godot --headless --path . --script res://pruebas/prueba_guardian_amague_indicador.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _jefe
var _jugador
var _amague
var _ok := true
var _vio_indicador_en_pose := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar()
		_amague.activar(Vector2.RIGHT, 1.0)
	var hay_indicador := false
	for hijo in current_scene.get_children():
		if hijo is IndicadorZonaEfecto:
			hay_indicador = true
			var poligono: PackedVector2Array = hijo.poligono
			if poligono.size() != 4:
				_ok = false
	if hay_indicador:
		_vio_indicador_en_pose = true
	if _fotogramas == 60:
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
	_jugador.global_position = Vector2(0, 120)
	var vida_jugador = _jugador.get_node("VidaComponente")
	vida_jugador.salud_maxima = 100000.0
	vida_jugador.salud_actual = 100000.0
	vida_jugador.cancelar_invulnerabilidad()

	_jefe.memoria.establecer("objetivo", _jugador)
	_amague = _jefe.get_node("Habilidades/HabilidadAmagueGuardian")


func _informar() -> bool:
	var sin_huerfanos := true
	for hijo in current_scene.get_children():
		if hijo is IndicadorZonaEfecto:
			sin_huerfanos = false
	if not sin_huerfanos:
		_ok = false
	print("Se vio el indicador durante la pose (esperado true): %s" % _vio_indicador_en_pose)
	print("Sin indicador huérfano tras terminar la pose (esperado true): %s" % sin_huerfanos)
	_ok = _ok and _vio_indicador_en_pose
	print("PRUEBA GUARDIAN AMAGUE INDICADOR %s" % ("OK" if _ok else "FALLIDA"))
	quit(0 if _ok else 1)
	return true
