extends EnemigoLobo
class_name EnemigoLoboFeroz

# =============================================================================
# 🐺🔥 LOBO FEROZ — variante más agresiva del Lobo normal.
#
# Hereda de EnemigoLobo (antes duplicaba a mano sus 4 handlers de arañazo/
# carga — ver _ready() de EnemigoLobo.gd, ahora se heredan tal cual): mismo
# combo arañazo+embestida (arañazo si está cerca, carga si el jugador se
# aleja — ver Carga.tres, rango_minimo=60 ya cubre ese caso), pero con
# arañazo mucho más seguido (ArañazoLoboFeroz.tres) y persecución más
# rápida (EnemigoDatos.velocidad_base más alto, en LoboFeroz.tres).
#
# Además tiene una esquiva reactiva: cada vez que CUALQUIER habilidad se
# activa a menos de 100px de él (BusEventos.habilidad_usada, ver
# HabilidadBase.activar()), tiene 30% de probabilidad de parpadear hacia un
# lado (izquierda o derecha al azar, perpendicular a la dirección hacia el
# que lanzó la habilidad) — no forma parte de SelectorHabilidades, es un
# reflejo que se dispara por señal, igual que el arañazo/carga del Lobo.
# =============================================================================

@onready var _habilidad_parpadeo: HabilidadParpadeo = $Habilidades/HabilidadParpadeo

const _DISTANCIA_REACCION := 100.0
const _PROBABILIDAD_ESQUIVA := 0.3


func _ready() -> void:
	super._ready()
	BusEventos.habilidad_usada.connect(_on_habilidad_usada_cerca)


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
