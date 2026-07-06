# =============================================================================
# Prueba de object pooling (GestorPiscinas):
#   1. Un Proyectil liberado se REUTILIZA en la siguiente petición (misma
#      instancia, no una nueva) y queda listo para volar de nuevo.
#   2. Un NumeroDaño liberado (su propio tween) también se reutiliza.
#   3. liberar_todos_los_activos() recoge algo "en vuelo" sin liberar aún.
#   godot --headless --path . --script res://pruebas/prueba_object_pooling.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _escena_proyectil: PackedScene
var _escena_numero: PackedScene
var _primer_proyectil: Node
var _fuente: CharacterBody2D
# En modo --script el autoload no se resuelve como identificador global
# dentro del propio guion de prueba: se busca por ruta, como en el resto
# de pruebas de este proyecto.
var _piscinas: Node


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
			_probar_reutilizacion_proyectil()
			_probar_reutilizacion_numero()
			_probar_recogida_de_emergencia()
		5:
			return _informar()
	return false


func _montar() -> void:
	_piscinas = root.get_node("/root/GestorPiscinas")
	_escena_proyectil = load("res://escenas/habilidades/proyectil/Proyectil.tscn")
	_escena_numero = load("res://escenas/ui/numero_daño/NumeroDaño.tscn")
	_fuente = CharacterBody2D.new()
	_fuente.add_to_group(&"jugadores")
	root.add_child(_fuente)


var _ok_proyectil := false
var _ok_numero := false
var _ok_emergencia := false


func _probar_reutilizacion_proyectil() -> void:
	var p1: Node = _piscinas.call("obtener", _escena_proyectil)
	p1.call("configurar", Vector2.RIGHT, 1.0, 10.0, _fuente)
	_piscinas.call("liberar", p1)
	var p2: Node = _piscinas.call("obtener", _escena_proyectil)
	_ok_proyectil = (p1 == p2)
	print("Proyectil reutilizado (misma instancia): %s" % _ok_proyectil)
	_piscinas.call("liberar", p2)


func _probar_reutilizacion_numero() -> void:
	var n1: Node = _piscinas.call("obtener", _escena_numero)
	n1.call("configurar", 15.0, Vector2.ZERO)
	_piscinas.call("liberar", n1)
	var n2: Node = _piscinas.call("obtener", _escena_numero)
	_ok_numero = (n1 == n2)
	print("NumeroDaño reutilizado (misma instancia): %s" % _ok_numero)
	_piscinas.call("liberar", n2)


func _probar_recogida_de_emergencia() -> void:
	_primer_proyectil = _piscinas.call("obtener", _escena_proyectil)
	_primer_proyectil.call("configurar", Vector2.RIGHT, 1.0, 10.0, _fuente)
	# NO se libera a mano: simula un proyectil "en vuelo" al cambiar de nivel.
	_piscinas.call("liberar_todos_los_activos")
	var siguiente: Node = _piscinas.call("obtener", _escena_proyectil)
	_ok_emergencia = (siguiente == _primer_proyectil)
	print("Recogida de emergencia liberó el proyectil en vuelo: %s" % _ok_emergencia)
	_piscinas.call("liberar", siguiente)


func _informar() -> bool:
	var exito := _ok_proyectil and _ok_numero and _ok_emergencia
	print("PRUEBA OBJECT POOLING %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
