# =============================================================================
# Regresión (bug real reportado 19 sep 2026): "coloco 2 cepos, uno encima
# del otro, y hago que un enemigo los pise, solo pisa el primero y el
# segundo parece desactivarse porque no se cierra y se queda ahí hasta que
# se acaba el tiempo". Causa real: HabilidadCepo/HabilidadTrampa guardaban
# la copia visual del cliente en UNA sola referencia (_cepo_actual/
# _trampa_actual) — con dos cepos/trampas vivos a la vez, colocar el
# segundo pisaba la referencia al primero, y el aviso de activación del
# servidor (_activar_cepo_visual_red/_activar_trampa_visual_red, sin
# ninguna forma de saber CUÁL de los dos activó) siempre terminaba
# actuando sobre el último colocado. El otro se quedaba "puesto" para
# siempre en pantalla, aunque su copia real ya se hubiera activado, hasta
# que se le acababa el tiempo solo.
#
# Se llaman los métodos @rpc DIRECTO (sin armar una red real de 2 peers,
# mismo criterio que prueba_lanzallamas_detiene_canal_por_servidor.gd) —
# simula exactamente lo que le llega a un cliente puro: dos copias
# solo-visuales creadas (_mostrar_cepo_red/_mostrar_trampa_red) y el
# servidor avisando, por posición, cuál de las dos activó.
#   godot --headless --path . --script res://pruebas/prueba_cepo_trampa_multiples_apiladas.gd
# =============================================================================
extends SceneTree

var _hab_cepo
var _cepo1
var _cepo2

var _hab_trampa
var _trampa1
var _trampa2

var _cepo1_no_afectado_por_segundo_ok := false
var _cepo1_activa_correcto_ok := false
var _cepo2_activa_correcto_ok := false
var _icono_debuff_en_mob_ok := false

var _trampa1_no_afectada_por_segunda_ok := false
var _trampa1_activa_correcto_ok := false
var _trampa2_activa_correcto_ok := false


func _process(_delta: float) -> bool:
	_montar()
	_probar_cepo()
	_probar_trampa()
	return _informar()


func _montar() -> void:
	_hab_cepo = (load("res://escenas/habilidades/cepo/HabilidadCepo.gd") as GDScript).new()
	root.add_child(_hab_cepo)

	_hab_trampa = (load("res://escenas/habilidades/trampa/HabilidadTrampa.gd") as GDScript).new()
	root.add_child(_hab_trampa)


func _probar_cepo() -> void:
	# Sin esto _icono_debuff queda null (nunca pasó por aplicar_datos(), ver
	# HabilidadCepo.gd) y _anotar_icono_en_red() no haría nada -- mismo
	# criterio que cualquier HabilidadXxx de prueba con campos sueltos.
	_hab_cepo._icono_debuff = PlaceholderTexture2D.new()

	# Dos copias solo-visuales, como las vería un cliente puro -- dos
	# posiciones DISTINTAS (apiladas cerca, no exactamente iguales, para
	# poder identificar cada una en los chequeos).
	_hab_cepo._mostrar_cepo_red(Vector2(100, 0))
	_hab_cepo._mostrar_cepo_red(Vector2(100, 5))
	_cepo1 = _hab_cepo._cepos_activos[0]
	_cepo2 = _hab_cepo._cepos_activos[1]

	# Regresión (bug real reportado 19 sep 2026): "hay debuffos que no se
	# muestran correctamente, como el cepo cuando un mob la pisa" -- el
	# mob "atrapado" real que el servidor identifica por su NodePath (ver
	# Cepo._on_body_entrada/avisar_cepo_activado).
	var objetivo := Node2D.new()
	objetivo.name = "MobAtrapado"
	root.add_child(objetivo)

	# El servidor avisa que el PRIMERO (100,0) activó de verdad, atrapando a "objetivo".
	_hab_cepo._activar_cepo_visual_red(Vector2(100, 0), objetivo.get_path())

	_cepo1_activa_correcto_ok = _cepo1._activada
	print("Cepo en (100,0) se activa cuando el servidor avisa esa posición (esperado true): %s" % \
		_cepo1_activa_correcto_ok)

	_cepo1_no_afectado_por_segundo_ok = not _cepo2._activada
	print("El OTRO cepo (100,5) sigue 'puesto', no se activó por error (esperado true): %s" % \
		_cepo1_no_afectado_por_segundo_ok)

	var buffs := objetivo.get_node_or_null("BuffsComponente") as BuffsComponente
	_icono_debuff_en_mob_ok = buffs != null and buffs.esta_activo("cepo")
	print("El mob atrapado muestra el ícono de debuff 'cepo' EN ESTE CLIENTE (esperado true): %s" % \
		_icono_debuff_en_mob_ok)

	# Ahora el servidor avisa que el SEGUNDO también activó.
	_hab_cepo._activar_cepo_visual_red(Vector2(100, 5), objetivo.get_path())
	_cepo2_activa_correcto_ok = _cepo2._activada
	print("El segundo cepo también se activa cuando le toca (esperado true): %s" % \
		_cepo2_activa_correcto_ok)


func _probar_trampa() -> void:
	_hab_trampa._mostrar_trampa_red(Vector2(200, 0))
	_hab_trampa._mostrar_trampa_red(Vector2(200, 5))
	_trampa1 = _hab_trampa._trampas_activas[0]
	_trampa2 = _hab_trampa._trampas_activas[1]

	_hab_trampa._activar_trampa_visual_red(Vector2(200, 0))

	_trampa1_activa_correcto_ok = _trampa1._activada
	print("Trampa en (200,0) se activa cuando el servidor avisa esa posición (esperado true): %s" % \
		_trampa1_activa_correcto_ok)

	_trampa1_no_afectada_por_segunda_ok = not _trampa2._activada
	print("La OTRA trampa (200,5) sigue 'puesta', no se activó por error (esperado true): %s" % \
		_trampa1_no_afectada_por_segunda_ok)

	_hab_trampa._activar_trampa_visual_red(Vector2(200, 5))
	_trampa2_activa_correcto_ok = _trampa2._activada
	print("La segunda trampa también se activa cuando le toca (esperado true): %s" % \
		_trampa2_activa_correcto_ok)


func _informar() -> bool:
	var exito := _cepo1_activa_correcto_ok and _cepo1_no_afectado_por_segundo_ok and _cepo2_activa_correcto_ok \
		and _icono_debuff_en_mob_ok \
		and _trampa1_activa_correcto_ok and _trampa1_no_afectada_por_segunda_ok and _trampa2_activa_correcto_ok
	print("PRUEBA CEPO TRAMPA MULTIPLES APILADAS %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
