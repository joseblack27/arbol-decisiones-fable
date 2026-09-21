# =============================================================================
# Regresión (bug reportado en juego real, 20 sep 2026): "en la reina no
# se le ve ninguno, ni veneno, ni cepo, nada" -- no era un bug puntual
# del ícono de Cepo (ver commit f5c537a), sino que NINGÚN jefe del juego
# podía mostrar NUNCA ningún debuff/buff. Causa real: Enemigo._crear_
# nombre_mob() cortaba de entrada si mostrar_nombre era false (los 5
# jefes -- EnemigoReinaHormigas, EnemigoCorazonCristal, EnemigoGuardian
# Quebrado, EnemigoHeraldoCorrupcion, EnemigoNucleoForja -- lo ponen en
# false porque tienen su propio cartel dedicado, NombreJefe/similar) --
# sin _nodo_nombre creado, ni _intentar_conectar_buffs_estado() ni
# _dibujar_iconos_estado_mob() se llamaban jamás.
#
# Confirma con la Reina de las Hormigas (mostrar_nombre=false real):
#   1. _nodo_nombre SE CREA igual (superficie de dibujo para los íconos),
#      aunque no haya texto de nombre que dibujar.
#   2. Agregar un debuff cualquiera a su BuffsComponente queda reflejado
#      en _buffs_activos (prueba de que _intentar_conectar_buffs_estado()
#      sí se conectó).
#   godot --headless --path . --script res://pruebas/prueba_jefe_muestra_debuff_sin_mostrar_nombre.gd
# =============================================================================
extends SceneTree

var _f := 0
var _reina

var _mostrar_nombre_es_false_ok := false
var _nodo_nombre_se_crea_igual_ok := false
var _sin_texto_de_nombre_ok := false
var _conecta_buffs_y_refleja_debuff_ok := false


func _process(_delta: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar()
		2:
			_verificar_nodo_nombre()
			_agregar_debuff_de_prueba()
		# Margen generoso: _intentar_conectar_buffs_estado() recién
		# encuentra el BuffsComponente (agregado DESPUÉS del _ready() de
		# la Reina) en el próximo reintento periódico (_INTERVALO_
		# REINTENTO_BUFFS = 0.5s) -- mismo criterio de margen que otras
		# pruebas de esta sesión con temporizadores reales de por medio.
		40:
			_verificar_conecta_buffs()
			return _informar()
	return false


func _montar() -> void:
	var escena := Node2D.new()
	root.add_child(escena)
	current_scene = escena

	_reina = (load("res://escenas/enemigos/EnemigoReinaHormigas.tscn") as PackedScene).instantiate()
	escena.add_child(_reina)


func _verificar_nodo_nombre() -> void:
	_mostrar_nombre_es_false_ok = not _reina.mostrar_nombre
	print("La Reina real tiene mostrar_nombre=false (esperado true): %s" % _mostrar_nombre_es_false_ok)

	_nodo_nombre_se_crea_igual_ok = _reina.get_node_or_null("NombreMob") != null
	print("_nodo_nombre (superficie de dibujo de íconos) se crea igual (esperado true): %s" % \
		_nodo_nombre_se_crea_igual_ok)

	_sin_texto_de_nombre_ok = _reina._texto_nombre == ""
	print("Pero sin texto de nombre (usa su propio cartel NombreJefe aparte, esperado true): %s" % \
		_sin_texto_de_nombre_ok)


func _agregar_debuff_de_prueba() -> void:
	var buffs := BuffsComponente.new()
	buffs.name = "BuffsComponente"
	_reina.add_child(buffs)
	buffs.agregar("veneno", null, 999.0, true, "Veneno", "de prueba")


func _verificar_conecta_buffs() -> void:
	_conecta_buffs_y_refleja_debuff_ok = _reina._buffs != null and _reina._buffs_activos.has("veneno")
	print("El debuff agregado queda reflejado (_intentar_conectar_buffs_estado SÍ se conectó, esperado true): %s" % \
		_conecta_buffs_y_refleja_debuff_ok)


func _informar() -> bool:
	var exito := _mostrar_nombre_es_false_ok and _nodo_nombre_se_crea_igual_ok \
		and _sin_texto_de_nombre_ok and _conecta_buffs_y_refleja_debuff_ok
	print("PRUEBA JEFE MUESTRA DEBUFF SIN MOSTRAR NOMBRE %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
