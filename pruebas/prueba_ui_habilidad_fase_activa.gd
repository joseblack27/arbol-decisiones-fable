# =============================================================================
# Prueba de UIHabilidad + BusEventos.habilidad_fase_cambiada: el ÍCONO de una
# habilidad de dos etapas (ver HabilidadAcumulacion) cambia de color
# (modulate, parametrizable vía color_icono_fase_activa) mientras está en su
# segunda etapa — pedido del usuario: "después de usar la habilidad la
# primera vez, esta cambie de color para que se diferencie de la primera
# etapa" y después "lo que quiero que cambie es el color del ícono... con el
# modulate y que sea parametrizable" (no el fondo del botón, como se probó
# primero).
#
# Mismo patrón que prueba_ui_habilidad_solo_jugador_local.gd: la señal es
# GLOBAL (dispara para cualquier jugador visible en pantalla), así que el
# botón tiene que filtrar por jugador LOCAL y por slot_index — la fase de
# OTRO jugador, o de OTRO slot, no puede teñir este ícono.
#   godot --headless --path . --script res://pruebas/prueba_ui_habilidad_fase_activa.gd
# =============================================================================
extends SceneTree

var _boton
var _jugador_local
var _jugador_ajeno
var _fotogramas := 0

var _fase_ajena_no_afecta_ok := false
var _fase_propia_si_afecta_ok := false
var _color_cambia_ok := false
var _slot_equivocado_no_afecta_ok := false
var _vuelve_a_reposo_al_desactivar_ok := false
var _cambiar_slot_limpia_fase_ok := false
var _volver_a_la_pagina_restaura_el_color_ok := false
var _pagina_vacia_sin_cooldown_ajeno_ok := false
var _volver_restaura_el_cooldown_ok := false


static func _script_jugador_falso() -> GDScript:
	var guion := GDScript.new()
	guion.source_code = """
extends CharacterBody2D
var peer_id_dueño: int = -1
"""
	guion.reload()
	return guion




func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		5:
			_probar()
			return _informar()
	return false


func _montar() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(0)
	root.multiplayer.multiplayer_peer = peer
	var mi_id := root.multiplayer.get_unique_id()

	_jugador_local = CharacterBody2D.new()
	_jugador_local.set_script(_script_jugador_falso())
	_jugador_local.peer_id_dueño = mi_id
	_jugador_local.add_to_group("jugadores")
	root.add_child(_jugador_local)

	_jugador_ajeno = CharacterBody2D.new()
	_jugador_ajeno.set_script(_script_jugador_falso())
	_jugador_ajeno.peer_id_dueño = mi_id + 999
	_jugador_ajeno.add_to_group("jugadores")
	root.add_child(_jugador_ajeno)

	var escena := load("res://escenas/ui/ui_habilidad/UIHabilidad.tscn") as PackedScene
	_boton = escena.instantiate()
	_boton.slot_index = 0
	root.add_child(_boton)


