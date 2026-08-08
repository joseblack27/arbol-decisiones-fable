extends Node
class_name EfectoTemporalPegado
## Base común para efectos NEGATIVOS "pegados" al objetivo — viven colgados
## de él con su propia duración y lo siguen a donde vaya (ver EfectoVeneno,
## EfectoLentitud). Distinto de los efectos de ZONA (ver EfectoAreaBase:
## Inmovilizar, DoT, Marca), que solo aplican mientras el objetivo está
## físicamente parado dentro de un área.
##
## Sirve para que HabilidadPurga pueda encontrar y cancelar TODOS los
## debuffs temporales que lleve encima una entidad sin conocer cada tipo por
## separado: cualquier debuff nuevo que extienda esto queda cubierto solo.
## Los efectos de zona/mapa se dejan afuera A PROPÓSITO (no extienden esto):
## purgarlos no tendría sentido — el objetivo los vuelve a sufrir apenas
## siga parado ahí — y el usuario pidió explícitamente que un futuro debuff
## de zona/mapa NO sea afectado por Purga.

## Purga solo cancela esto si es true — deja la puerta abierta a un efecto
## "pegado" que sea beneficioso en vez de un debuff (hoy no hay ninguno:
## Escudo/Curación son componentes aparte, no este patrón).
@export var es_debuff: bool = true

## Asignado por quien lo crea (ver Proyectil._spawnear_efecto_impacto) ANTES
## de add_child() — para acá y para las subclases.
var objetivo: Node = null


## Aborta el efecto ANTES de aplicar nada si el objetivo tiene puesta la
## inmunidad temporal que deja Purga (ver InmunidadDebuffsComponente). Las
## subclases DEBEN llamar a super._ready() primero y cortar si esto ya puso
## el nodo en cola de borrado — queue_free() no interrumpe por sí solo el
## resto de un _ready() ya en curso.
##
## Por NOMBRE de nodo y no por tipo a propósito: referenciar la clase le
## daría a esta base una dependencia dura hacia InmunidadDebuffsComponente,
## y esta clase la extienden EfectoVeneno/EfectoLentitud, usados desde
## Proyectil.gd en contextos --script donde los autoloads todavía pueden no
## estar resueltos (mismo criterio que VisionComponente._es_objetivo_valido
## con CamuflajeComponente).
func _ready() -> void:
	if not es_debuff or objetivo == null:
		return
	var inmunidad = objetivo.get_node_or_null("InmunidadDebuffsComponente")
	if inmunidad != null and inmunidad.esta_activa():
		queue_free()


## Cancela el efecto YA, antes de que venza solo — dispara la misma
## limpieza que su vencimiento natural (cada subclase la resuelve en
## _exit_tree/queue_free), así que basta con liberarlo.
func cancelar() -> void:
	queue_free()
