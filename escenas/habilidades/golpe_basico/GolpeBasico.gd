class_name GolpeBasico
extends Area2D
## Hitbox de corta duración para golpe cuerpo a cuerpo.
## Se destruye automáticamente al expirar la duración.
## Se crea puramente por código — no necesita escena .tscn.

var _daño: float           = 15.0
var _duracion: float       = 0.15
var _timer: float          = 0.0
var _entidad_fuente: Node  = null
var _configurado: bool     = false
var _tipo_dano: Enums.Skill.TypeDamage = Enums.Skill.TypeDamage.PHYSIC

@onready var _col_shape: CollisionShape2D = $CollisionShape2D
var _forma: CircleShape2D

func _ready() -> void:
	_forma = _col_shape.shape as CircleShape2D

## Configura el golpe y aplica el daño en el siguiente frame.
## cantidad_daño — daño aplicado a cada objetivo alcanzado.
## radio         — radio del área de golpe.
## fuente        — entidad que realizó el golpe (evita auto-daño).
## duracion      — segundos antes de que se destruya el nodo.
## tipo          — tipo de daño (afecta resistencias del defensor).
func configurar(cantidad_daño: float, radio: float, fuente: Node, duracion: float, tipo: Enums.Skill.TypeDamage = Enums.Skill.TypeDamage.PHYSIC) -> void:
	_daño           = cantidad_daño
	_forma.radius   = radio
	_entidad_fuente = fuente
	_duracion       = duracion
	_tipo_dano      = tipo
	_configurado    = true
	call_deferred("_aplicar_daño")

func _aplicar_daño() -> void:
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
			if entidad == _entidad_fuente or entidad in ya_dañados:
				continue
			if _mismo_equipo(_entidad_fuente, entidad):
				continue
			ya_dañados.append(entidad)
			var dano_final := AtributosComponente.calcular_pipeline(_entidad_fuente, entidad, _daño, _tipo_dano)
			col.quitar_vida(dano_final)
			BusEventos.daño_aplicado.emit(entidad, dano_final, _entidad_fuente)
			BusEventos.habilidad_impacto.emit("golpe_basico", entidad)
		elif col.has_method("quitar_vida"):
			if col == _entidad_fuente or col in ya_dañados:
				continue
			if _mismo_equipo(_entidad_fuente, col):
				continue
			ya_dañados.append(col)
			var dano_final := AtributosComponente.calcular_pipeline(_entidad_fuente, col, _daño, _tipo_dano)
			col.quitar_vida(dano_final)
			BusEventos.daño_aplicado.emit(col, dano_final, _entidad_fuente)
			BusEventos.habilidad_impacto.emit("golpe_basico", col)

static func _mismo_equipo(fuente: Node, objetivo: Node) -> bool:
	if fuente == null or objetivo == null:
		return false
	if fuente.is_in_group("enemigos") and objetivo.is_in_group("enemigos"):
		return true
	if fuente.is_in_group("jugadores") and objetivo.is_in_group("jugadores"):
		return true
	return false

func _process(delta: float) -> void:
	if not _configurado:
		return
	_timer += delta
	if _timer >= _duracion:
		queue_free()

func _draw() -> void:
	if _forma:
		draw_circle(Vector2.ZERO, _forma.radius, Color(1.0, 1.0, 1.0, 0.25))
