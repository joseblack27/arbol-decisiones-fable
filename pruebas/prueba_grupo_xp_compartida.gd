# =============================================================================
# Feature C del plan MMO (grupos): Enemigo._otorgar_xp ya solo le daba XP a
# _ultimo_atacante (last-hit). Ahora, si ese atacante pertenece a un grupo,
# cada compañero DENTRO de RADIO_PARTICIPACION_GRUPO_XP recibe la XP
# COMPLETA también (sin dividir, ver el comentario en Enemigo.gd).
#
# Verifica con un mob real (Lobo) y _ultimo_atacante fijado a mano (mismo
# punto de enganche exacto que usaría el combate real, sin necesitar
# reproducir todo el pipeline de daño):
#   1. El atacante (Ana) recibe la XP — comportamiento de siempre.
#   2. Beto, compañero de grupo DENTRO del radio, también recibe la XP
#      completa (no la mitad).
#   3. Cora, compañera de grupo pero FUERA del radio, no recibe nada extra.
#   4. Dana, cerca pero SIN estar en el grupo, no recibe nada.
#   godot --headless --path . --script res://pruebas/prueba_grupo_xp_compartida.gd
# =============================================================================
extends SceneTree

var _gg
var _mob
var _a
var _b
var _c
var _d

var _atacante_recibe_xp_ok := false
var _companero_cercano_recibe_xp_completa_ok := false
var _companero_lejano_no_recibe_ok := false
var _no_agrupado_no_recibe_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_reparto()
	return _informar()


func _montar() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(0)
	root.multiplayer.multiplayer_peer = peer
	_gg = root.get_node("/root/GestorGrupos")

	_a = _crear_jugador("Ana", "id_a", Vector2.ZERO)
	_b = _crear_jugador("Beto", "id_b", Vector2(300, 0))       # dentro de 600px.
	_c = _crear_jugador("Cora", "id_c", Vector2(2000, 0))      # fuera de 600px.
	_d = _crear_jugador("Dana", "id_d", Vector2(200, 0))       # cerca, pero sin grupo.

	# Grupo Ana+Beto+Cora armado directo (ya se probó el flujo de invitación
	# real en prueba_gestor_grupos_ciclo_completo.gd; acá solo importa el
	# reparto de XP, no repetir esa prueba).
	var id_grupo: String = _gg._crear_grupo("id_a")
	_gg._agregar_miembro(id_grupo, "id_b")
	_gg._agregar_miembro(id_grupo, "id_c")

	_mob = (load("res://escenas/enemigos/EnemigoLobo.tscn") as PackedScene).instantiate()
	root.add_child(_mob)
	_mob.global_position = Vector2.ZERO
	_mob._ultimo_atacante = _a  # mismo punto de enganche que usa el combate real.


func _crear_jugador(nombre: String, id_unico: String, posicion: Vector2):
	var jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(jugador)
	jugador.nombre_visible = nombre
	jugador.id_unico = id_unico
	jugador.peer_id_dueño = 0
	jugador.global_position = posicion
	return jugador


func _xp_de(jugador) -> int:
	return jugador.get_node("ExperienciaComponente").xp_total


func _probar_reparto() -> void:
	var xp_a_antes := _xp_de(_a)
	var xp_b_antes := _xp_de(_b)
	var xp_c_antes := _xp_de(_c)
	var xp_d_antes := _xp_de(_d)

	_mob._otorgar_xp(100)

	_atacante_recibe_xp_ok = _xp_de(_a) == xp_a_antes + 100
	_companero_cercano_recibe_xp_completa_ok = _xp_de(_b) == xp_b_antes + 100
	_companero_lejano_no_recibe_ok = _xp_de(_c) == xp_c_antes
	_no_agrupado_no_recibe_ok = _xp_de(_d) == xp_d_antes

	print("El atacante recibe la XP (esperado true): %s" % _atacante_recibe_xp_ok)
	print("El compañero de grupo cercano recibe la XP COMPLETA (esperado true): %s" \
		% _companero_cercano_recibe_xp_completa_ok)
	print("El compañero de grupo lejano no recibe nada (esperado true): %s" \
		% _companero_lejano_no_recibe_ok)
	print("Alguien cercano pero SIN grupo no recibe nada (esperado true): %s" \
		% _no_agrupado_no_recibe_ok)


func _informar() -> bool:
	var exito := _atacante_recibe_xp_ok and _companero_cercano_recibe_xp_completa_ok \
		and _companero_lejano_no_recibe_ok and _no_agrupado_no_recibe_ok
	print("PRUEBA GRUPO XP COMPARTIDA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
