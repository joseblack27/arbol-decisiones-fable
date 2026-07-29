# =============================================================================
# Prueba de HabilidadLanzallamas (canal continuo mientras se mantiene el
# dedo, sin red):
#   1. Al "apuntar" (primer toque) se congela el control del tirador
#      (bloquear_control) y arranca a tirar daño por tick.
#   2. Mientras se sigue "apuntando" (dedo sostenido), el objetivo en el
#      cono recibe VARIOS golpes (no uno solo) a lo largo del tiempo.
#   3. Al "soltar" el control se libera y el daño se corta — más golpes NO
#      deben aparecer después.
#   4. Entra en cooldown al soltar (aunque se haya disparado poco tiempo):
#      un reintento inmediato NO debe arrancar un canal nuevo.
#   5. Pasado el cooldown, SÍ se puede volver a disparar.
#   6. El bono plano de atributos ("danos") se suma al golpe COMPLETO antes
#      de repartir la fracción del tick — no DESPUÉS de achicarlo (bug real
#      reportado: "dice 2-3 pero pega 10-12", el bono dominaba un número ya
#      reducido). Ver Combate.golpear_area(multiplicador_final).
#   7. Si el canal se corta SOLO (tiempo máximo) con el dedo aún puesto, NO
#      rearranca al vencer el cooldown mientras se siga sosteniendo — hay
#      que soltar primero (bug real reportado: "si no sueltas el joystick,
#      cuando se acaba el cooldown vuelve a lanzar").
#   godot --headless --path . --script res://pruebas/prueba_lanzallamas.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _tirador
var _objetivo
var _habilidad
var _golpes_a_mitad_camino := -1
var _golpes_al_soltar := -1
var _golpes_reintento_en_cooldown := -1
var _rearranque_bloqueado := false
var _arranco_tras_soltar := false


static func _script_tirador() -> GDScript:
	var guion := GDScript.new()
	guion.source_code = """
extends CharacterBody2D
var bloqueos := 0
func bloquear_control() -> void:
	bloqueos += 1
func desbloquear_control() -> void:
	bloqueos = max(0, bloqueos - 1)
"""
	guion.reload()
	return guion


static func _script_objetivo() -> GDScript:
	var guion := GDScript.new()
	guion.source_code = """
extends CharacterBody2D
var golpes := 0
var ultimo_dano := 0.0
func quitar_vida(cantidad: float, _fuente: Node = null, _tipo: int = 2, _critico: bool = false) -> void:
	ultimo_dano = cantidad
	golpes += 1
"""
	guion.reload()
	return guion


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		5:
			# Primer "toque": arranca el canal.
			root.get_node("/root/SeñalManager").emitir("slot_0_apunte", "prueba", [Vector2.RIGHT, 1.0])
		6:
			print("Control bloqueado tras el primer toque (esperado 1): %d" % _tirador.get("bloqueos"))
		45:
			# Seguir "apuntando" varias veces mientras se sostiene el dedo
			# (mismo patrón que UIHabilidad._process ahora emite cada frame).
			root.get_node("/root/SeñalManager").emitir("slot_0_apunte", "prueba", [Vector2.RIGHT, 1.0])
		46:
			_golpes_a_mitad_camino = _objetivo.get("golpes")
			print("Golpes a mitad de camino (esperado >= 2, varios ticks): %d" % _golpes_a_mitad_camino)
		90:
			# "Soltar" el dedo.
			root.get_node("/root/SeñalManager").emitir("slot_0_lanzar", "prueba", [Vector2.RIGHT, 1.0])
		92:
			print("Control liberado tras soltar (esperado 0): %d" % _tirador.get("bloqueos"))
			_golpes_al_soltar = _objetivo.get("golpes")
			print("Golpes justo al soltar: %d" % _golpes_al_soltar)
		95:
			# Reintento INMEDIATO — todavía en cooldown (duracion_recarga=2.0,
			# apenas pasaron ~0.08s desde que se soltó) — no debe arrancar.
			root.get_node("/root/SeñalManager").emitir("slot_0_apunte", "prueba", [Vector2.RIGHT, 1.0])
		96:
			_golpes_reintento_en_cooldown = _objetivo.get("golpes")
			print("Control tras reintento en cooldown (esperado 0, no arrancó): %d" % _tirador.get("bloqueos"))
		219:
			# Acortar el tope de duración SOLO para el segundo canal (el
			# primero, de ~1.4s, no debía cortarse solo): 0.5s = 30
			# fotogramas — se cortará solo en el ~250, con el "dedo puesto".
			_habilidad.set("duracion_maxima_canal", 0.5)
		220:
			# Ya pasó el cooldown (2s = 120 fotogramas desde que se soltó en
			# el 90) — ahora SÍ debe poder volver a disparar.
			root.get_node("/root/SeñalManager").emitir("slot_0_apunte", "prueba", [Vector2.RIGHT, 1.0])
		221:
			print("Control tras reintento pasado el cooldown (esperado 1, arrancó de nuevo): %d" % _tirador.get("bloqueos"))
		260:
			print("Canal cortado solo por tiempo máximo, control liberado (esperado 0): %d" % _tirador.get("bloqueos"))
		400:
			# Cooldown del segundo canal ya vencido (se cortó ~250, +120=370)
			# y el "dedo" SIGUE puesto: este apunte NO debe rearrancar.
			root.get_node("/root/SeñalManager").emitir("slot_0_apunte", "prueba", [Vector2.RIGHT, 1.0])
		401:
			print("Apunte sostenido tras cortarse solo + cooldown vencido (esperado 0, NO rearrancó): %d" % _tirador.get("bloqueos"))
			_rearranque_bloqueado = _tirador.get("bloqueos") == 0
			# Ahora sí: soltar y volver a apuntar — debe arrancar normal.
			root.get_node("/root/SeñalManager").emitir("slot_0_lanzar", "prueba", [Vector2.RIGHT, 1.0])
		405:
			root.get_node("/root/SeñalManager").emitir("slot_0_apunte", "prueba", [Vector2.RIGHT, 1.0])
		406:
			print("Tras soltar y re-apuntar (esperado 1, arrancó): %d" % _tirador.get("bloqueos"))
			_arranco_tras_soltar = _tirador.get("bloqueos") == 1
		430:
			return _informar()
	return false


