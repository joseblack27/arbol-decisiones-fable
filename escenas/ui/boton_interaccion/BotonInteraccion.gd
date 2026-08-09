extends Button
## Botón fijo de interacción (a la izquierda del paginador de habilidades,
## ver Mundo.tscn) — se muestra solo cuando GestorInteraccion tiene algo
## cerca disponible (hoy: hablar con un Npc; a futuro, cualquier otra cosa
## que se registre ahí). No sabe nada de NPCs ni de diálogo: solo refleja
## lo que GestorInteraccion le informa y le delega el toque.

func _ready() -> void:
	visible = false
	pressed.connect(GestorInteraccion.interactuar)
	GestorInteraccion.disponible.connect(_on_disponible)
	GestorInteraccion.no_disponible.connect(_on_no_disponible)


func _on_disponible(_objeto: Node, texto: String) -> void:
	text = texto
	visible = true


func _on_no_disponible() -> void:
	visible = false
