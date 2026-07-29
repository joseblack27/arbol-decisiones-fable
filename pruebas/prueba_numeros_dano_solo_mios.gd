# =============================================================================
# Prueba de que GestorNumerosDano solo muestra el número flotante cuando el
# jugador LOCAL está involucrado — como objetivo (recibió el golpe) o como
# fuente (lo provocó él) — nunca para golpes entre otras entidades que
# solo está mirando en pantalla (pedido del usuario).
#   godot --headless --path . --script res://pruebas/prueba_numeros_dano_solo_mios.gd
# =============================================================================
extends SceneTree

var _mi_jugador
var _enemigo_generico
var _otro_jugador
var _gestor
var _piscinas
var _fotogramas := 0

var _muestra_cuando_yo_recibo := false
var _muestra_cuando_yo_provoco := false
var _no_muestra_ajeno := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			var antes: int = _piscinas._activos.size()
			_gestor._al_aplicar_daño(_mi_jugador, 10.0, _enemigo_generico)
			_muestra_cuando_yo_recibo = _piscinas._activos.size() > antes
		3:
			var antes: int = _piscinas._activos.size()
			_gestor._al_aplicar_daño(_enemigo_generico, 10.0, _mi_jugador)
			_muestra_cuando_yo_provoco = _piscinas._activos.size() > antes
		4:
			var antes: int = _piscinas._activos.size()
			_gestor._al_aplicar_daño(_otro_jugador, 10.0, _enemigo_generico)
			_no_muestra_ajeno = _piscinas._activos.size() == antes
		5:
			return _informar()
	return false


func _montar() -> void:
	_gestor = root.get_node("/root/GestorNumerosDano")
	_piscinas = root.get_node("/root/GestorPiscinas")

	_mi_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_mi_jugador)

	_enemigo_generico = Node2D.new()
	root.add_child(_enemigo_generico)

	_otro_jugador = Node2D.new()
	root.add_child(_otro_jugador)


func _informar() -> bool:
	print("Muestra el número cuando YO recibo daño: %s" % _muestra_cuando_yo_recibo)
	print("Muestra el número cuando YO provoco daño: %s" % _muestra_cuando_yo_provoco)
	print("NO muestra el número de un golpe ajeno: %s" % _no_muestra_ajeno)

	var exito := _muestra_cuando_yo_recibo and _muestra_cuando_yo_provoco and _no_muestra_ajeno
	print("PRUEBA NUMEROS DANO SOLO MIOS %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
