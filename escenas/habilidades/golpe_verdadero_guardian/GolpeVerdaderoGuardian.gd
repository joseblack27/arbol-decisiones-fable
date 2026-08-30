class_name GolpeVerdaderoGuardian
extends Area2D
## Hitbox de golpe único, cuerpo a cuerpo, del Guardián Quebrado.
##
## A propósito NO pasa por Combate.golpear_area(): ese helper siempre marca
## el golpe como es_area=true (ver Combate.gd, línea del quitar_vida() al
## final de golpear_area()) — justo lo que ParryComponente necesita para
## que HabilidadCorte lo bloquee. Este golpe existe PARA NO ser bloqueable
## por el parry (el amague de fase 1, el castigo por cooldown de fase 3 y
## las transiciones de fase lo usan con ese propósito explícito, ver el
## diseño en escenas/enemigos/EnemigoGuardianQuebrado.gd) — mismo criterio
## que ya usa HabilidadCarga._physics_process para su daño de embestida
## (quitar_vida() directo, sin es_area).
##
## El resto (pooling, timer de vida, forma circular) es una copia deliberada
## de GolpeBasico.gd — mismo motivo por el que HabilidadCorte._golpear()
## tampoco reusa golpear_area(): necesita decidir "área o no" a mano.

var _daño: float = 20.0
var _duracion: float = 0.15
var _timer: float = 0.0
var _entidad_fuente: Node = null
var _configurado: bool = false
var _tipo_dano: Enums.Habilidad.TipoDano = Enums.Habilidad.TipoDano.FISICO
## true solo en la variante de fase 4 (arremetida) — mismo mecanismo de
## "daño verdadero" que ya usa HabilidadCorte del jugador.
var _ignora_defensa: bool = false

@onready var _col_shape: CollisionShape2D = $CollisionShape2D
var _forma: CircleShape2D


func _ready() -> void:
	_forma = _col_shape.shape as CircleShape2D


## cantidad_daño/radio/fuente/duracion/tipo — mismo contrato que
## GolpeBasico.configurar(). ignora_defensa agrega la variante de daño
## verdadero (ver cabecera).
func configurar(cantidad_daño: float, radio: float, fuente: Node, duracion: float,
		tipo: Enums.Habilidad.TipoDano = Enums.Habilidad.TipoDano.FISICO,
		ignora_defensa: bool = false) -> void:
	_daño = cantidad_daño
	_forma.radius = radio
	_entidad_fuente = fuente
	_duracion = duracion
	_tipo_dano = tipo
	_ignora_defensa = ignora_defensa
	_configurado = true
	_timer = 0.0
	set_deferred("monitorable", true)
	call_deferred("_aplicar_daño")


func _al_liberar_a_piscina() -> void:
	set_deferred("monitorable", false)


## Copia deliberada del cuerpo de Combate.golpear_area() — la única
## diferencia real es que quitar_vida() NO recibe es_area=true al final,
## así que ParryComponente.bloquea() nunca detiene este golpe.
func _aplicar_daño() -> void:
	var espacio := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _forma
	query.transform = global_transform
	query.collision_mask = 0xFFFFFFFF
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var ya_dañados: Array = []
	for r in espacio.intersect_shape(query):
		var col = r.get("collider")
		var vida: Node
		var objetivo: Node
		if col is VidaComponente:
			vida = col
			objetivo = (col as VidaComponente).get_parent()
		elif (col is Node) and (col as Node).has_method("quitar_vida"):
			vida = col
			objetivo = col
		else:
			continue
		if objetivo == _entidad_fuente or objetivo in ya_dañados:
			continue
		if Combate.mismo_equipo(_entidad_fuente, objetivo):
			continue
		ya_dañados.append(objetivo)
		var dano_final := AtributosComponente.calcular_pipeline(
			_entidad_fuente, objetivo, _daño, _tipo_dano, _ignora_defensa)
		var fue_critico := AtributosComponente.ultimo_pipeline_critico
		if vida is VidaComponente:
			(vida as VidaComponente).quitar_vida(dano_final, _entidad_fuente, _tipo_dano, fue_critico)
		else:
			vida.quitar_vida(dano_final, _entidad_fuente, _tipo_dano, fue_critico)
		if Utils.debe_mostrar_dano_local():
			BusEventos.daño_aplicado.emit(objetivo, dano_final, _entidad_fuente, _tipo_dano, fue_critico)
		BusEventos.habilidad_impacto.emit("golpe_verdadero_guardian", objetivo)


func _process(delta: float) -> void:
	if not _configurado:
		return
	_timer += delta
	if _timer >= _duracion:
		GestorPiscinas.liberar(self)


func _draw() -> void:
	if _forma:
		draw_circle(Vector2.ZERO, _forma.radius, Color(1.0, 0.25, 0.25, 0.3))
