class_name PortalNivel
extends Area2D
## Salida de un nivel: cuando el jugador la pisa, pide a GestorNiveles cargar
## la escena destino. El anti-rebote (para no teletransportarse en bucle)
## vive en el gestor, no aquí.

## Escena de nivel a la que lleva este portal.
@export_file("*.tscn") var ruta_nivel_destino := ""
## Texto mostrado sobre el portal (p. ej. el nombre del destino).
@export var etiqueta := ""
## Dónde aparece un jugador que llega desde OTRO nivel usando el portal de
## regreso correspondiente a este (ver GestorNiveles._punto_de_llegada) —
## posición fija, elegida a mano en el editor para cada portal (mover este
## Marker2D "PuntoLlegada" hijo del portal), en vez de un punto al azar
## alrededor del círculo. Pedido explícito del usuario: "con eso se
## establece bien una buena posición de respawn" — un punto al azar podía
## caer en cualquier ángulo, incluso hacia terreno no despejado.
##
## OJO al moverlo por instancia: tiene que quedar FUERA del radio de
## disparo del portal (30 px, ver CircleShape2D_forma_portal) MÁS el propio
## radio del jugador (10 px, sin margen los círculos ya se tocan) — bug
## real encontrado con el valor por defecto original (0,40), exactamente
## en el borde: el jugador llegaba, tras vencer la gracia anti-rebote
## (1 s) sin haberse movido de ahí, el portal se reactivaba solo y lo
## mandaba de vuelta en bucle. El valor por defecto (0,64) deja margen de
## sobra.
@export var punto_llegada: Marker2D

const DIAMETRO_VISUAL := 72.0

@onready var _aro: Sprite2D = $Aro
@onready var _texto: Label = $Etiqueta


func _ready() -> void:
	add_to_group(&"portales_nivel")
	_texto.text = etiqueta
	_texto.reset_size()
	_texto.position = Vector2(-_texto.size.x / 2.0, -DIAMETRO_VISUAL * 0.8 - 8.0)
	if _aro.texture != null:
		_aro.scale = Vector2.ONE * (DIAMETRO_VISUAL / _aro.texture.get_size().x)
	# Pulso perpetuo para que el portal se distinga de la decoración.
	var pulso := create_tween().set_loops()
	pulso.tween_property(_aro, "scale", _aro.scale * 1.15, 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulso.tween_property(_aro, "scale", _aro.scale, 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# Sondeo en vez de body_entered: si el jugador pisa el portal durante la
# ventana de gracia del gestor, la señal única se perdería; sondeando,
# el viaje se dispara en cuanto la gracia expira. El gestor deduplica.
#
# En red esto corre SOLO en el servidor: es él quien decide el viaje y se lo
# ordena a todos (ver GestorNiveles.cambiar_nivel). Si cada peer viajara por
# su cuenta bastaba con que el portal se disparara en uno y no en el otro
# para que cliente y servidor quedaran en niveles distintos — el bug de "al
# salir de la cueva se buguea y no me puedo mover".
func _physics_process(_delta: float) -> void:
	if Utils.en_red() and not multiplayer.is_server():
		return
	# Sin "return" tras el primero: pueden estar dos jugadores parados encima
	# a la vez, y cada uno viaja por su cuenta.
	for cuerpo in get_overlapping_bodies():
		if cuerpo.is_in_group(&"jugadores"):
			_viajar(cuerpo)


## Viaja SOLO el jugador que pisó el portal. Antes esto cambiaba "el nivel del
## mundo", y como el servidor tenía un único nivel para todos, el primero que
## cruzaba se llevaba puestos a los demás: al resto se le cambiaba el mapa
## abajo de los pies sin haber hecho nada.
func _viajar(cuerpo: Node) -> void:
	if ruta_nivel_destino.is_empty():
		push_warning("PortalNivel '%s' sin ruta_nivel_destino." % name)
		return
	if not Utils.en_red():
		GestorNiveles.cambiar_nivel(ruta_nivel_destino)
		return
	# El nombre del nodo Jugador ES el peer id de su dueño (ver Jugador.gd).
	var nombre := String(cuerpo.name)
	if not nombre.is_valid_int():
		return
	GestorNiveles.mover_peer_a_nivel(int(nombre), ruta_nivel_destino)
