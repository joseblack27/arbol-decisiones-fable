class_name HabilidadBuffEquipo
extends HabilidadBase
## Grito de guerra: buff instantáneo (no un aura continua) que sube el
## daño de vos y de tus aliados cercanos por un tiempo — botón tap, sin
## dirección, como Curación/Escudo.
##
## El bono NO se guarda en AtributosComponente.base (eso lo pisa
## recalcular_con_equipo() cada vez que alguien cambia de equipo, ver ese
## archivo) — usa AtributosComponente.agregar_bono_temporal(), que
## vive aparte y se quita solo al vencer.
##
## Red: esta copia (dueño local en predicción, o servidor con autoridad)
## aplica el bono DIRECTO a cualquier aliado que encuentre en su propio
## árbol (Combate.buscar_aliados_cercanos) — para el dueño esto ya alcanza
## (su propia predicción). Pero un aliado AJENO solo se entera de verdad
## si SU PROPIO cliente corre esto también: por eso el servidor, aparte de
## aplicar el bono con autoridad, avisa a los peers cercanos con la lista
## de a quién le tocó — cada cliente se fija si ESTÁ en esa lista (mismo
## criterio local-only que ya usa toda la UI de este proyecto) y si es así
## se aplica el bono a SU PROPIO jugador (Utils.jugador_local()).

@export_group("Buff")
@export var radio_buff: float = 150.0
@export var bono_dano: float = 15.0
@export var duracion_buff: float = 10.0
## Ícono que muestra BarraBuffs mientras el buff está activo en cada
## aliado alcanzado (incluido quien lo lanza). Null = no se anota en
## BuffsComponente (queda sin ícono en el HUD).
@export var icono_buff: Texture2D = null

const _ID_BUFF := "buff_equipo_dano"
const _ESCENA_CIRCULO := preload("res://escenas/habilidades/buff_equipo/EfectoCirculoBuffEquipo.tscn")


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Grito de guerra"
	tipo_habilidad   = "buff_equipo"
	requiere_direccion = false


func _ejecutar(_direccion: Vector2, _poder: float) -> void:
	if not is_instance_valid(entidad_dueña) or not (entidad_dueña is Node2D):
		return
	_mostrar_circulo_area()
	var aliados := Combate.buscar_aliados_cercanos(entidad_dueña as Node2D, radio_buff, entidad_dueña)
	for aliado in aliados:
		_aplicar_buff_local(aliado)

	# Avisar a los aliados AJENOS (no a mí mismo: mi propia predicción de
	# arriba ya me lo aplicó) — solo tiene sentido con autoridad real: el
	# servidor es quien sabe de verdad a quién le tocó.
	if not (Utils.en_red() and multiplayer.is_server()):
		return
	var ids_aliados: Array = []
	for aliado in aliados:
		if aliado != entidad_dueña and is_instance_valid(aliado) and ("peer_id_dueño" in aliado):
			ids_aliados.append(aliado.peer_id_dueño)
	if ids_aliados.is_empty():
		return
	for peer_id in InteresEspacial.peers_cercanos((entidad_dueña as Node2D).global_position):
		rpc_id(peer_id, "_recibir_buff_equipo_red", ids_aliados)


## Círculo verde puramente visual (pedido del usuario: "para saber hasta
## donde llegó", mismo criterio que el círculo blanco de GolpeBasico/
## AreaEfecto) — no aplica nada de daño ni colisión, el bono real ya se
## aplicó arriba. Se salta en headless (servidor dedicado): nadie lo va a
## ver ahí, no vale la pena ni instanciarlo.
func _mostrar_circulo_area() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var efecto := GestorPiscinas.obtener(_ESCENA_CIRCULO) as EfectoCirculoBuffEquipo
	efecto.global_position = (entidad_dueña as Node2D).global_position
	efecto.configurar(radio_buff)


func _aplicar_buff_local(aliado: Node) -> void:
	if not is_instance_valid(aliado):
		return
	var atributos := aliado.get_node_or_null("AtributosComponente") as AtributosComponente
	if atributos:
		atributos.agregar_bono_temporal(_ID_BUFF, bono_dano, 0.0, 0.0, 0.0, duracion_buff)
	if icono_buff == null:
		return
	var buffs := aliado.get_node_or_null("BuffsComponente") as BuffsComponente
	if buffs == null:
		buffs = BuffsComponente.new()
		buffs.name = "BuffsComponente"
		aliado.add_child(buffs)
	buffs.agregar(_ID_BUFF, icono_buff, duracion_buff, false,
		nombre_habilidad, "Aumenta el daño en +%d" % int(bono_dano))


## CLIENTE: el servidor avisa que a MI jugador (si está en la lista) le
## tocó el buff — mi propia predicción nunca se hubiera enterado sola
## (nunca corrió su propia búsqueda de aliados con autoridad real, ver
## _ejecutar arriba: en un cliente puro esa búsqueda solo sirve para la
## PREDICCIÓN de quien lanzó, no para decidir nada por los demás).
@rpc("authority", "reliable")
func _recibir_buff_equipo_red(ids_aliados: Array) -> void:
	var yo := Utils.jugador_local()
	if yo == null or not ("peer_id_dueño" in yo):
		return
	if yo.peer_id_dueño in ids_aliados:
		_aplicar_buff_local(yo)
