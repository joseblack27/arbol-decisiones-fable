# =============================================================================
# Prueba de HabilidadVeneno/EfectoVeneno (sin red): dispara una flecha que
# hace daño instantáneo Y envenena al enemigo — a diferencia de EfectoDoT
# (una nube fija en el punto de impacto, deja de dañar si el objetivo
# camina fuera de ella), el veneno queda PEGADO al enemigo (mismo
# criterio que EfectoLentitud) y lo sigue a donde vaya.
#
# Verifica:
#   1. El impacto hace daño instantáneo real.
#   2. El veneno queda pegado al enemigo (EfectoVeneno como hijo) y
#      anotado en BuffsComponente.
#   3. Sigue tickeando aunque el enemigo se TELEPORTE lejos del punto de
#      impacto — la diferencia clave con una nube de veneno en el suelo.
#   4. Un segundo veneno del mismo tipo RENUEVA en vez de apilarse (un
#      solo EfectoVeneno hijo, no dos).
#   5. Pasada la duración, se limpia solo (deja de tickear, sale de
#      BuffsComponente).
#   godot --headless --path . --script res://pruebas/prueba_veneno.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _atacante: Node2D
var _mob
var _vida
var _vida_tras_impacto: float = 0.0

var _hizo_dano_instantaneo := false
var _veneno_pegado_y_con_icono := false
var _sigue_tickeando_lejos_del_impacto := false
var _segundo_impacto_no_apila := false
var _se_limpia_solo_al_vencer := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		5:
			_disparar()
		20:
			# Alcanza de sobra (a 450px/s, 60px tardan ~8 fotogramas) para
			# que el impacto ya haya pasado.
			_hizo_dano_instantaneo = _vida.salud_actual < _vida.salud_maxima
			_vida_tras_impacto = _vida.salud_actual
			print("Daño instantáneo al impactar (esperado true, vida %.1f/%.1f): %s" % [
				_vida.salud_actual, _vida.salud_maxima, _hizo_dano_instantaneo])
			var buffs = _mob.get_node_or_null("BuffsComponente")
			_veneno_pegado_y_con_icono = _contar_venenos() == 1 \
				and buffs != null and buffs.esta_activo("veneno_flecha")
			print("Veneno pegado (1 hijo) y anotado en BuffsComponente (esperado true): %s" % _veneno_pegado_y_con_icono)
			# Teletransportar LEJOS del punto de impacto — si el veneno fuera
			# una nube fija (EfectoDoT), esto lo dejaría de tickear.
			_mob.global_position = Vector2(9000, 9000)
		100:
			# intervalo_tick=1s (60 fotogramas) desde que se pegó (~frame
			# 13) — a esta altura ya tickeó al menos una vez, lejísimos del
			# punto de impacto original.
			_sigue_tickeando_lejos_del_impacto = _vida.salud_actual < _vida_tras_impacto - 4.0
			print("Sigue tickeando lejos del punto de impacto (esperado true, vida %.1f -> %.1f): %s" % [
				_vida_tras_impacto, _vida.salud_actual, _sigue_tickeando_lejos_del_impacto])
			_aplicar_segundo_veneno_directo()
		101:
			_segundo_impacto_no_apila = _contar_venenos() == 1
			print("Segundo veneno renueva sin apilar (esperado true, hijos=%d): %s" % [
				_contar_venenos(), _segundo_impacto_no_apila])
		# duracion=5s (300 fotogramas) desde la renovación del frame 100 —
		# con margen de sobra.
		420:
			var buffs = _mob.get_node_or_null("BuffsComponente")
			var fuera_de_buffs: bool = buffs == null or not buffs.esta_activo("veneno_flecha")
			_se_limpia_solo_al_vencer = _contar_venenos() == 0 and fuera_de_buffs
			print("Se limpia solo al vencer (esperado true, hijos=%d): %s" % [
				_contar_venenos(), _se_limpia_solo_al_vencer])
			return _informar()
	return false


## Sin "is EfectoVeneno": referenciar por tipo estático una clase recién
## creada en el propio script de entrada --script es justo lo que causó
## el cuelgue investigado en prueba_ticket_consumible_xp.gd — acá en vez
## de colgarse directamente da "Failed to compile depended scripts" y deja
## el nodo instanciado como un Node pelado en vez de EfectoVeneno de
## verdad. Duck typing (mismo criterio ya usado en otras pruebas de este
## proyecto) evita el problema de raíz.
func _contar_venenos() -> int:
	var n := 0
	for hijo in _mob.get_children():
		if "id_debuff" in hijo and hijo.get("id_debuff") == "veneno_flecha":
			n += 1
	return n


func _montar() -> void:
	_atacante = Node2D.new()
	_atacante.add_to_group("jugadores")
	root.add_child(_atacante)
	current_scene = _atacante
	_atacante.global_position = Vector2.ZERO

	_mob = (load("res://escenas/enemigos/EnemigoRaton.tscn") as PackedScene).instantiate()
	root.add_child(_mob)
	_mob.global_position = Vector2(60, 0)
	_vida = _mob.get_node("VidaComponente")


func _disparar() -> void:
	var proy = (load("res://escenas/habilidades/veneno/ProyectilVeneno.tscn") as PackedScene).instantiate()
	root.add_child(proy)
	proy.global_position = _atacante.global_position
	proy.alcance_base = 400.0
	proy.configurar(Vector2.RIGHT, 1.0, 9.0, _atacante, Enums.Habilidad.TipoDano.FISICO)


## El segundo "impacto" se aplica DIRECTO (sin volver a disparar un
## proyectil real): el mob ya está teletransportado lejos, así que un
## segundo disparo desde el atacante original nunca llegaría — lo que
## importa probar acá es solo la renovación, no el vuelo del proyectil de
## nuevo (ya cubierto arriba).
func _aplicar_segundo_veneno_directo() -> void:
	var efecto = (load("res://escenas/efectos/EfectoVenenoFlecha.tscn") as PackedScene).instantiate()
	efecto.fuente = _atacante
	efecto.objetivo = _mob
	_mob.add_child(efecto)


func _informar() -> bool:
	var exito := _hizo_dano_instantaneo and _veneno_pegado_y_con_icono \
		and _sigue_tickeando_lejos_del_impacto and _segundo_impacto_no_apila \
		and _se_limpia_solo_al_vencer
	print("PRUEBA VENENO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
