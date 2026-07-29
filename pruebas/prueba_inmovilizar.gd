# =============================================================================
# Prueba de la habilidad de inmovilizar (HabilidadProyectil con
# escena_al_impactar = EfectoInmovilizarEnemigos): el proyectil no hace
# daño (daño_proyectil=0 en la escena), pero al chocar con un enemigo lo
# deja sin poder moverse durante unos segundos, y se libera solo después.
#
# También verifica el pedido del usuario: "si te inmoviliza un enemigo no
# aparece ningún ícono" — EfectoInmovilizar ahora anota un buff en
# BuffsComponente mientras dura, y lo saca al vencer.
#   godot --headless --path . --script res://pruebas/prueba_inmovilizar.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _tirador: Node2D
var _objetivo: CharacterBody2D
var _movimiento: Node
var _vida_objetivo: VidaComponente
var _habilidad: Node
var _inmovilizado_ok := false
var _icono_buff_aparece := false
var _icono_buff_desaparece := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		5:
			_habilidad.activar(Vector2.RIGHT, 1.0)
		30:
			# El proyectil (350 px/s) ya debería haber recorrido los 60px
			# hasta el objetivo e impactado — margen extra por los
			# add_child/set_deferred de _spawnear_efecto_impacto (el Area2D
			# del efecto necesita al menos un physics_frame más para que el
			# motor detecte el solapamiento y dispare body_entered).
			print("Vida del objetivo tras el impacto (esperado 100, sin daño): %.0f" % _vida_objetivo.obtener_vida())
			_inmovilizado_ok = _movimiento.get("_contador_inmovilizacion") > 0
			print("Inmovilizado tras el impacto (esperado true): %s" % _inmovilizado_ok)
			var buffs := _objetivo.get_node_or_null("BuffsComponente")
			_icono_buff_aparece = buffs != null and buffs.esta_activo("inmovilizado")
			print("Aparece el ícono de inmovilizado (esperado true): %s" % _icono_buff_aparece)
		# EfectoInmovilizarEnemigos dura 2.5s = 150 fotogramas; dar margen
		# desde el impacto (~fotograma 30) hasta que se libere solo.
		220:
			return _informar()
	return false


func _montar() -> void:
	var escena := Node2D.new()
	root.add_child(escena)
	current_scene = escena

	_tirador = Node2D.new()
	_tirador.add_to_group("jugadores")
	escena.add_child(_tirador)
	var contenedor := Marker2D.new()
	contenedor.name = "Habilidades"
	_tirador.add_child(contenedor)

	var guion := load("res://escenas/habilidades/proyectil/HabilidadProyectil.gd") as GDScript
	_habilidad = guion.new()
	_habilidad.set("escena_proyectil", load("res://escenas/habilidades/proyectil/custom/ProyectilInmovilizador.tscn"))
	_habilidad.set("daño_proyectil", 0.0)
	_habilidad.set("alcance_maximo", 400.0)
	_habilidad.set("duracion_recarga", 0.0)
	contenedor.add_child(_habilidad)
	_habilidad.entidad_dueña = _tirador

	_objetivo = CharacterBody2D.new()
	_objetivo.add_to_group("enemigos")
	# Capa 2, igual que Enemigo.gd real: la red (EfectoInmovilizarEnemigos)
	# detecta cuerpos por máscara 2|8 (mobs + jugadores) — un cuerpo en la
	# capa 1 por defecto ya no la dispara.
	_objetivo.collision_layer = 2
	_objetivo.global_position = Vector2(60, 0)
	# Proyectil._on_body_entrada() exige que el objetivo tenga quitar_vida()
	# antes de considerarlo un impacto real (mismo criterio que Enemigo.gd,
	# que reenvía a su propio VidaComponente) — sin esto, el proyectil pasa
	# de largo sin detenerse ni spawnear el efecto.
	var guion_objetivo := GDScript.new()
	guion_objetivo.source_code = """
extends CharacterBody2D
func quitar_vida(cantidad: float, fuente: Node = null, _tipo: int = 2, _critico: bool = false) -> void:
	var vida := get_node_or_null("VidaComponente")
	if vida:
		vida.quitar_vida(cantidad, fuente)
"""
	guion_objetivo.reload()
	_objetivo.set_script(guion_objetivo)
	escena.add_child(_objetivo)
	var forma_objetivo := CollisionShape2D.new()
	var circ_objetivo := CircleShape2D.new()
	circ_objetivo.radius = 12.0
	forma_objetivo.shape = circ_objetivo
	_objetivo.add_child(forma_objetivo)

	_vida_objetivo = VidaComponente.new()
	_vida_objetivo.name = "VidaComponente"
	_vida_objetivo.salud_maxima = 100.0
	_objetivo.add_child(_vida_objetivo)
	_vida_objetivo.restaurar_vida(100.0)

	_movimiento = (load("res://componentes/MovimientoComponente.gd") as GDScript).new()
	_movimiento.name = "MovimientoComponente"
	_movimiento.jugador = _objetivo
	_objetivo.add_child(_movimiento)


func _informar() -> bool:
	var libre_de_nuevo: bool = _movimiento.get("_contador_inmovilizacion") <= 0
	print("Libre de nuevo tras vencerse el efecto (esperado true): %s" % libre_de_nuevo)
	var buffs := _objetivo.get_node_or_null("BuffsComponente")
	_icono_buff_desaparece = buffs == null or not buffs.esta_activo("inmovilizado")
	print("Desaparece el ícono al vencer el efecto (esperado true): %s" % _icono_buff_desaparece)
	var exito := is_equal_approx(_vida_objetivo.obtener_vida(), 100.0) and libre_de_nuevo and _inmovilizado_ok \
		and _icono_buff_aparece and _icono_buff_desaparece
	print("PRUEBA INMOVILIZAR %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
