# =============================================================================
# Prueba de HabilidadBuffEquipo ("Grito de guerra"): buff instantáneo de
# daño para vos y tus aliados cercanos.
#
# Verifica:
#   1. Al activarla, tanto quien la lanza como el aliado cercano reciben
#      el bono de daño (calcular_dano_saliente sube).
#   2. Ambos quedan con el buff visible en BuffsComponente.
#   3. El bono NO se guarda en AtributosComponente.base (sigue igual a
#      los valores de fábrica) — vive aparte, ver AtributosComponente.
#      agregar_bono_dano_temporal.
#   4. El bono SOBREVIVE a un recalcular_con_equipo() de por medio (bug
#      que se evitó a propósito: si viviera en "base", cambiar de equipo
#      mientras el buff está activo lo borraría, ver ese comentario).
#   5. El bono se quita solo al vencer (sin tocar nada a mano).
#   6. En red: un aliado AJENO solo se aplica el buff a SÍ MISMO si su
#      propio peer_id está en la lista que manda el servidor — no a
#      cualquiera (mismo criterio local-only que UIHabilidad/oclusión).
#   godot --headless --path . --script res://pruebas/prueba_buff_equipo.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _lanzador
var _aliado
var _habilidad

var _lanzador_recibe_bono := false
var _aliado_recibe_bono := false
var _ambos_ven_el_buff := false
var _base_del_aliado_intacta := false
var _bono_sobrevive_recalcular_equipo := false
var _bono_se_quita_al_vencer := false

var _rpc_aplica_si_estoy_en_la_lista := false
var _rpc_no_aplica_si_no_estoy_en_la_lista := false


static func _script_combatiente() -> GDScript:
	var guion := GDScript.new()
	guion.source_code = """
extends CharacterBody2D
var peer_id_dueño: int = -1
func quitar_vida(_c: float, _f: Node = null, _t: int = 2, _cr: bool = false) -> void:
	pass
"""
	guion.reload()
	return guion


func _crear_combatiente(pos: Vector2, dano_base: float) -> Node:
	var cuerpo := CharacterBody2D.new()
	cuerpo.set_script(_script_combatiente())
	cuerpo.add_to_group("jugadores")
	cuerpo.collision_layer = 8
	cuerpo.collision_mask = 0
	cuerpo.global_position = pos
	var forma := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 10.0
	forma.shape = circ
	cuerpo.add_child(forma)
	root.add_child(cuerpo)

	var atributos: Node = (load("res://componentes/AtributosComponente.gd") as GDScript).new()
	atributos.name = "AtributosComponente"
	var base := AtributosBase.new()
	base.danos = dano_base
	atributos.base = base
	cuerpo.add_child(atributos)
	return cuerpo


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
			_habilidad.activar(Vector2.ZERO, 1.0)
		2:
			_verificar_bono_aplicado()
			_verificar_base_intacta()
			var atributos_aliado := _aliado.get_node("AtributosComponente") as AtributosComponente
			atributos_aliado.recalcular_con_equipo([])
			_bono_sobrevive_recalcular_equipo = is_equal_approx(
				atributos_aliado.calcular_dano_saliente(0.0), 25.0)
			print("Bono sobrevive a recalcular_con_equipo() (esperado true): %s" % _bono_sobrevive_recalcular_equipo)
			_forzar_vencimiento(atributos_aliado)
		3:
			var atributos_aliado := _aliado.get_node("AtributosComponente") as AtributosComponente
			_bono_se_quita_al_vencer = is_equal_approx(atributos_aliado.calcular_dano_saliente(0.0), 10.0)
			print("Bono se quita solo al vencer (esperado true, vuelve a 10.0): %s" % _bono_se_quita_al_vencer)
			_probar_rpc_gating()
			return _informar()
	return false


func _montar() -> void:
	_lanzador = _crear_combatiente(Vector2.ZERO, 10.0)
	_aliado   = _crear_combatiente(Vector2(50, 0), 10.0)

	var contenedor := Marker2D.new()
	contenedor.name = "HabilidadesPrueba"
	_lanzador.add_child(contenedor)

	var guion := load("res://escenas/habilidades/buff_equipo/HabilidadBuffEquipo.gd") as GDScript
	_habilidad = guion.new()
	_habilidad.slot_index = 0
	_habilidad.radio_buff = 150.0
	_habilidad.bono_dano = 15.0
	_habilidad.duracion_buff = 10.0
	_habilidad.icono_buff = load("res://assets/iconos/icono_grito_guerra_32x32.png")
	_habilidad.costo_energia = 0.0
	_habilidad.duracion_recarga = 1.0
	contenedor.add_child(_habilidad)
	_habilidad.entidad_dueña = _lanzador


