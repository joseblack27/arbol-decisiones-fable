class_name Arañazo
extends Area2D
## Hitbox + visual efímero del ataque Arañazo.
## Se instancia en HabilidadArañazo._ejecutar(), aplica daño al aparecer
## y se destruye al terminar la animación.

var _daño: float = 15.0
var _entidad_fuente: Node = null
var _tipo_dano: Enums.Skill.TypeDamage = Enums.Skill.TypeDamage.PHYSIC

@onready var _col_shape: CollisionShape2D = $CollisionShape2D
@onready var _animacion: AnimationPlayer  = $AnimationPlayer
var _forma: CircleShape2D


func _ready() -> void:
	_forma = _col_shape.shape as CircleShape2D
	_animacion.animation_finished.connect(_on_animacion_terminada)


## Misma firma que GolpeBasico.configurar() — compatible con HabilidadGolpeBasico._ejecutar().
## duracion se ignora: el tiempo de vida lo controla la animación.
func configurar(cantidad_daño: float, radio: float, fuente: Node, _duracion: float,
		tipo: Enums.Skill.TypeDamage = Enums.Skill.TypeDamage.PHYSIC) -> void:
	_daño           = cantidad_daño
	_forma.radius   = radio
	_entidad_fuente = fuente
	_tipo_dano      = tipo
	_animacion.play("ataque_arañazo")
	call_deferred("_aplicar_daño")


func _aplicar_daño() -> void:
	var espacio := get_world_2d().direct_space_state
	var query   := PhysicsShapeQueryParameters2D.new()
	query.shape               = _forma
	query.transform           = global_transform
	query.collision_mask      = 0xFFFFFFFF
	query.collide_with_areas  = true
	query.collide_with_bodies = true
	var resultados := espacio.intersect_shape(query)
	var ya_dañados: Array = []
	for r in resultados:
		var col = r.get("collider")
		if col is VidaComponente:
			var entidad = col.get_parent()
			if entidad == _entidad_fuente or entidad in ya_dañados:
				continue
			if _mismo_equipo(_entidad_fuente, entidad):
				continue
			ya_dañados.append(entidad)
			var dano_final := AtributosComponente.calcular_pipeline(_entidad_fuente, entidad, _daño, _tipo_dano)
			col.quitar_vida(dano_final)
			BusEventos.daño_aplicado.emit(entidad, dano_final, _entidad_fuente)
			BusEventos.habilidad_impacto.emit("arañazo", entidad)
		elif col.has_method("quitar_vida"):
			if col == _entidad_fuente or col in ya_dañados:
				continue
			if _mismo_equipo(_entidad_fuente, col):
				continue
			ya_dañados.append(col)
			var dano_final := AtributosComponente.calcular_pipeline(_entidad_fuente, col, _daño, _tipo_dano)
			col.quitar_vida(dano_final)
			BusEventos.daño_aplicado.emit(col, dano_final, _entidad_fuente)
			BusEventos.habilidad_impacto.emit("arañazo", col)

static func _mismo_equipo(fuente: Node, objetivo: Node) -> bool:
	if fuente == null or objetivo == null:
		return false
	if fuente.is_in_group("enemigos") and objetivo.is_in_group("enemigos"):
		return true
	if fuente.is_in_group("jugadores") and objetivo.is_in_group("jugadores"):
		return true
	return false


func _on_animacion_terminada(_anim_name: String) -> void:
	queue_free()
