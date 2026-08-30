# =============================================================================
# Prueba de EscudoReflectanteComponente: además de reducir el daño entrante
# como EscudoComponente normal, la porción bloqueada vuelve contra quien
# atacó.
#   1. Escudo 100%: el dueño no pierde vida, la fuente pierde lo bloqueado.
#   2. Escudo 50%: el dueño pierde la mitad, la fuente recibe la otra mitad.
#   3. Sin fuente (null): no revienta, el dueño se protege igual.
#   4. fuente == dueño (auto-daño): no se refleja contra sí mismo.
#   godot --headless --path . --script res://pruebas/prueba_guardian_escudo_reflectante.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _dueño: Node2D
var _vida_dueño: VidaComponente
var _escudo: EscudoReflectanteComponente
var _fuente: Node2D
var _vida_fuente: VidaComponente

var _reflejo_100_ok := false
var _reflejo_50_ok := false
var _sin_fuente_ok := false
var _sin_auto_reflejo_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		3:
			_escudo.activar(5.0, 1.0)
			_vida_dueño.quitar_vida(40.0, _fuente)
		4:
			_reflejo_100_ok = is_equal_approx(_vida_dueño.obtener_vida(), 100.0) \
				and is_equal_approx(_vida_fuente.obtener_vida(), 60.0)
			print("Escudo 100%% - dueño intacto (100), fuente refleja 40 (esperado true): %s" % _reflejo_100_ok)
			_escudo.activar(5.0, 0.5)
			_vida_dueño.quitar_vida(40.0, _fuente)
		5:
			_reflejo_50_ok = is_equal_approx(_vida_dueño.obtener_vida(), 80.0) \
				and is_equal_approx(_vida_fuente.obtener_vida(), 40.0)
			print("Escudo 50%% - dueño pierde la mitad (80), fuente refleja la otra mitad (40) (esperado true): %s" % _reflejo_50_ok)
			_escudo.activar(5.0, 1.0)
			_vida_dueño.quitar_vida(30.0, null)
		6:
			_sin_fuente_ok = is_equal_approx(_vida_dueño.obtener_vida(), 80.0)
			print("Sin fuente (null) - dueño protegido, sin crash (esperado true): %s" % _sin_fuente_ok)
			_escudo.activar(5.0, 1.0)
			_vida_dueño.quitar_vida(20.0, _dueño)
		7:
			_sin_auto_reflejo_ok = is_equal_approx(_vida_dueño.obtener_vida(), 80.0)
			print("fuente == dueño - no se refleja contra sí mismo, sin crash (esperado true): %s" % _sin_auto_reflejo_ok)
			return _informar()
	return false


func _montar() -> void:
	var escena := Node2D.new()
	root.add_child(escena)
	current_scene = escena

	_dueño = Node2D.new()
	escena.add_child(_dueño)
	_vida_dueño = VidaComponente.new()
	_vida_dueño.name = "VidaComponente"
	_vida_dueño.salud_maxima = 100.0
	_dueño.add_child(_vida_dueño)
	_vida_dueño.restaurar_vida(100.0)
	_escudo = EscudoReflectanteComponente.new()
	_escudo.name = "EscudoComponente"
	_dueño.add_child(_escudo)

	_fuente = Node2D.new()
	escena.add_child(_fuente)
	_vida_fuente = VidaComponente.new()
	_vida_fuente.name = "VidaComponente"
	_vida_fuente.salud_maxima = 100.0
	_fuente.add_child(_vida_fuente)
	_vida_fuente.restaurar_vida(100.0)


func _informar() -> bool:
	var exito := _reflejo_100_ok and _reflejo_50_ok and _sin_fuente_ok and _sin_auto_reflejo_ok
	print("PRUEBA GUARDIAN ESCUDO REFLECTANTE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
