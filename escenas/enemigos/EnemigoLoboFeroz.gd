extends Enemigo
class_name EnemigoLoboFeroz

# =============================================================================
# 🐺🔥 LOBO FEROZ — variante más agresiva del Lobo normal.
#
# Mismo combo arañazo+embestida que el Lobo (arañazo si está cerca, carga si
# el jugador se aleja — ver Carga.tres, rango_minimo=60 ya cubre ese caso),
# pero con arañazo mucho más seguido (ArañazoLoboFeroz.tres) y persecución
# más rápida (EnemigoDatos.velocidad_base más alto, en LoboFeroz.tres).
#
# Además tiene una esquiva reactiva: cada vez que CUALQUIER habilidad se
# activa a menos de 100px de él (BusEventos.habilidad_usada, ver
# HabilidadBase.activar()), tiene 30% de probabilidad de parpadear hacia un
# lado (izquierda o derecha al azar, perpendicular a la dirección hacia el
# que lanzó la habilidad) — no forma parte de SelectorHabilidades, es un
# reflejo que se dispara por señal, igual que el arañazo/carga del Lobo.
# =============================================================================

@onready var ataque_arañazo: HabilidadArañazo = $Habilidades/HabilidadArañazo
@onready var habilidad_carga: HabilidadCarga  = $Habilidades/HabilidadCarga
@onready var _habilidad_parpadeo: HabilidadParpadeo = $Habilidades/HabilidadParpadeo

const _DISTANCIA_REACCION := 100.0
const _PROBABILIDAD_ESQUIVA := 0.3


func _ready() -> void:
	super._ready()
	ataque_arañazo.habilidad_activada.connect(_on_arañazo_activado)
	habilidad_carga.preparacion_iniciada.connect(_on_carga_preparacion)
	habilidad_carga.carga_iniciada.connect(_on_carga_iniciada)
	habilidad_carga.carga_terminada.connect(_on_carga_terminada)
	BusEventos.habilidad_usada.connect(_on_habilidad_usada_cerca)


# =============================================================================
# SEÑALES DE HABILIDADES (arañazo/carga — mismo patrón que EnemigoLobo)
# =============================================================================

func _on_arañazo_activado(_habilidad: HabilidadBase) -> void:
	componente_animacion.establecer_condicion("parameters/conditions/debeIdle", true)
	memoria.establecer("habilidad_lanzada", true)


## Ver el mismo comentario en EnemigoLobo.gd — mismo árbol de animación
## (esta escena se duplicó de ahí), mismo arreglo.
func _on_carga_preparacion() -> void:
	componente_animacion.establecer_condicion("parameters/conditions/debeMordidaPrep", true)


func _on_carga_iniciada(_direccion: Vector2, _multiplicador: float) -> void:
	componente_animacion.establecer_condicion("parameters/conditions/debeMordidaPrep", false)
	componente_animacion.establecer_condicion("parameters/conditions/debeMordidaDash", true)


func _on_carga_terminada() -> void:
	memoria.establecer("ataque_en_curso", false)
	componente_animacion.establecer_condicion("parameters/conditions/debeMordidaDash", false)
	componente_animacion.establecer_condicion("parameters/conditions/debeSalirMordida", true)
	componente_animacion.establecer_condicion("parameters/conditions/debeIdle", true)


# =============================================================================
# ESQUIVA REACTIVA (parpadeo lateral)
# =============================================================================

## Solo la autoridad real decide esto (servidor en red, o el único peer sin
## red) — mismo criterio que SelectorHabilidades, que tampoco corre en
## clientes puros: si un cliente puro también activara el parpadeo acá,
## quedaría un teletransporte "fantasma" desincronizado del que decide el
## servidor. HabilidadBase.activar() ya se encarga de replicar el efecto
## visual a los demás peers cuando el servidor la llama.
func _on_habilidad_usada_cerca(entidad: Node, _tipo_habilidad: String) -> void:
	if Utils.en_red() and not multiplayer.is_server():
		return
	if _muerto or entidad == self or not is_instance_valid(entidad):
		return
	var objetivo := entidad as Node2D
	if not objetivo:
		return
	if Combate.mismo_equipo(self, entidad):
		return
	if global_position.distance_to(objetivo.global_position) > _DISTANCIA_REACCION:
		return
	if randf() >= _PROBABILIDAD_ESQUIVA:
		return
	if not _habilidad_parpadeo or not _habilidad_parpadeo.puede_usarse():
		return
	var hacia_objetivo := (objetivo.global_position - global_position).normalized()
	var lado := PI / 2.0 if randf() < 0.5 else -PI / 2.0
	_habilidad_parpadeo.activar(hacia_objetivo.rotated(lado), 1.0)
