class_name AreaEfecto
extends Area2D
## Área temporal que daña todos los VidaComponentes dentro al activarse.
## Se destruye automáticamente al terminar duracion_efecto.
## Se crea puramente por código — no necesita escena .tscn.

@export var radio_base: float       = 80.0
@export var daño: float             = 30.0
@export var duracion_efecto: float  = 0.4

var entidad_fuente: Node = null
var tipo_dano: Enums.Skill.TypeDamage = Enums.Skill.TypeDamage.PHYSIC

@onready var _col_shape: CollisionShape2D = $CollisionShape2D
var _forma: CircleShape2D
var _timer: float   = 0.0
var _activado: bool = false

func _ready() -> void:
	_forma = _col_shape.shape as CircleShape2D

## Configura el área antes de que empiece a procesar.
## cantidad_daño — daño a aplicar a cada objetivo.
## fuente        — entidad que originó el área (evita auto-daño).
## tipo          — tipo de daño (afecta resistencias del defensor).
func configurar(cantidad_daño: float, fuente: Node, tipo: Enums.Skill.TypeDamage = Enums.Skill.TypeDamage.PHYSIC) -> void:
	daño           = cantidad_daño
	entidad_fuente = fuente
	tipo_dano      = tipo
	_forma.radius  = radio_base
	call_deferred("_aplicar_daño")

func _aplicar_daño() -> void:
	_activado = true
	var espacio := get_world_2d().direct_space_state
	var query   := PhysicsShapeQueryParameters2D.new()
	query.shape               = _forma
	query.transform           = global_transform
	query.collision_mask      = 0xFFFFFFFF
	query.collide_with_areas  = true
	query.collide_with_bodies = true
	var resultados  := espacio.intersect_shape(query)
	var ya_dañados: Array = []
	for r in resultados:
		var col = r.get("collider")
		if col is VidaComponente:
			var entidad = col.get_parent()
			if entidad == entidad_fuente or entidad in ya_dañados:
				continue
			ya_dañados.append(entidad)
			var dano_final := AtributosComponente.calcular_pipeline(entidad_fuente, entidad, daño, tipo_dano)
			col.quitar_vida(dano_final)
			BusEventos.daño_aplicado.emit(entidad, dano_final, entidad_fuente)
			BusEventos.habilidad_impacto.emit("area_efecto", entidad)
		elif col.has_method("quitar_vida"):
			if col == entidad_fuente or col in ya_dañados:
				continue
			ya_dañados.append(col)
			var dano_final := AtributosComponente.calcular_pipeline(entidad_fuente, col, daño, tipo_dano)
			col.quitar_vida(dano_final)
			BusEventos.daño_aplicado.emit(col, dano_final, entidad_fuente)
			BusEventos.habilidad_impacto.emit("area_efecto", col)

func _process(delta: float) -> void:
	if not _activado:
		return
	_timer += delta
	if _timer >= duracion_efecto:
		queue_free()

func _draw() -> void:
	if _forma:
		draw_circle(Vector2.ZERO, _forma.radius, Color(0.8, 0.2, 0.8, 0.35))
		draw_arc(Vector2.ZERO, _forma.radius, 0.0, TAU, 32, Color(0.8, 0.2, 0.8, 0.9), 2.0)
