class_name HabilidadInvocacion
extends HabilidadBase
## Invoca un aliado temporal (ver AliadoInvocado.gd) que pelea contra los
## enemigos por "duracion_invocacion" segundos y se desvanece solo — self-
## buff sin dirección (botón tap, como Curación/Escudo).

@export var escena_aliado: PackedScene = preload("res://escenas/enemigos/AliadoInvocado.tscn")
@export var duracion_invocacion: float = 15.0
@export var dano_ataque: float = 10.0
@export var rango_ataque: float = 40.0
@export var intervalo_ataque: float = 1.0
@export var velocidad_persecucion: float = 140.0
## Ícono que muestra BuffsComponente mientras el aliado está activo. Null =
## no se anota en BuffsComponente (queda sin ícono en el HUD).
@export var icono_buff: Texture2D = null


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Invocación"
	tipo_habilidad   = "invocacion"
	requiere_direccion = false


func _ejecutar(_direccion: Vector2, _poder: float) -> void:
	if not is_instance_valid(entidad_dueña) or not (entidad_dueña is Node2D):
		return

	# El aliado es una IA persistente (~15s tomando sus propias decisiones de
	# a quién perseguir/golpear), no un efecto instantáneo como Proyectil/
	# OndaChoque — con el patrón normal de HabilidadBase (cada peer corre su
	# propia _ejecutar(), "predicción" + réplica visual) cada cliente creaba
	# su PROPIA copia independiente. Como AliadoInvocado apaga su IA fuera del
	# servidor (ver _physics_process), esas copias quedaban congeladas
	# adornando la pantalla de cada jugador mientras la única que de verdad
	# peleaba vivía invisible en el servidor — el reportado "no se ve el daño
	# de la invocación... quiero números flotantes" salía de ahí:
	# GestorNumerosDano solo pinta el número si fuente/objetivo es TU jugador
	# local, y esa copia real nunca estaba replicada para poder serlo.
	# Arreglo: solo el servidor (o un solo jugador sin red) crea al aliado de
	# verdad, dentro del contenedor "Enemigos" del nivel — el mismo que usa
	# SpawnerMobs, con un MultiplayerSpawner registrado en NivelBase (ver
	# NivelBase._configurar_spawner_invocaciones) que lo replica a todos los
	# clientes igual que a un mob. La posición/animación ya viaja gratis por
	# el RPC que Enemigo._physics_process ya tiene para todo mob.
	if not (Utils.en_red() and not multiplayer.is_server()):
		var aliado = escena_aliado.instantiate()
		aliado.dueño                  = entidad_dueña
		aliado.dano_ataque            = dano_ataque
		aliado.rango_ataque           = rango_ataque
		aliado.intervalo_ataque       = intervalo_ataque
		aliado.velocidad_persecucion  = velocidad_persecucion
		aliado.activar(duracion_invocacion)
		var nivel := GestorNiveles.nivel_actual()
		var contenedor: Node = (nivel.get_node_or_null("Enemigos") if nivel else null)
		if contenedor == null:
			contenedor = get_tree().current_scene
		# force_readable_name=true: sin esto, el MultiplayerSpawner rechaza el
		# nombre autogenerado ("Unable to auto-spawn node with reserved
		# name") y el aliado nunca replica al cliente — mismo motivo que
		# SpawnerMobs._generar_uno().
		contenedor.add_child.call_deferred(aliado, true)
		aliado.set_deferred("global_position", (entidad_dueña as Node2D).global_position + Vector2(30, 0))

	if icono_buff != null:
		var buffs := entidad_dueña.get_node_or_null("BuffsComponente") as BuffsComponente
		if buffs == null:
			buffs = BuffsComponente.new()
			buffs.name = "BuffsComponente"
			entidad_dueña.add_child(buffs)
		# El daño acá es dano_ataque TAL CUAL (no pasa por AtributosComponente:
		# el aliado no tiene uno propio, ver AliadoInvocado._atacar) — a
		# diferencia de Aura/Veneno, mostrar el valor crudo es exacto, no una
		# aproximación. Pedido del usuario: "que al menos el invocador
		# pudiera ver el daño de la invocación" — la descripción de
		# invocacion.tres (pantalla de equipar) ya lo mostraba, pero esta
		# OTRA descripción (la del buff activo, la que ve el invocador
		# mientras el aliado sigue vivo) es un texto aparte que no se
		# actualizaba con el número real.
		buffs.agregar("invocacion", icono_buff, duracion_invocacion, false,
			nombre_habilidad, "Tu aliado pelea a tu lado, golpeando por %d" % int(dano_ataque))
