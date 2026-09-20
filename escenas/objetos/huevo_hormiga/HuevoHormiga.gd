extends Enemigo
class_name HuevoHormiga
## Huevo de hormiga: objeto ESTACIONARIO y destructible que la Reina deja
## durante su Puesta de Huevos (ver HabilidadPuestaHuevos.gd). Extiende
## Enemigo directo (no una hormiga real) para heredar gratis grupo
## "enemigos" (los ataques del jugador ya lo reconocen como objetivo válido
## sin nada especial), capas de colisión, VidaComponente y réplica en red —
## sin IA, sin visión, sin movimiento: solo se queda ahí a esperar a que lo
## rompan o a eclosionar.
##
## Textura placeholder generada por código (óvalo relleno, tintado con
## datos.color) en vez de un sprite dedicado — reemplazar por arte real más
## adelante no necesita tocar este script, solo asignar Sprite2D.texture a
## mano en el .tscn (ver _ready(), que respeta cualquier textura ya puesta).

const _ANCHO := 22
const _ALTO := 28


func _ready() -> void:
	if sprite and sprite.texture == null:
		sprite.texture = _generar_textura_placeholder()
	super._ready()
	_iniciar_pulso()


func _generar_textura_placeholder() -> ImageTexture:
	var imagen := Image.create(_ANCHO, _ALTO, false, Image.FORMAT_RGBA8)
	var centro := Vector2(_ANCHO / 2.0, _ALTO / 2.0)
	for y in _ALTO:
		for x in _ANCHO:
			var d := Vector2(x + 0.5, y + 0.5) - centro
			var normalizado := Vector2(d.x / (_ANCHO / 2.0), d.y / (_ALTO / 2.0))
			var dist := normalizado.length()
			if dist <= 0.7:
				imagen.set_pixel(x, y, Color(1.0, 1.0, 1.0, 1.0))
			elif dist <= 0.85:
				imagen.set_pixel(x, y, Color(0.15, 0.12, 0.08, 1.0))
			elif dist <= 1.0:
				# Aro amarillo bien saturado -- a diferencia del relleno/borde
				# de arriba (que Enemigo._aplicar_datos() tiñe con datos.color,
				# un cream/tan que se puede perder contra el piso de piedra),
				# este aro no depende de esa multiplicación para notarse:
				# reportado en juego real (19 sep 2026) que el huevo/larva no
				# se veía nada durante la Puesta de Huevos de la Reina.
				imagen.set_pixel(x, y, Color(1.0, 0.9, 0.2, 1.0))
	return ImageTexture.create_from_image(imagen)


## Pulso sutil de escala mientras el huevo sigue vivo, para que no pase
## desapercibido en medio del combate (chico, quieto, y de tonos similares
## al piso) -- ver comentario de _generar_textura_placeholder(). El Tween
## queda atado a este nodo (Node.create_tween()), así que se corta solo si
## el huevo se destruye o eclosiona antes de terminar de pulsar.
func _iniciar_pulso() -> void:
	if not sprite:
		return
	var tween := create_tween().set_loops()
	tween.tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_SINE)
