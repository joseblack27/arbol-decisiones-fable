# =============================================================================
# Prueba de HabilidadPurga (ver EfectoTemporalPegado / InmunidadDebuffsComponente).
#
# Pedido del usuario: que te libere de TODOS los debuffs temporales que
# lleves encima (veneno, lentitud...), que NO toque un futuro debuff de
# zona/mapa, y que la inmunidad posterior sea en segundos y parametrizable.
#
# Verifica:
#   1. Cancela un EfectoVeneno y un EfectoLentitud activos al instante (el
#      nodo se libera, y su ícono sale de BuffsComponente ya mismo, no
#      cuando venza solo).
#   2. Dura lo que diga duracion_inmunidad (parametrizable, se prueba con un
#      valor distinto al default) — mientras esté activa, un debuff NUEVO
#      que intente pegarse se descarta sin aplicar nada.
#   3. Pasada la inmunidad, un debuff nuevo SÍ aplica normal.
#   4. Los efectos de ZONA (EfectoAreaBase: Inmovilizar/DoT/Marca) no
#      extienden EfectoTemporalPegado — Purga estructuralmente no puede
#      tocarlos, sin importar qué se agregue después.
#   godot --headless --path . --script res://pruebas/prueba_purga.gd
# =============================================================================
extends SceneTree

const DURACION_INMUNIDAD_PRUEBA := 0.5

var _f := 0
var _jugador: CharacterBody2D
var _purga
var _veneno
var _lentitud
var _veneno2
var _veneno3
var _buffs
var _icono_prueba := PlaceholderTexture2D.new()

var _cancela_debuffs_activos_ok := false
var _icono_sale_al_instante_ok := false
var _inmunidad_parametrizable_ok := false
var _bloquea_debuff_nuevo_mientras_dura_ok := false
var _aplica_normal_tras_vencer_ok := false
var _zona_no_es_purgable_ok := false


