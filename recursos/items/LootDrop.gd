extends Resource
class_name LootDrop
## Una entrada de la tabla de botín de un enemigo: qué ítem soltar (directo
## al inventario del jugador — nunca queda tirado en el suelo) y con qué
## probabilidad. Cada entrada de una tabla se evalúa de forma independiente.

@export var item: DatosItem
## 0.0-1.0 — probabilidad de que este ítem se otorgue al morir el enemigo.
@export_range(0.0, 1.0) var probabilidad: float = 1.0
