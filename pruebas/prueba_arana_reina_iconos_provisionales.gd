# =============================================================================
# Prueba: las habilidades de la Araña Reina que disparan un proyectil ARMADO
# A MANO (Marca Jefe, Charco Jefe — sin DatosHabilidad, nunca pasan por
# HabilidadProyectil.aplicar_datos) usan el ÍCONO PROVISIONAL configurado
# directo en su propio .tscn, en vez de caer en los círculos de debug de
# Proyectil._draw() — reportado por el usuario ("cuál de las habilidades de
# la reina araña no tiene sprite y es un proyectil", y después: "ya no
# quiero que uses el debug de proyectil").
#
# Causa: usar_icono_como_sprite=false + ninguna de las dos tenía un ícono
# propio (el campo que alimentaba el sprite provisional, antes "_icono",
# SOLO se llenaba desde aplicar_datos(DatosHabilidad) — y estas dos, sin
# DatosHabilidad, se quedaban en null para siempre) forzaba mostrar_debug=
# true en cada disparo pese a que el .tscn traía mostrar_debug=false.
#
#   godot --headless --path . --script res://pruebas/prueba_arana_reina_iconos_provisionales.gd
# =============================================================================
extends SceneTree

var _dueño: CharacterBody2D
var _f := 0

var _marca_usa_icono_ok := false
var _charco_usa_icono_ok := false


func _process(_delta: float) -> bool:
	_f += 1
	match _f:
		1:
			_montar()
		2:
			_disparar("res://escenas/habilidades/marca_jefe/HabilidadMarcaJefe.tscn")
		3:
			_marca_usa_icono_ok = _verificar_ultimo_proyectil()
			print("Marca Jefe usa el ícono provisional, no el debug (esperado true): %s" % \
				_marca_usa_icono_ok)
			_disparar("res://escenas/habilidades/charco_jefe/HabilidadCharcoJefe.tscn")
		4:
			_charco_usa_icono_ok = _verificar_ultimo_proyectil()
			print("Charco Jefe usa el ícono provisional, no el debug (esperado true): %s" % \
				_charco_usa_icono_ok)
			return _informar()
	return false


func _montar() -> void:
	var escena := Node2D.new()
	root.add_child(escena)
	current_scene = escena

	# Cargar la escena COMPLETA de Jugador.tscn primero fuerza a que los
	# autoloads que usa Proyectil.gd (GestorPiscinas) ya estén resueltos —
	# sin esto, tocar una habilidad de proyectil en un --script nuevo
	# cuelga en silencio (mismo criterio ya usado en prueba_gancho.gd).
	var jugador := (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	escena.add_child(jugador)
	jugador.queue_free()

	_dueño = CharacterBody2D.new()
	_dueño.add_to_group("enemigos")
	escena.add_child(_dueño)
	_dueño.global_position = Vector2.ZERO


func _disparar(ruta_habilidad: String) -> void:
	var hab := (load(ruta_habilidad) as PackedScene).instantiate() as HabilidadProyectil
	_dueño.add_child(hab)
	hab.entidad_dueña = _dueño
	hab.activar(Vector2.RIGHT, 1.0)


## El proyectil recién disparado vive en el contenedor de GestorPiscinas
## (ver GestorPiscinas.obtener), no en current_scene.
func _verificar_ultimo_proyectil() -> bool:
	var gestor := root.get_node("/root/GestorPiscinas")
	for hijo in gestor._contenedor.get_children():
		if hijo is Proyectil:
			var sprite := hijo.get_node_or_null("SpriteIcono") as Sprite2D
			return not hijo.mostrar_debug and sprite != null and sprite.visible \
				and sprite.texture != null
	return false


func _informar() -> bool:
	var exito := _marca_usa_icono_ok and _charco_usa_icono_ok
	print("PRUEBA ARAÑA REINA ICONOS PROVISIONALES %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