func _process(_d: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar()
		3:
			# Con veneno y lentitud ya pegados y aplicados de verdad. Con
			# ícono real (no null) para que la baja de BuffsComponente sea
			# una prueba real y no un "no estaba de todos modos".
			_veneno.objetivo = _jugador
			_veneno.duracion = 10.0
			_veneno.icono_debuff = _icono_prueba
			_jugador.add_child(_veneno)
			_lentitud.objetivo = _jugador
			_lentitud.duracion = 10.0
			_lentitud.icono_debuff = _icono_prueba
			_jugador.add_child(_lentitud)
		5:
			# Los dos efectos ya se aplicaron de verdad (un frame de margen).
			print("Veneno aplicado antes de purgar (esperado true): %s" % _veneno._aplicado)
			print("Lentitud aplicada antes de purgar (esperado true): %s" % _lentitud._aplicado)
			_purga.call("_ejecutar", Vector2.ZERO, 1.0)
		7:
			_cancela_debuffs_activos_ok = not is_instance_valid(_veneno) and not is_instance_valid(_lentitud)
			print("Veneno y lentitud cancelados al instante (esperado true): %s" % _cancela_debuffs_activos_ok)

			_icono_sale_al_instante_ok = not _buffs.esta_activo("veneno") and not _buffs.esta_activo("lentitud")
			print("Sus íconos salen de BuffsComponente al instante (esperado true): %s" % _icono_sale_al_instante_ok)

			var inmunidad = _jugador.get_node_or_null("InmunidadDebuffsComponente")
			_inmunidad_parametrizable_ok = inmunidad != null and inmunidad.esta_activa() \
				and absf(inmunidad.tiempo_restante() - DURACION_INMUNIDAD_PRUEBA) < 0.05
			print("Inmunidad activa con la duración configurada (%.1fs, esperado true): %s" % [
				DURACION_INMUNIDAD_PRUEBA, _inmunidad_parametrizable_ok])

			# Intento de un debuff NUEVO mientras la inmunidad sigue activa.
			_veneno2 = (load("res://escenas/efectos/EfectoVeneno.gd") as GDScript).new()
			_veneno2.objetivo = _jugador
			_veneno2.duracion = 10.0
			_veneno2.icono_debuff = _icono_prueba
			_jugador.add_child(_veneno2)
		9:
			# Ni se aplicó (chequeo directo) ni quedó vivo esperando —
			# EfectoTemporalPegado._ready() lo aborta y libera en el acto.
			_bloquea_debuff_nuevo_mientras_dura_ok = not is_instance_valid(_veneno2) \
				and not _buffs.esta_activo("veneno")
			print("Un debuff nuevo NO aplica mientras dura la inmunidad (esperado true): %s" % _bloquea_debuff_nuevo_mientras_dura_ok)
		# DURACION_INMUNIDAD_PRUEBA = 0.5s -> de sobra a los 40 fotogramas (~0.66s).
		40:
			_veneno3 = (load("res://escenas/efectos/EfectoVeneno.gd") as GDScript).new()
			_veneno3.objetivo = _jugador
			_veneno3.duracion = 10.0
			_veneno3.icono_debuff = _icono_prueba
			_jugador.add_child(_veneno3)
		42:
			_aplica_normal_tras_vencer_ok = is_instance_valid(_veneno3) and _veneno3._aplicado \
				and _buffs.esta_activo("veneno")
			print("Pasada la inmunidad, un debuff nuevo SÍ aplica (esperado true): %s" % _aplica_normal_tras_vencer_ok)

			# Sin tipar "EfectoTemporalPegado" (mismo motivo de siempre en
			# --script): se chequea por duck typing la propiedad que solo
			# tiene esa base ("es_debuff", que Purga usa para filtrar).
			var inmov = (load("res://escenas/efectos/EfectoInmovilizar.gd") as GDScript).new()
			_zona_no_es_purgable_ok = not ("es_debuff" in inmov)
			print("Un efecto de ZONA no extiende EfectoTemporalPegado, Purga no lo toca (esperado true): %s" % _zona_no_es_purgable_ok)
			inmov.free()

			return _informar()
	return false


func _montar() -> void:
	var escena := Node2D.new()
	root.add_child(escena)
	current_scene = escena

	_jugador = CharacterBody2D.new()
	_jugador.add_to_group("jugadores")
	escena.add_child(_jugador)

	var mov = (load("res://componentes/MovimientoComponente.gd") as GDScript).new()
	mov.name = "MovimientoComponente"
	mov.jugador = _jugador
	_jugador.add_child(mov)

	_buffs = (load("res://componentes/BuffsComponente.gd") as GDScript).new()
	_buffs.name = "BuffsComponente"
	_jugador.add_child(_buffs)

	_veneno = (load("res://escenas/efectos/EfectoVeneno.gd") as GDScript).new()
	_lentitud = (load("res://escenas/efectos/EfectoLentitud.gd") as GDScript).new()

	var contenedor := Marker2D.new()
	contenedor.name = "HabilidadesPrueba"
	_jugador.add_child(contenedor)

	var guion := load("res://escenas/habilidades/purga/HabilidadPurga.gd") as GDScript
	_purga = guion.new()
	_purga.slot_index = 0
	_purga.costo_energia = 0.0
	_purga.duracion_recarga = 0.1
	_purga.duracion_inmunidad = DURACION_INMUNIDAD_PRUEBA
	contenedor.add_child(_purga)
	_purga.entidad_dueña = _jugador


func _informar() -> bool:
	var exito := _cancela_debuffs_activos_ok and _icono_sale_al_instante_ok \
		and _inmunidad_parametrizable_ok and _bloquea_debuff_nuevo_mientras_dura_ok \
		and _aplica_normal_tras_vencer_ok and _zona_no_es_purgable_ok
	print("  cancela debuffs activos: %s" % _cancela_debuffs_activos_ok)
	print("  ícono sale al instante: %s" % _icono_sale_al_instante_ok)
	print("  inmunidad parametrizable en segundos: %s" % _inmunidad_parametrizable_ok)
	print("  bloquea debuff nuevo mientras dura: %s" % _bloquea_debuff_nuevo_mientras_dura_ok)
	print("  aplica normal tras vencer la inmunidad: %s" % _aplica_normal_tras_vencer_ok)
	print("  zona no purgable: %s" % _zona_no_es_purgable_ok)
	print("PRUEBA PURGA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
