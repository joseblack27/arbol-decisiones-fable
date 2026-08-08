class_name HabilidadSacudida
extends HabilidadBase
## Golpe en área alrededor tuyo que aturde brevemente a los enemigos
## cercanos — sin empujarlos (a diferencia de Onda de Choque) y sin hacer
## daño: es control puro. Pensada para cortar una preparación (una
## embestida, un disparo cargado) antes de que salga — ver EfectoAturdir,
## que además de bloquear el movimiento pausa la IA y las habilidades del
## objetivo, no solo su desplazamiento.

@export_group("Sacudida")
@export var radio: float = 90.0
@export var duracion_aturdimiento: float = 1.2
## Ícono que muestra BuffsComponente sobre cada enemigo aturdido — se
## PISA con aplicar_datos() (ver ese método) al equiparse de verdad: el
## valor de acá es solo un respaldo para cuando algo crea esta habilidad
## sin pasar por un DatosHabilidad (pruebas, por ejemplo).
@export var icono_debuff: Texture2D = null

## Misma capa que usan las demás habilidades de área para su consulta
## (Marca, Acumulación, Onda de Choque).
const MASCARA_OBJETIVOS := 0xFFFFFFFF

const _ESCENA_EFECTO := "res://escenas/efectos/EfectoAturdir.gd"


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Sacudida"
	tipo_habilidad   = "sacudida"
	requiere_direccion = false


## El ícono de aturdido tiene que ser el mismo que ves en el botón — pedido
## del usuario: "quiero que el icono que salga como debuff o buff sea el
## que se usa como habilidad no el del proyectil" (dicho para Veneno, pero
## aplica igual acá: antes este export vivía suelto en el .tscn, sin
## relación con sacudida.tres).
func aplicar_datos(d: DatosHabilidad) -> void:
	super.aplicar_datos(d)
	if d.icono:
		icono_debuff = d.icono


func _ejecutar(_direccion: Vector2, _poder: float) -> void:
	if not is_instance_valid(entidad_dueña):
		return
	var origen := entidad_dueña as Node2D
	if origen == null:
		return

	# Feedback visual del radio real — pedido del usuario: sin esto, Sacudida
	# aplicaba su efecto en silencio, sin nada en pantalla que confirmara
	# dónde ni qué tan lejos llegaba (ver IndicadorZonaEfecto).
	var indicador := IndicadorZonaEfecto.new()
	indicador.radio = radio
	indicador.color_relleno = Color(0.6, 0.8, 1.0, 0.35)
	indicador.color_borde = Color(0.65, 0.85, 1.0, 0.9)
	origen.get_tree().current_scene.add_child(indicador)
	indicador.global_position = origen.global_position

	var espacio := origen.get_world_2d().direct_space_state
	var forma := CircleShape2D.new()
	forma.radius = radio
	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = forma
	consulta.transform = Transform2D(0.0, origen.global_position)
	consulta.collision_mask = MASCARA_OBJETIVOS
	consulta.collide_with_areas = false
	consulta.collide_with_bodies = true

	for resultado in espacio.intersect_shape(consulta, 32):
		var cuerpo = resultado.get("collider")
		if not (cuerpo is Node) or cuerpo == entidad_dueña:
			continue
		if Combate.mismo_equipo(entidad_dueña, cuerpo):
			continue
		if (cuerpo as Node).get_node_or_null("VidaComponente") == null:
			continue
		var efecto = (load(_ESCENA_EFECTO) as GDScript).new()
		efecto.objetivo = cuerpo
		efecto.duracion = duracion_aturdimiento
		efecto.icono_debuff = icono_debuff
		(cuerpo as Node).add_child(efecto)
