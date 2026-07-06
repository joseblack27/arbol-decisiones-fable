extends Node2D
## Mundo: cascarón persistente del juego (jugador + interfaz). El contenido
## jugable vive en niveles intercambiables dentro de ContenedorNivel;
## GestorNiveles se encarga de cambiarlos (los portales se lo piden).

@export_file("*.tscn") var nivel_inicial := "res://niveles/NivelPradera.tscn"


func _ready() -> void:
	GestorNiveles.registrar($ContenedorNivel, $Jugador)
	GestorNiveles.cambiar_nivel(nivel_inicial)
