# =============================================================================
# GestorGrupos — Feature C del plan MMO. Sin transporte de red real (mismo
# criterio que prueba_tienda_comprar_item.gd): multiplayer.get_remote_
# sender_id() da 0 al llamar los _pedir_X_red() directo, así que "quién
# actúa" se simula renombrando el nodo Jugador correspondiente a "0" justo
# antes de cada llamada (ver _fijar_identidades) — los demás jugadores
# quedan con un nombre numérico propio y distinto, para poder targetearlos
# por peer_id en las invitaciones.
#
# Verifica: invitar/aceptar arma el grupo, tope de tamaño, expulsar (solo
# el líder puede), salir, el grupo se disuelve al quedar vacío, y que
# jugador_de_id_unico() resuelve por id_unico sin caché (simula una
# reconexión: el nodo viejo se libera, uno nuevo con el MISMO id_unico pero
# otro nombre/peer_id lo reemplaza, y sigue encontrándose).
#   godot --headless --path . --script res://pruebas/prueba_gestor_grupos_ciclo_completo.gd
# =============================================================================
extends SceneTree

var _gg
var _a
var _b
var _c
var _d
var _e

var _invitacion_y_aceptacion_arman_grupo_ok := false
var _tercer_miembro_se_suma_ok := false
var _tope_de_tamano_rechaza_ok := false
var _no_lider_no_puede_expulsar_ok := false
var _lider_expulsa_ok := false
var _salir_ok := false
var _grupo_se_disuelve_vacio_ok := false
var _reconexion_por_id_unico_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_invitacion_y_aceptacion()
	_probar_tercer_miembro()
	_probar_tope_de_tamano()
	_probar_expulsar()
	_probar_salir_y_disolver()
	_probar_reconexion_por_id_unico()
	return _informar()


func _montar() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(0)
	root.multiplayer.multiplayer_peer = peer
	_gg = root.get_node("/root/GestorGrupos")

	_a = _crear_jugador("Ana", "id_a")
	_b = _crear_jugador("Beto", "id_b")
	_c = _crear_jugador("Cora", "id_c")
	_d = _crear_jugador("Dana", "id_d")
	_e = _crear_jugador("Emi", "id_e")


func _crear_jugador(nombre: String, id_unico: String):
	var jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(jugador)
	jugador.nombre_visible = nombre
	jugador.id_unico = id_unico
	jugador.peer_id_dueño = 0
	return jugador


## Solo "actor" se llama "0" (lo que get_remote_sender_id() da sin
## transporte real, ver cabecera) — el resto recibe los nombres numéricos
## indicados en "otros", para poder targetearlos por peer_id.
##
## Dos pasadas (temporal, después real): si se asignara el nombre final
## directo, dos nodos podrían cruzarse de nombre (ej. Beto pasa a ser "2"
## justo cuando otro nodo YA se llama "2") y Godot resuelve esa colisión
## auto-incrementando el nombre a algo impredecible — se vio en la práctica,
## el segundo jugador en "aceptar" terminaba con un nombre que no era "0".
func _fijar_identidades(actor, otros: Dictionary) -> void:
	actor.name = "tmp_actor"
	var i := 0
	for nodo in otros:
		nodo.name = "tmp_%d" % i
		i += 1
	actor.name = "0"
	for nodo in otros:
		nodo.name = str(otros[nodo])
	# InteresEspacial cachea jugador_de_peer() por fotograma físico (ver ese
	# archivo) — renombrar DENTRO del mismo fotograma (sin transporte real
	# de por medio) necesita invalidar a mano.
	root.get_node("/root/InteresEspacial").invalidar_cache_jugadores()


func _probar_invitacion_y_aceptacion() -> void:
	_fijar_identidades(_a, {_b: 2, _c: 3, _d: 4, _e: 5})
	_gg._pedir_invitar_red(2)  # Ana invita a Beto.
	var invitacion_pendiente: bool = _gg._invitaciones.has("id_b") \
		and _gg._invitaciones["id_b"]["origen"] == "id_a"

	_fijar_identidades(_b, {_a: 1, _c: 3, _d: 4, _e: 5})
	_gg._pedir_aceptar_invitacion_red()  # Beto acepta.

	var grupo = _gg.grupo_de("id_a")
	_invitacion_y_aceptacion_arman_grupo_ok = invitacion_pendiente and grupo != null \
		and grupo == _gg.grupo_de("id_b") \
		and grupo["lider"] == "id_a" \
		and (grupo["miembros"] as Array).size() == 2
	print("Invitar + aceptar arma el grupo con Ana como líder (esperado true): %s" \
		% _invitacion_y_aceptacion_arman_grupo_ok)


func _probar_tercer_miembro() -> void:
	_fijar_identidades(_a, {_b: 2, _c: 3, _d: 4, _e: 5})
	_gg._pedir_invitar_red(3)  # Ana invita a Cora.
	_fijar_identidades(_c, {_a: 1, _b: 2, _d: 4, _e: 5})
	_gg._pedir_aceptar_invitacion_red()  # Cora acepta.

	var grupo = _gg.grupo_de("id_a")
	_tercer_miembro_se_suma_ok = grupo != null and (grupo["miembros"] as Array).size() == 3 \
		and (grupo["miembros"] as Array).has("id_c")
	print("Un tercer miembro se suma al mismo grupo (esperado true): %s" % _tercer_miembro_se_suma_ok)


