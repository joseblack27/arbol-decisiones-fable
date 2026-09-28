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

	# El aliado es una IA persistente (~15 s tomando sus propias decisiones),
	# no un efecto instantáneo como Proyectil. Con el patrón normal de
	# HabilidadBase (cada peer corre su _ejecutar()), cada cliente creaba su
	# propia copia, congelada porque AliadoInvocado solo piensa en el
	# servidor, mientras el aliado real peleaba invisible. Solo el servidor
	# (o sin red) crea al aliado, dentro del contenedor "Enemigos" del
	# nivel: ReplicadorEnemigos lo replica como a un mob, y la posición y
	# animación viajan por el RPC de Enemigo._physics_process.
	if not (Utils.en_red() and not multiplayer.is_server()):
		var aliado = escena_aliado.instantiate()
		aliado.dueño                  = entidad_dueña
		aliado.dano_ataque            = dano_ataque
		aliado.rango_ataque           = rango_ataque
		aliado.intervalo_ataque       = intervalo_ataque
		aliado.velocidad_persecucion  = velocidad_persecucion
		aliado.activar(duracion_invocacion)
		# nivel_de_jugador() y no nivel_actual(): en el servidor conviven varios
		# niveles y nivel_actual() devuelve el primero cargado (Pradera). Con él,
		# un aliado invocado en otro nivel quedaba colgado de la malla de la
		# Pradera y se plantaba sin moverse ni atacar.
		var nivel := GestorNiveles.nivel_de_jugador(entidad_dueña)
		var contenedor: Node = (nivel.get_node_or_null("Enemigos") if nivel else null)
		if contenedor == null:
			contenedor = get_tree().current_scene
		# force_readable_name=true: el nombre viaja a los clientes y tiene que
		# ser el mismo en los dos lados — mismo motivo que SpawnerMobs._generar_uno().
		contenedor.add_child.call_deferred(aliado, true)
		aliado.set_deferred("global_position", (entidad_dueña as Node2D).global_position + Vector2(30, 0))

	if icono_buff != null:
		var buffs := entidad_dueña.get_node_or_null("BuffsComponente") as BuffsComponente
		if buffs == null:
			buffs = BuffsComponente.new()
			buffs.name = "BuffsComponente"
			entidad_dueña.add_child(buffs)
		# El daño es dano_ataque TAL CUAL (el aliado no tiene
		# AtributosComponente, ver AliadoInvocado._atacar), así que mostrar el
		# valor crudo es exacto. Esta es la descripción del buff activo (la que
		# ve el invocador mientras vive el aliado), aparte de la de
		# invocacion.tres.
		buffs.agregar("invocacion", icono_buff, duracion_invocacion, false,
			nombre_habilidad, "Tu aliado pelea a tu lado, golpeando por %d" % int(dano_ataque))
