class_name ActivadorSalaSpawners
extends Area2D
## Al entrar un jugador por primera vez, activa los SpawnerMobs de ESTA
## sala (arrancan con activo=false en el nivel, ver generar_nivel_
## hormiguero.gd) -- así la población del hormiguero crece sala por sala a
## medida que el grupo avanza, en vez de estar toda viva desde el
## arranque. Server-only (mismo criterio que Trampa.gd/Cepo.gd): el
## cliente nunca decide esto, solo ve el resultado (más hormigas
## apareciendo). SpawnerMobs ya expone activar()/desactivar() públicos --
## esto no necesita ninguna plomería nueva ahí.
##
## Se queda activado para siempre una vez pisado (no vuelve a desactivar
## los spawners al salir): la idea es que la población crezca, no que
## desaparezca si el grupo retrocede un paso.

## Los SpawnerMobs de esta sala -- puede ser más de uno si la sala tiene
## varios tipos de hormiga.
@export var spawners: Array[NodePath] = []

var _activado := false


func _ready() -> void:
	body_entered.connect(_on_body_entrada)


func _on_body_entrada(cuerpo: Node2D) -> void:
	if _activado:
		return
	# Autoridad real: en un solo jugador esto también corre (Utils.en_red()
	# da false), en red SOLO el servidor decide -- mismo gate que Trampa/Cepo.
	if Utils.en_red() and not multiplayer.is_server():
		return
	if not cuerpo.is_in_group("jugadores"):
		return
	_activado = true
	for ruta in spawners:
		var spawner := get_node_or_null(ruta)
		if spawner and spawner.has_method("activar"):
			spawner.activar()