func _probar() -> void:
	# La fase de un jugador AJENO no puede pintar mi botón.
	_boton._on_fase_cambiada(_jugador_ajeno, 0, true)
	_fase_ajena_no_afecta_ok = not _boton._fase_activa

	# La fase de OTRO slot (aunque sea mi jugador) tampoco.
	_boton._on_fase_cambiada(_jugador_local, 5, true)
	_slot_equivocado_no_afecta_ok = not _boton._fase_activa

	# Mi propia habilidad, en mi slot: ahora sí. Necesita una textura en el
	# ícono para que _refrescar_visual() le toque el modulate (si no hay
	# ícono equipado, no hay nada que teñir).
	_boton._icono.texture = PlaceholderTexture2D.new()
	_boton._on_fase_cambiada(_jugador_local, 0, true)
	_fase_propia_si_afecta_ok = _boton._fase_activa
	_color_cambia_ok = _boton._icono.modulate == _boton.color_icono_fase_activa

	# Al detonar (fase=false), el ÍCONO vuelve a su color normal.
	_boton._on_fase_cambiada(_jugador_local, 0, false)
	_vuelve_a_reposo_al_desactivar_ok = not _boton._fase_activa \
		and _boton._icono.modulate == _boton._COLOR_ICONO_NORMAL

	# Reportado: "el cambio de color de la habilidad de acumulación se queda
	# en el espacio y si cambio de página de habilidades la habilidad que se
	# coloque allí también queda con el color cambiado" — PaginadorHabilidades
	# reasigna este mismo botón físico a otro slot_index vía cambiar_slot();
	# sin limpiar _fase_activa ahí, el color de "segunda etapa" de Acumulación
	# quedaba pegado a lo que sea que ese botón mostrara después.
	_boton._on_fase_cambiada(_jugador_local, 0, true)  # deja el botón "en fase"
	_boton.cambiar_slot(1)
	_cambiar_slot_limpia_fase_ok = not _boton._fase_activa

	# Reportado a continuación: "al volver, si todavía está el efecto de
	# acumulación, no vuelve al color modificado sino que se queda normal,
	# debería de validarse eso" — si la habilidad que le toca mostrar SIGUE
	# de verdad en su segunda etapa (no una señal vieja, el estado real de
	# HabilidadAcumulacion), tiene que pintarse así de una al volver a esa
	# página, no en blanco a esperar una señal que no va a volver a llegar.
	var hab_acum = (load("res://escenas/habilidades/acumulacion/HabilidadAcumulacion.gd") as GDScript).new()
	hab_acum.entidad_dueña = _jugador_local
	_jugador_local.add_child(hab_acum)
	hab_acum._asegurar_componente()
	hab_acum._componente.activar(10.0, 0.3, 60.0, 0)  # la deja "acumulando" de verdad

	var datos_falsos := DatosHabilidad.new()
	datos_falsos.icono = PlaceholderTexture2D.new()

	# SlotHabilidades REAL (no un doble): _slot_habilidades está tipado como
	# SlotHabilidades en UIHabilidad, así que un Node genérico con script no
	# alcanzaría — se llenan _instancias/_datos_equipados a mano en vez de
	# pasar por equipar() (que pide DatosHabilidad.escena real).
	var slots := SlotHabilidades.new()
	root.add_child(slots)
	slots._instancias[0] = hab_acum
	slots._datos_equipados[0] = datos_falsos
	_boton._slot_habilidades = slots

	_boton.cambiar_slot(0)  # "vuelve" a la página donde vive la acumulación
	_volver_a_la_pagina_restaura_el_color_ok = _boton._fase_activa \
		and _boton._icono.modulate == _boton.color_icono_fase_activa

	# Reportado: "el cooldown visual también se pierde al paginar" — mismo
	# origen exacto: cambiar_slot() reseteaba _cd_ratio/_cd_restante a 0 a
	# ciegas en vez de consultar la recarga REAL de la habilidad que le toca
	# mostrar ahora, así que una que seguía en recarga de verdad se veía
	# lista para usar hasta la próxima señal de recarga_iniciada (que no
	# vuelve a llegar solo por cambiar de página).
	hab_acum.duracion_recarga = 5.0
	hab_acum._recarga_restante = 3.0
	_boton.cambiar_slot(1)  # se va de la página — el pastel debe reflejar SU habilidad (ninguna acá)
	_pagina_vacia_sin_cooldown_ajeno_ok = is_equal_approx(_boton._cd_restante, 0.0)
	_boton.cambiar_slot(0)  # vuelve a la página de la acumulación, todavía en recarga
	_volver_restaura_el_cooldown_ok = is_equal_approx(_boton._cd_restante, 3.0) \
		and is_equal_approx(_boton._cd_ratio, 3.0 / 5.0)


func _informar() -> bool:
	print("Fase de OTRO jugador no me afecta (esperado true): %s" % _fase_ajena_no_afecta_ok)
	print("Fase de OTRO slot no me afecta (esperado true): %s" % _slot_equivocado_no_afecta_ok)
	print("Mi propia fase SÍ me afecta (esperado true): %s" % _fase_propia_si_afecta_ok)
	print("El ícono se tiñe con color_icono_fase_activa (esperado true): %s" % _color_cambia_ok)
	print("El ícono vuelve a su color normal al desactivarse (esperado true): %s" % _vuelve_a_reposo_al_desactivar_ok)
	print("cambiar_slot() (paginador) limpia la fase pegada (esperado true): %s" % \
		_cambiar_slot_limpia_fase_ok)
	print("Volver a la página restaura el color si la habilidad SIGUE en fase activa (esperado true): %s" % \
		_volver_a_la_pagina_restaura_el_color_ok)
	print("Página sin esa habilidad no muestra un cooldown ajeno (esperado true): %s" % \
		_pagina_vacia_sin_cooldown_ajeno_ok)
	print("Volver a la página restaura el cooldown real (esperado true): %s" % \
		_volver_restaura_el_cooldown_ok)

	var exito := _fase_ajena_no_afecta_ok and _slot_equivocado_no_afecta_ok \
		and _fase_propia_si_afecta_ok and _color_cambia_ok and _vuelve_a_reposo_al_desactivar_ok \
		and _cambiar_slot_limpia_fase_ok and _volver_a_la_pagina_restaura_el_color_ok \
		and _pagina_vacia_sin_cooldown_ajeno_ok and _volver_restaura_el_cooldown_ok
	print("PRUEBA UI HABILIDAD FASE ACTIVA %s" % ("OK" if exito else "FALLIDA"))
	root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	quit(0 if exito else 1)
	return true