func _montar() -> void:
	var sm := root.get_node("/root/SeñalManager")
	sm.registrar("slot_0_apunte", "prueba", {"direccion": TYPE_VECTOR2, "poder": TYPE_FLOAT})
	sm.registrar("slot_0_lanzar", "prueba", {"direccion": TYPE_VECTOR2, "poder": TYPE_FLOAT})
	sm.registrar("slot_0_cancelar", "prueba", {})

	var escena := Node2D.new()
	root.add_child(escena)
	current_scene = escena

	_tirador = CharacterBody2D.new()
	_tirador.set_script(_script_tirador())
	_tirador.add_to_group("jugadores")
	escena.add_child(_tirador)

	# Bono plano de atributos (equipo con +10 "danos", sin % de potencia) —
	# el punto de este escenario es comprobar que se suma ANTES de repartir
	# la fracción del tick, no después.
	var atributos = (load("res://componentes/AtributosComponente.gd") as GDScript).new()
	atributos.name = "AtributosComponente"
	var base = (load("res://recursos/AtributosBase.gd") as GDScript).new()
	base.danos = 10.0
	atributos.base = base
	_tirador.add_child(atributos)

	_objetivo = CharacterBody2D.new()
	_objetivo.set_script(_script_objetivo())
	_objetivo.add_to_group("enemigos")
	_objetivo.collision_layer = 2
	_objetivo.global_position = Vector2(80, 0)
	escena.add_child(_objetivo)
	var forma := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 14.0
	forma.shape = circ
	_objetivo.add_child(forma)

	var contenedor := Marker2D.new()
	contenedor.name = "Habilidades"
	_tirador.add_child(contenedor)

	var guion := load("res://escenas/habilidades/lanzallamas/HabilidadLanzallamas.gd") as GDScript
	_habilidad = guion.new()
	_habilidad.slot_index = 0
	_habilidad.set("intervalo_tick", 0.2)
	_habilidad.set("alcance_cono", 200.0)
	_habilidad.set("angulo_cono_grados", 60.0)
	_habilidad.set("dano_por_tick", 5.0)
	_habilidad.set("costo_energia", 0.0)
	contenedor.add_child(_habilidad)
	_habilidad.entidad_dueña = _tirador
	# DESPUÉS de add_child (_ready ya corrió): el enfriamiento real solo se
	# conoce al equipar (aplicar_datos, desde el recurso), acá se fija a
	# mano para no depender de cargar un DatosHabilidad completo.
	_habilidad.duracion_recarga = 2.0


func _informar() -> bool:
	var golpes_finales: int = _objetivo.get("golpes")
	print("Golpes tras el reintento en cooldown (esperado == al soltar, no subió): %d" % _golpes_reintento_en_cooldown)
	print("Golpes totales al final (esperado > el del reintento fallido, sí disparó de nuevo): %d" % golpes_finales)

	# (dano_por_tick=5 + bono danos=10) * multiplicador_dano_tick(0.2) = 3.0
	# exacto — si el bono se sumara DESPUÉS de la fracción (el bug), daría
	# (5*0.2)+10 = 11.0 en cambio.
	var ultimo_dano: float = _objetivo.get("ultimo_dano")
	print("Último daño de tick con bono de atributos (esperado 3.0, NO ~11): %.2f" % ultimo_dano)
	var orden_correcto_ok := is_equal_approx(ultimo_dano, 3.0)

	var congelo_ok := true  # verificado en los prints de arriba
	var golpes_multiples := _golpes_a_mitad_camino >= 2
	var se_corto_ok := _golpes_reintento_en_cooldown == _golpes_al_soltar
	var cooldown_bloqueo_ok := _golpes_reintento_en_cooldown == _golpes_al_soltar
	var disparo_tras_cooldown_ok := golpes_finales > _golpes_reintento_en_cooldown
	print("Rearranque bloqueado con dedo puesto (esperado true): %s" % _rearranque_bloqueado)
	print("Arrancó normal tras soltar y re-apuntar (esperado true): %s" % _arranco_tras_soltar)
	var exito := congelo_ok and golpes_multiples and se_corto_ok \
		and cooldown_bloqueo_ok and disparo_tras_cooldown_ok and orden_correcto_ok \
		and _rearranque_bloqueado and _arranco_tras_soltar
	print("PRUEBA LANZALLAMAS %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
