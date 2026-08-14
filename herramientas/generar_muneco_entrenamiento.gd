# =============================================================================
# generar_muneco_entrenamiento.gd — construye
# escenas/enemigos/MunecoEntrenamiento.tscn: un CharacterBody2D que extiende
# Enemigo (mismo VidaComponente/MovimientoComponente que cualquier mob, así
# que empuje/atracción —Onda de Choque, Vórtice— funcionan gratis) pero sin
# árbol de comportamiento (nunca ataca ni persigue) y con
# MunecoEntrenamiento._on_muerte() reemplazando el flujo normal de muerte
# de Enemigo (sin botín/XP/despawn — se cura al máximo en vez de morir).
#
# Sprite: "Training Dummy Sprite Sheet.png" (256x96, grilla 8x3 de 32x32
# confirmada por inspección — NO asumida). Los primeros 4 frames (fila
# superior, columnas 0-3) son la animación de reposo pedida.
#
#   godot --headless --path . --script res://herramientas/generar_muneco_entrenamiento.gd
# =============================================================================
extends SceneTree

const RUTA_SALIDA := "res://escenas/enemigos/MunecoEntrenamiento.tscn"
const RUTA_SCRIPT := "res://escenas/enemigos/MunecoEntrenamiento.gd"
const RUTA_DATOS := "res://recursos/enemigos/MunecoEntrenamiento.tres"
const RUTA_SPRITESHEET := "res://assets/sprites/Training Dummy Sprite Sheet.png"

const RADIO_COLISION := 12.0


func _process(_d: float) -> bool:
	var raiz := CharacterBody2D.new()
	raiz.name = "MunecoEntrenamiento"
	raiz.set_script(load(RUTA_SCRIPT))
	raiz.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	var forma_cuerpo := CircleShape2D.new()
	forma_cuerpo.radius = RADIO_COLISION
	var colision := CollisionShape2D.new()
	colision.name = "CollisionShape2D"
	colision.shape = forma_cuerpo
	raiz.add_child(colision)
	colision.owner = raiz

	# Requerido por Enemigo.gd (@onready var habilidades: Marker2D =
	# $Habilidades) — vacío, el muñeco no tiene ninguna habilidad propia.
	var habilidades := Marker2D.new()
	habilidades.name = "Habilidades"
	raiz.add_child(habilidades)
	habilidades.owner = raiz

	# Requerido por Enemigo._ready() (memoria.establecer(...) sin chequeo de
	# null) — sin ArbolComportamiento arriba, mismo patrón que
	# AliadoInvocado.tscn (memoria "suelta", sin BT real debajo).
	var memoria := Node.new()
	memoria.name = "MemoriaBT"
	memoria.set_script(load("res://componentes/arbol_comportamiento/MemoriaBT.gd"))
	raiz.add_child(memoria)
	memoria.owner = raiz

	var movimiento := Node.new()
	movimiento.name = "MovimientoComponente"
	movimiento.set_script(load("res://componentes/MovimientoComponente.gd"))
	raiz.add_child(movimiento)
	movimiento.owner = raiz
	# Referencia de NODO real, no un NodePath literal: PackedScene.pack()
	# solo serializa esto como node_paths resolvible si le pasás el objeto
	# (mismo mecanismo que componente_vida/memoria más abajo). Un NodePath
	# literal se guarda como valor suelto y jamás se resuelve a nodo al
	# instanciar — quedaba "jugador" en null y el empuje reventaba
	# (confirmado con la prueba: "Invalid ... on a base object of type 'Nil'"
	# en MovimientoComponente._physics_process).
	movimiento.set("jugador", raiz)

	var vida := Area2D.new()
	vida.name = "VidaComponente"
	vida.set_script(load("res://componentes/VidaComponente.gd"))
	vida.set("salud_maxima", 300.0)
	raiz.add_child(vida)
	vida.owner = raiz
	var forma_vida := CircleShape2D.new()
	forma_vida.radius = RADIO_COLISION
	var colision_vida := CollisionShape2D.new()
	colision_vida.name = "CollisionShape2D"
	colision_vida.shape = forma_vida
	vida.add_child(colision_vida)
	colision_vida.owner = raiz

	# Requerido por Enemigo.gd (@onready var sprite: Sprite2D = $Sprite2D).
	# hframes/vframes confirmados por inspección directa del PNG (256x96 =
	# grilla exacta 8x3 de 32x32) — frame 0..3 son la fila superior.
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load(RUTA_SPRITESHEET)
	sprite.hframes = 8
	sprite.vframes = 3
	sprite.frame = 0
	raiz.add_child(sprite)
	sprite.owner = raiz

	# Sin animación de reposo: queda quieto en el frame 0 (pedido del
	# usuario). Única animación real: "golpe", frames 9-12 (el muñeco se
	# tambalea hacia atrás y se endereza — confirmado por inspección visual
	# de la hoja de contacto, NO asumido), disparada a mano desde
	# MunecoEntrenamiento._on_daño_aplicado() en cada golpe confirmado.
	# Termina en el frame 0 (última clave) para volver solo al reposo, sin
	# necesitar animation_finished ni resetear nada a mano.
	var anim_golpe := Animation.new()
	anim_golpe.length = 0.32
	anim_golpe.loop_mode = Animation.LOOP_NONE
	var pista := anim_golpe.add_track(Animation.TYPE_VALUE)
	anim_golpe.track_set_path(pista, NodePath("Sprite2D:frame"))
	anim_golpe.value_track_set_update_mode(pista, Animation.UPDATE_DISCRETE)
	anim_golpe.track_insert_key(pista, 0.0, 9)
	anim_golpe.track_insert_key(pista, 0.08, 10)
	anim_golpe.track_insert_key(pista, 0.16, 11)
	anim_golpe.track_insert_key(pista, 0.24, 12)
	anim_golpe.track_insert_key(pista, 0.32, 0)
	var libreria := AnimationLibrary.new()
	libreria.add_animation("golpe", anim_golpe)
	var reproductor := AnimationPlayer.new()
	reproductor.name = "AnimationPlayer"
	raiz.add_child(reproductor)
	reproductor.owner = raiz
	reproductor.add_animation_library("", libreria)

	var barra := Node2D.new()
	barra.name = "BarraVidaEnergia"
	barra.set_script(load("res://componentes/BarraVidaEnergiaComponente.gd"))
	barra.set("ancho", 28.0)
	barra.position = Vector2(0, -24)
	raiz.add_child(barra)
	barra.owner = raiz

	raiz.set("componente_vida", vida)
	raiz.set("componente_movimiento", movimiento)
	raiz.set("memoria", memoria)
	raiz.set("datos", load(RUTA_DATOS))
	raiz.set("xp_otorgada", 0)

	var escena := PackedScene.new()
	if escena.pack(raiz) != OK:
		push_error("No se pudo empaquetar la escena.")
		quit(1)
		return true
	if ResourceSaver.save(escena, RUTA_SALIDA) != OK:
		push_error("No se pudo guardar %s" % RUTA_SALIDA)
		quit(1)
		return true

	print("Guardado %s" % RUTA_SALIDA)
	quit(0)
	return true
