extends Node
## Autoload central de música de fondo — mismo criterio que GestorSonido
## (bus propio, no depende de un default_bus_layout.tres a mano) pero con UN
## solo AudioStreamPlayer en loop, no un pool: acá no hay "varios sonidos a
## la vez", es una sola pista de fondo que suena todo el tiempo. Bus "Music"
## separado de "SFX" para que el volumen se controle por separado desde
## PanelConfiguracion (Utils.volumen_musica), sin afectar los efectos.

const NOMBRE_BUS := "Music"
const PISTA_POR_DEFECTO := "res://assets/audio/otros/Path_to_the_Moonlit_Grove.mp3"

@onready var _reproductor: AudioStreamPlayer = AudioStreamPlayer.new()


func _ready() -> void:
	if AudioServer.get_bus_index(NOMBRE_BUS) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, NOMBRE_BUS)
		AudioServer.set_bus_send(idx, "Master")
	_reproductor.bus = NOMBRE_BUS
	add_child(_reproductor)
	aplicar_volumen()
	reproducir(load(PISTA_POR_DEFECTO))


## Vuelca Utils.volumen_musica (0.0-1.0) al bus real. Llamarlo al arrancar
## (arriba) y cada vez que el jugador mueve el control en Configuración.
func aplicar_volumen() -> void:
	var idx := AudioServer.get_bus_index(NOMBRE_BUS)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(Utils.volumen_musica, 0.0, 1.0)))


## Reproduce "pista" en loop — no hace nada si ya es la pista sonando (evita
## reiniciarla desde cero si algo llama esto de nuevo con la misma música).
func reproducir(pista: AudioStream) -> void:
	if pista == null or _reproductor.stream == pista:
		return
	_reproductor.stream = pista
	_reproductor.play()
