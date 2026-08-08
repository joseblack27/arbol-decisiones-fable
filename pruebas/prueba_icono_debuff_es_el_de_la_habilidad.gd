# =============================================================================
# Prueba: el ícono de buff/debuff que queda anotado en BuffsComponente al
# impactar es el mismo que el de la HABILIDAD (DatosHabilidad.icono, el que
# se ve en el botón), no uno aparte hardcodeado en la escena del efecto.
#
# Pedido del usuario: "quiero que el icono que salga como debuff o buff sea
# el que se usa como habilidad no el del proyectil" — antes EfectoVenenoFlecha
# traía su propio ícono fijo (icono_veneno_32x32.png), sin relación con lo
# que en verdad se ve en el botón de Veneno (veneno.tres, un recorte de
# "iconos habilidades.png") — si algún día cambia uno sin acordarse del
# otro, quedaban desincronizados.
#
# Se prueba con Veneno como caso real end-to-end: HabilidadVeneno con
# aplicar_datos(veneno.tres) de por medio (así el ícono real de la habilidad
# entra en juego, no un valor puesto a mano) disparando un proyectil real que
# impacta y deja el efecto pegado.
#   godot --headless --path . --script res://pruebas/prueba_icono_debuff_es_el_de_la_habilidad.gd
# =============================================================================
extends SceneTree

var _f := 0
var _atacante: Node2D
var _mob
var _habilidad
var _datos_veneno: DatosHabilidad


func _process(_d: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar()
		2:
			_habilidad.call("_ejecutar", Vector2.RIGHT, 1.0)
		# A 450px/s, 60px de distancia tardan ~8 fotogramas en impactar —
		# 20 fotogramas de margen de sobra (mismo criterio que prueba_veneno.gd).
		20:
			return _informar()
	return false


func _montar() -> void:
	_atacante = Node2D.new()
	_atacante.add_to_group("jugadores")
	root.add_child(_atacante)
	current_scene = _atacante
	_atacante.global_position = Vector2.ZERO

	_mob = (load("res://escenas/enemigos/EnemigoRaton.tscn") as PackedScene).instantiate()
	root.add_child(_mob)
	_mob.global_position = Vector2(60, 0)

	var contenedor := Marker2D.new()
	contenedor.name = "HabilidadesPrueba"
	_atacante.add_child(contenedor)

	var guion := load("res://escenas/habilidades/proyectil/HabilidadProyectil.gd") as GDScript
	_habilidad = guion.new()
	_habilidad.slot_index = 0
	_habilidad.escena_proyectil = load("res://escenas/habilidades/veneno/ProyectilVeneno.tscn")
	contenedor.add_child(_habilidad)
	_habilidad.entidad_dueña = _atacante

	# aplicar_datos() de verdad, con el .tres real de Veneno — así el ícono
	# que entra en juego es el mismo que vería el jugador en su botón, no un
	# valor puesto a mano para la prueba.
	_datos_veneno = load("res://recursos/habilidades/veneno.tres") as DatosHabilidad
	_habilidad.aplicar_datos(_datos_veneno)


func _informar() -> bool:
	var buffs = _mob.get_node_or_null("BuffsComponente")
	var buff = buffs.obtener("veneno_flecha") if buffs else null
	var icono_coincide: bool = buff != null and buff.icono == _datos_veneno.icono
	print("El ícono del debuff (%s) coincide con el de la habilidad (%s) (esperado true): %s" % [
		buff.icono if buff else null, _datos_veneno.icono, icono_coincide])
	print("PRUEBA ICONO DEBUFF ES EL DE LA HABILIDAD %s" % ("OK" if icono_coincide else "FALLIDA"))
	quit(0 if icono_coincide else 1)
	return true
