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


func _generar_textura_placeholder() -> ImageTexture:
	var imagen := Image.create(_ANCHO, _ALTO, false, Image.FORMAT_RGBA8)
	var centro := Vector2(_ANCHO / 2.0, _ALTO / 2.0)
	for y in _ALTO:
		for x in _ANCHO:
			var d := Vector2(x + 0.5, y + 0.5) - centro
			var normalizado := Vector2(d.x / (_ANCHO / 2.0), d.y / (_ALTO / 2.0))
			var dist := normalizado.length()
			if dist <= 0.82:
				imagen.set_pixel(x, y, Color(1.0, 1.0, 1.0, 1.0))
			elif dist <= 1.0:
				imagen.set_pixel(x, y, Color(0.25, 0.2, 0.12, 1.0))
	return ImageTexture.create_from_image(imagen)
