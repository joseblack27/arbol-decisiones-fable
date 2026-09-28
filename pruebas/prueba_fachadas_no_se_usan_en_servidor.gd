# =============================================================================
# GestorInventario/GestorExperiencia son el jugador LOCAL, que en el servidor
# no existe: usados ahí caían a una instancia de respaldo que no es de nadie y
# el botín o la XP se perdían sin aviso. El código de servidor tiene que usar
# el componente del jugador que corresponde.
#
# Con un ENetMultiplayerPeer de servidor (sin clientes), confirma:
#   1. El botín y la XP de un mob muerto sin atacante identificable NO pasan
#      por las fachadas (sus instancias de respaldo ni se crean).
#   2. Con un atacante que tiene InventarioComponente/ExperienciaComponente,
#      el ítem y la XP van a SUS componentes.
#   3. Sin red, sin atacante, siguen yendo a las fachadas (el jugador local de
#      una partida de un jugador).
#   godot --headless --path . --script res://pruebas/prueba_fachadas_no_se_usan_en_servidor.gd
# =============================================================================
extends SceneTree

const ITEM := "res://recursos/items/recursos/hoja_1.tres"

var _f := 0
var _mob
var _exito := true


func _process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		var peer := ENetMultiplayerPeer.new()
		peer.create_server(0)
		root.multiplayer.multiplayer_peer = peer
		_mob = (load("res://escenas/enemigos/EnemigoLobo.tscn") as PackedScene).instantiate()
		root.add_child(_mob)
		return false
	if _f == 2:
		_probar_servidor_sin_atacante()
		_probar_servidor_con_atacante()
		_probar_sin_red_sin_atacante()
		print("PRUEBA FACHADAS NO SE USAN EN SERVIDOR %s" % ("OK" if _exito else "FALLIDA"))
		quit(0 if _exito else 1)
		return true
	return false


func _tabla_con_item() -> Array[LootDrop]:
	var entrada := LootDrop.new()
	entrada.item = load(ITEM)
	entrada.probabilidad = 1.0
	var tabla: Array[LootDrop] = [entrada]
	return tabla


func _probar_servidor_sin_atacante() -> void:
	_mob.tabla_botin = _tabla_con_item()
	_mob._ultimo_atacante = null
	_mob._otorgar_botin()
	_mob._otorgar_xp_a(null, 10)
	var inv_respaldo = root.get_node("/root/GestorInventario")._respaldo
	var xp_respaldo = root.get_node("/root/GestorExperiencia")._respaldo
	var ok: bool = inv_respaldo == null and xp_respaldo == null
	_exito = _exito and ok
	print("En el servidor, sin atacante, las fachadas no se tocan (esperado true, respaldo inv=%s xp=%s): %s" % [
		inv_respaldo, xp_respaldo, ok])


func _probar_servidor_con_atacante() -> void:
	var atacante := Node2D.new()
	atacante.name = "AtacanteDePrueba"
	var inventario = (load("res://componentes/InventarioComponente.gd") as GDScript).new()
	inventario.name = "InventarioComponente"
	atacante.add_child(inventario)
	var experiencia = (load("res://componentes/ExperienciaComponente.gd") as GDScript).new()
	experiencia.name = "ExperienciaComponente"
	atacante.add_child(experiencia)
	root.add_child(atacante)
	_mob._ultimo_atacante = atacante
	_mob._otorgar_botin()
	_mob._otorgar_xp_a(atacante, 10)
	var ok: bool = inventario.items.size() == 1 and experiencia.xp_total == 10
	_exito = _exito and ok
	print("En el servidor, con atacante, van a SUS componentes (esperado true, ítems=%d xp=%d): %s" % [
		inventario.items.size(), experiencia.xp_total, ok])


func _probar_sin_red_sin_atacante() -> void:
	root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_mob._ultimo_atacante = null
	_mob._otorgar_botin()
	_mob._otorgar_xp_a(null, 10)
	var gestor_inv = root.get_node("/root/GestorInventario")
	var gestor_xp = root.get_node("/root/GestorExperiencia")
	var ok: bool = gestor_inv.items.size() == 1 and gestor_xp.xp_total == 10
	_exito = _exito and ok
	print("Sin red, sin atacante, van al jugador local (esperado true, ítems=%d xp=%d): %s" % [
		gestor_inv.items.size(), gestor_xp.xp_total, ok])
