extends Control
## Pantalla de Game Over — antes morir solo mostraba un Label armado por
## código (Jugador._mostrar_aviso_muerte, eliminado); ahora es una escena
## real con sus propios nodos (pedido explícito del usuario: "crea todos
## los nodos, no quiero que generes nodos por código"). Reacciona a
## BusEventos.jugador_murio/jugador_reaparecio — ambas señales ya estaban
## declaradas pero nunca se emitían (código muerto), quedaron enganchadas
## acá. Las dos están gateadas del lado de Jugador.gd a _es_dueño_local(),
## así que este panel nunca se muestra por la muerte de OTRO jugador.

@onready var _subtitulo: Label = $CenterContainer/VBox/Subtitulo
@onready var _temporizador: Timer = $Temporizador

var _restante: int = 0


func _ready() -> void:
	hide()
	BusEventos.jugador_murio.connect(_mostrar)
	BusEventos.jugador_reaparecio.connect(_ocultar)
	_temporizador.timeout.connect(_actualizar_cuenta_regresiva)


func _mostrar(tiempo_reaparicion: float) -> void:
	_restante = int(ceil(tiempo_reaparicion))
	_subtitulo.text = "Reapareces en %d..." % _restante
	show()
	_temporizador.start()


func _ocultar(_posicion: Vector2) -> void:
	_temporizador.stop()
	hide()


func _actualizar_cuenta_regresiva() -> void:
	_restante = maxi(_restante - 1, 0)
	_subtitulo.text = "Reapareces en %d..." % _restante
	if _restante <= 0:
		_temporizador.stop()
