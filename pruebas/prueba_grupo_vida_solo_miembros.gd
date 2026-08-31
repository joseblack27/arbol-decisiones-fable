# =============================================================================
# Feature C del plan MMO (grupos): la vida de un miembro solo debe llegarle
# a SUS COMPAÑEROS de grupo, nunca a todos los jugadores (evita el ruido
# que motivó posponer "vida de todos los jugadores en pantalla" — ver
# GestorGrupos.notificar_cambio_vida). Camino real de punta a punta:
# VidaComponente.agregar_vida() -> señal cambio_valor_vida -> Jugador._on_
# vida_cambiada_para_grupo() -> GestorGrupos.notificar_cambio_vida().
#
# agregar_vida() en vez de quitar_vida(): el jugador recién creado arranca
# con invulnerabilidad de aparición (TIEMPO_INVULNERABILIDAD_APARICION),
# que bloquearía quitar_vida() — agregar_vida() no está gateada por eso, y
# lo único que importa acá es que el valor de salud_actual CAMBIE para
# disparar la señal, no si sube o baja.
#
# Verifica:
#   1. Tras el cambio, la vista de grupo de Ana Y de Beto (su compañero)
#      refleja la vida NUEVA y real de Ana.
#   2. Cora, sin ningún grupo, no tiene ninguna vista de grupo (vacía) —
#      estructuralmente no puede haber recibido nada de esto.
#   godot --headless --path . --script res://pruebas/prueba_grupo_vida_solo_miembros.gd
# =============================================================================
extends SceneTree

var _gg
var _a
var _b
var _c
var _vida_a


func _process(_delta: float) -> bool:
	_montar()
	return _probar()


func _montar() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(0)
	root.multiplayer.multiplayer_peer = peer
	_gg = root.get_node("/root/GestorGrupos")

	_a = _crear_jugador("Ana", "id_a")
	_b = _crear_jugador("Beto", "id_b")
	_c = _crear_jugador("Cora", "id_c")

	var id_grupo: String = _gg._crear_grupo("id_a")
	_gg._agregar_miembro(id_grupo, "id_b")
	# Cora queda deliberadamente afuera de cualquier grupo.

	_vida_a = _a.get_node("VidaComponente")
	_vida_a.salud_actual = 50.0  # deja margen para que agregar_vida() cambie algo real.


func _crear_jugador(nombre: String, id_unico: String):
	var jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(jugador)
	jugador.nombre_visible = nombre
	jugador.id_unico = id_unico
	jugador.peer_id_dueño = 0
	return jugador


func _probar() -> bool:
	_vida_a.agregar_vida(10.0)  # dispara cambio_valor_vida -> ... -> GestorGrupos.

	var vista_a: Dictionary = _gg._vista_de_grupo_para("id_a")
	var vista_b: Dictionary = _gg._vista_de_grupo_para("id_b")
	var vista_c: Dictionary = _gg._vista_de_grupo_para("id_c")

	var vida_a_en_vista := -1.0
	for miembro: Dictionary in (vista_a.get("miembros", []) as Array):
		if miembro.get("id_unico") == "id_a":
			vida_a_en_vista = miembro.get("vida")

	var vista_a_refleja_vida_real_ok: bool = vida_a_en_vista == _vida_a.obtener_vida()
	var vista_b_ve_al_mismo_grupo_ok: bool = vista_b.get("id_grupo", "") == vista_a.get("id_grupo", "") \
		and (vista_b.get("miembros", []) as Array).size() == 2
	var cora_sin_grupo_no_ve_nada_ok: bool = vista_c.is_empty()

	print("La vista de Ana refleja su vida real actual (%.1f, esperado true): %s" % [
		_vida_a.obtener_vida(), vista_a_refleja_vida_real_ok])
	print("Beto (compañero de grupo) ve el mismo grupo con ambos miembros (esperado true): %s" \
		% vista_b_ve_al_mismo_grupo_ok)
	print("Cora, sin grupo, no tiene ninguna vista de grupo (esperado true): %s" \
		% cora_sin_grupo_no_ve_nada_ok)

	var exito := vista_a_refleja_vida_real_ok and vista_b_ve_al_mismo_grupo_ok \
		and cora_sin_grupo_no_ve_nada_ok
	print("PRUEBA GRUPO VIDA SOLO MIEMBROS %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