func _verificar_bono_aplicado() -> void:
	var atrib_lanzador := _lanzador.get_node("AtributosComponente") as AtributosComponente
	var atrib_aliado   := _aliado.get_node("AtributosComponente") as AtributosComponente
	_lanzador_recibe_bono = is_equal_approx(atrib_lanzador.calcular_dano_saliente(0.0), 25.0)
	_aliado_recibe_bono   = is_equal_approx(atrib_aliado.calcular_dano_saliente(0.0), 25.0)
	print("Lanzador recibe el bono (esperado true, daño 25.0): %s" % _lanzador_recibe_bono)
	print("Aliado cercano recibe el bono (esperado true, daño 25.0): %s" % _aliado_recibe_bono)

	var buffs_lanzador := _lanzador.get_node_or_null("BuffsComponente") as BuffsComponente
	var buffs_aliado   := _aliado.get_node_or_null("BuffsComponente") as BuffsComponente
	_ambos_ven_el_buff = buffs_lanzador != null and buffs_lanzador.esta_activo("buff_equipo_dano") \
		and buffs_aliado != null and buffs_aliado.esta_activo("buff_equipo_dano")
	print("Ambos ven el ícono de buff en BuffsComponente (esperado true): %s" % _ambos_ven_el_buff)


func _verificar_base_intacta() -> void:
	var atrib_aliado := _aliado.get_node("AtributosComponente") as AtributosComponente
	_base_del_aliado_intacta = is_equal_approx(atrib_aliado.base.danos, 10.0)
	print("AtributosComponente.base del aliado sigue en fábrica (esperado true, 10.0): %s" % _base_del_aliado_intacta)


## Salta directo al vencimiento del bono sin esperar los 10s reales de
## fotogramas — mismo criterio que otras pruebas de este proyecto que
## empujan un contador interno a mano en vez de correr cientos de frames.
func _forzar_vencimiento(atributos: AtributosComponente) -> void:
	for bono in atributos._bonos_temporales.values():
		bono.tiempo_restante = 0.001
	atributos._process(0.01)


func _probar_rpc_gating() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(0)
	root.multiplayer.multiplayer_peer = peer
	var mi_id := root.multiplayer.get_unique_id()

	# Caso 1: mi propio peer_id SÍ está en la lista que manda el "servidor".
	_lanzador.peer_id_dueño = mi_id
	var atrib_lanzador := _lanzador.get_node("AtributosComponente") as AtributosComponente
	for bono in atrib_lanzador._bonos_temporales.values():
		bono.tiempo_restante = 0.001
	atrib_lanzador._process(0.01)  # arranca de nuevo desde "sin bono" para esta prueba.

	_habilidad._recibir_buff_equipo_red([mi_id])
	_rpc_aplica_si_estoy_en_la_lista = is_equal_approx(atrib_lanzador.calcular_dano_saliente(0.0), 25.0)
	print("RPC aplica el buff cuando mi peer_id SÍ está en la lista (esperado true): %s" % _rpc_aplica_si_estoy_en_la_lista)

	# Caso 2: limpiar y probar con una lista que NO me incluye.
	for bono in atrib_lanzador._bonos_temporales.values():
		bono.tiempo_restante = 0.001
	atrib_lanzador._process(0.01)
	_habilidad._recibir_buff_equipo_red([mi_id + 999])
	_rpc_no_aplica_si_no_estoy_en_la_lista = is_equal_approx(atrib_lanzador.calcular_dano_saliente(0.0), 10.0)
	print("RPC NO aplica el buff cuando mi peer_id no está en la lista (esperado true): %s" % _rpc_no_aplica_si_no_estoy_en_la_lista)

	root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func _informar() -> bool:
	var exito := _lanzador_recibe_bono and _aliado_recibe_bono and _ambos_ven_el_buff \
		and _base_del_aliado_intacta and _bono_sobrevive_recalcular_equipo \
		and _bono_se_quita_al_vencer and _rpc_aplica_si_estoy_en_la_lista \
		and _rpc_no_aplica_si_no_estoy_en_la_lista
	print("PRUEBA BUFF EQUIPO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
