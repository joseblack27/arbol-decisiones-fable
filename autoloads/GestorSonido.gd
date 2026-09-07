extends Node
## Autoload central de efectos de sonido (SFX) — primer sistema de audio del
## proyecto (antes no había ni un solo AudioStreamPlayer). Bus "SFX" propio
## (se crea acá si no existe, no depende de un default_bus_layout.tres a
## mano) para que el volumen se controle desde PanelConfiguracion sin tocar
## Master ni pisar música que se agregue más adelante.
##
## Pool chico de AudioStreamPlayer reciclados (mismo criterio que
## GestorPiscinas/GestorNumerosDano): instanciar uno nuevo por cada sonido
## sería el mismo tipo de tirón ya evitado ahí.

const NOMBRE_BUS := "SFX"
const TAMANO_POOL := 4

var _pool: Array[AudioStreamPlayer] = []
var _siguiente := 0


func _ready() -> void:
	if AudioServer.get_bus_index(NOMBRE_BUS) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, NOMBRE_BUS)
		AudioServer.set_bus_send(idx, "Master")
	for i in range(TAMANO_POOL):
		var jugador := AudioStreamPlayer.new()
		jugador.bus = NOMBRE_BUS
		add_child(jugador)
		_pool.append(jugador)
	aplicar_volumen()


## Vuelca Utils.volumen_sfx (0.0-1.0) al bus real. Llamarlo al arrancar
## (arriba) y cada vez que el jugador mueve el control en Configuración —
## así el cambio se escucha al instante, no recién en el próximo sonido.
func aplicar_volumen() -> void:
	var idx := AudioServer.get_bus_index(NOMBRE_BUS)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(Utils.volumen_sfx, 0.0, 1.0)))


## Reproduce "sonido" en el siguiente reproductor libre del pool (round-robin
## simple: con TAMANO_POOL=4 y sonidos cortos como el de loot, nunca se
## llega a pisar uno que siga sonando en el uso normal del juego).
func reproducir(sonido: AudioStream) -> void:
	if sonido == null:
		return
	var jugador := _pool[_siguiente]
	_siguiente = (_siguiente + 1) % _pool.size()
	jugador.stream = sonido
	jugador.play()