func _probar_tope_de_tamano() -> void:
	# Grupo actual: Ana, Beto, Cora (3). Sumar a Dana lo lleva al tope (4).
	_fijar_identidades(_a, {_b: 2, _c: 3, _d: 4, _e: 5})
	_gg._pedir_invitar_red(4)
	_fijar_identidades(_d, {_a: 1, _b: 2, _c: 3, _e: 5})
	_gg._pedir_aceptar_invitacion_red()
	var tamano_en_tope: int = (_gg.grupo_de("id_a")["miembros"] as Array).size()

	# Con el grupo YA en TAMANO_MAXIMO_GRUPO (4), invitar a Emi debe rechazarse
	# sin crear ninguna invitación pendiente.
	_fijar_identidades(_a, {_b: 2, _c: 3, _d: 4, _e: 5})
	_gg._pedir_invitar_red(5)
	_tope_de_tamano_rechaza_ok = tamano_en_tope == _gg.TAMANO_MAXIMO_GRUPO \
		and not _gg._invitaciones.has("id_e")
	print("El grupo llega al tope (%d) y una invitación de más se rechaza (esperado true): %s" \
		% [_gg.TAMANO_MAXIMO_GRUPO, _tope_de_tamano_rechaza_ok])


func _probar_expulsar() -> void:
	# Dana (no es líder) intenta expulsar a Ana: debe rechazarse.
	_fijar_identidades(_d, {_a: 1, _b: 2, _c: 3, _e: 5})
	_gg._pedir_expulsar_red("id_a")
	_no_lider_no_puede_expulsar_ok = _gg.esta_en_grupo("id_a")
	print("Un miembro que no es líder no puede expulsar (esperado true): %s" \
		% _no_lider_no_puede_expulsar_ok)

	# Ana (líder) expulsa a Cora: sí debe funcionar.
	_fijar_identidades(_a, {_b: 2, _c: 3, _d: 4, _e: 5})
	_gg._pedir_expulsar_red("id_c")
	_lider_expulsa_ok = not _gg.esta_en_grupo("id_c") and _gg.esta_en_grupo("id_a")
	print("El líder expulsa a un miembro (esperado true): %s" % _lider_expulsa_ok)


func _probar_salir_y_disolver() -> void:
	# Grupo actual: Ana (líder), Beto, Dana. Beto sale por su cuenta.
	_fijar_identidades(_b, {_a: 1, _c: 3, _d: 4, _e: 5})
	_gg._pedir_salir_del_grupo_red()
	_salir_ok = not _gg.esta_en_grupo("id_b") and _gg.esta_en_grupo("id_a")
	print("Un miembro sale del grupo por su cuenta (esperado true): %s" % _salir_ok)

	# Ana y Dana salen también: el grupo tiene que desaparecer del todo.
	_fijar_identidades(_a, {_b: 2, _c: 3, _d: 4, _e: 5})
	_gg._pedir_salir_del_grupo_red()
	_fijar_identidades(_d, {_a: 1, _b: 2, _c: 3, _e: 5})
	_gg._pedir_salir_del_grupo_red()
	_grupo_se_disuelve_vacio_ok = not _gg.esta_en_grupo("id_a") and not _gg.esta_en_grupo("id_d") \
		and _gg._grupos.is_empty()
	print("El grupo se disuelve al quedar vacío (esperado true): %s" % _grupo_se_disuelve_vacio_ok)


## Simula una reconexión de verdad: el nodo viejo de Emi se libera (como
## haría ServidorDedicado._al_desconectar) y uno NUEVO con el MISMO
## id_unico pero un nombre de nodo distinto lo reemplaza — jugador_de_
## id_unico() tiene que encontrar el nuevo sin ninguna acción extra, porque
## nunca cachea la referencia (ver cabecera de GestorGrupos.gd).
func _probar_reconexion_por_id_unico() -> void:
	var encontrado_antes = _gg.jugador_de_id_unico("id_e")
	var era_el_nodo_viejo: bool = encontrado_antes == _e

	# free() directo (no queue_free): la baja tiene que ser YA, en el mismo
	# fotograma — queue_free() la difiere al final del fotograma, y como
	# esta prueba entera corre en un solo _process(), el nodo viejo seguiría
	# en el grupo "jugadores" al momento de resolver de nuevo, dando un
	# falso positivo de "todavía lo encuentra" sin probar nada real.
	_e.free()
	var nuevo_e = _crear_jugador("Emi", "id_e")
	nuevo_e.name = "99"

	var encontrado_despues = _gg.jugador_de_id_unico("id_e")
	_reconexion_por_id_unico_ok = era_el_nodo_viejo and encontrado_despues == nuevo_e
	print("jugador_de_id_unico() encuentra al nodo NUEVO tras una reconexión (esperado true): %s" \
		% _reconexion_por_id_unico_ok)


func _informar() -> bool:
	var exito := _invitacion_y_aceptacion_arman_grupo_ok and _tercer_miembro_se_suma_ok \
		and _tope_de_tamano_rechaza_ok and _no_lider_no_puede_expulsar_ok and _lider_expulsa_ok \
		and _salir_ok and _grupo_se_disuelve_vacio_ok and _reconexion_por_id_unico_ok
	print("PRUEBA GESTOR GRUPOS CICLO COMPLETO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
