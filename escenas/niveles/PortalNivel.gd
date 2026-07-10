class_name PortalNivel
extends Area2D
## Salida de un nivel: cuando el jugador la pisa, pide a GestorNiveles cargar
## la escena destino. El anti-rebote (para no teletransportarse en bucle)
## vive en el gestor, no aquí.

## Escena de nivel a la que lleva este portal.
@export_file("*.tscn") var ruta_nivel_destino := ""
## Texto mostrado sobre el portal (p. ej. el nombre del destino).
@export var etiqueta := ""

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
func _physics_process(_delta: float) -> void:
	for cuerpo in get_overlapping_bodies():
		if cuerpo.is_in_group(&"jugadores"):
			_viajar()
			return


func _viajar() -> void:
	if ruta_nivel_destino.is_empty():
		push_warning("PortalNivel '%s' sin ruta_nivel_destino." % name)
		return
	GestorNiveles.cambiar_nivel(ruta_nivel_destino)
