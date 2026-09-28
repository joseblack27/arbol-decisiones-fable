extends Control
## Pantalla de Game Over: una escena con sus propios nodos. Reacciona a
## BusEventos.jugador_murio/jugador_reaparecio, que Jugador.gd solo emite para
## el dueño local (_es_dueño_local()), así que nunca se muestra por la muerte
## de OTRO jugador.

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
