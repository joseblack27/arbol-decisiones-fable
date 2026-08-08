# =============================================================================
# Prueba de la pasiva de gatillo "Instinto Vengador" (ver
# escenas/pasivas/instinto_vengador/PasivaInstintoVengador.gd): al recibir un
# golpe CRÍTICO, aturde 1 segundo a quien lo dio (EfectoAturdir, mismo patrón
# que HabilidadSacudida).
#
# Cubre:
#   1. Golpe crítico recibido por el dueño → el atacante queda con un
#      EfectoAturdir colgado.
#   2. Golpe NO crítico → no pasa nada.
#   3. Golpe crítico a OTRO jugador (no el dueño de la pasiva) → no pasa nada
#      (daño_aplicado es global, hay que filtrar por objetivo == dueño).
#   godot --headless --path . --script res://pruebas/prueba_pasiva_instinto_vengador.gd
# =============================================================================
extends SceneTree

var _dueño
var _ajeno
var _atacante
var _bus

var _aturde_en_critico_ok := false
var _no_aturde_sin_critico_ok := false
var _no_aturde_a_otro_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_critico_aturde()
	_probar_no_critico()
	_probar_golpe_a_otro()
	return _informar()


func _montar() -> void:
	_dueño = CharacterBody2D.new()
	_dueño.name = "Dueño"
	_dueño.add_to_group("jugadores")
	root.add_child(_dueño)

	_ajeno = CharacterBody2D.new()
	_ajeno.name = "Ajeno"
	_ajeno.add_to_group("jugadores")
	root.add_child(_ajeno)

	_atacante = CharacterBody2D.new()
	_atacante.name = "Atacante"
	root.add_child(_atacante)

	var pasiva := (load("res://escenas/pasivas/instinto_vengador/PasivaInstintoVengador.tscn") as PackedScene).instantiate()
	pasiva.entidad_dueña = _dueño
	_dueño.add_child(pasiva)

	_bus = root.get_node("/root/BusEventos")


func _tiene_aturdir(nodo: Node) -> bool:
	for hijo in nodo.get_children():
		if hijo is EfectoAturdir:
			return true
	return false


func _probar_critico_aturde() -> void:
	_bus.daño_aplicado.emit(_dueño, 20.0, _atacante, 0, true)
	print("Atacante aturdido tras crítico recibido (esperado true): %s" % _tiene_aturdir(_atacante))
	_aturde_en_critico_ok = _tiene_aturdir(_atacante)


func _probar_no_critico() -> void:
	var otro_atacante := CharacterBody2D.new()
	root.add_child(otro_atacante)
	_bus.daño_aplicado.emit(_dueño, 20.0, otro_atacante, 0, false)
	print("Sin crítico no aturde (esperado true, sin efecto): %s" % (not _tiene_aturdir(otro_atacante)))
	_no_aturde_sin_critico_ok = not _tiene_aturdir(otro_atacante)


func _probar_golpe_a_otro() -> void:
	var otro_atacante := CharacterBody2D.new()
	root.add_child(otro_atacante)
	_bus.daño_aplicado.emit(_ajeno, 20.0, otro_atacante, 0, true)
	print("Crítico a OTRO jugador no aturde (esperado true, sin efecto): %s" % (not _tiene_aturdir(otro_atacante)))
	_no_aturde_a_otro_ok = not _tiene_aturdir(otro_atacante)


func _informar() -> bool:
	var exito := _aturde_en_critico_ok and _no_aturde_sin_critico_ok and _no_aturde_a_otro_ok
	print("  crítico recibido aturde al atacante: %s" % _aturde_en_critico_ok)
	print("  sin crítico no aturde: %s" % _no_aturde_sin_critico_ok)
	print("  crítico a otro jugador no me afecta: %s" % _no_aturde_a_otro_ok)
	print("PRUEBA PASIVA INSTINTO VENGADOR %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
