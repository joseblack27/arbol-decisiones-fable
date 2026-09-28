extends Enemigo
class_name HuevoHormiga
## Huevo de hormiga: objeto ESTACIONARIO y destructible que la Reina deja con
## su Puesta de Huevos (ver HabilidadPuestaHuevos.gd). Extiende Enemigo
## directo (no una hormiga) para heredar el grupo "enemigos" (los ataques del
## jugador lo reconocen solos), las capas de colisión, VidaComponente y la
## réplica en red; sin IA, visión ni movimiento: espera a que lo rompan o a
## eclosionar.
##
## Usa el sprite real ant_larva_48x48_v4.png (asignado en HuevoHormiga.tscn).
## _generar_textura_placeholder() queda como respaldo si Sprite2D.texture
## llega sin asignar (ver _ready()).

const _ANCHO := 22
const _ALTO := 28
## Escala del placeholder generado acá (solo si no hay sprite asignado): a
## 22x28 px es más chico que un tile y se pierde en una pelea de jefe en el
## celular. Un sprite real asignado en el .tscn ya viene con su tamaño.
const _ESCALA_PLACEHOLDER := 2.2

## Duración del vuelo desde la Reina hasta el punto de aterrizaje -- ver
## lanzar_hacia().
const _DURACION_LANZAMIENTO := 0.45


func _ready() -> void:
	if sprite and sprite.texture == null:
		sprite.texture = _generar_textura_placeholder()
		sprite.scale = Vector2.ONE * _ESCALA_PLACEHOLDER
	super._ready()
	_iniciar_pulso()


## Vuela desde donde nació (la Reina, ver HabilidadPuestaHuevos._ejecutar)
## hasta "destino" y se queda ahí, para que la habilidad tenga una visual de
## lanzamiento en vez de aparecer de golpe. Al llegar sigue siendo el mismo
## huevo, con su pulso y su eclosión (ver _iniciar_pulso/_al_terminar_descanso).
## Solo se llama del lado con autoridad (_ejecutar() ya está limitada a
## servidor o sin red), así que el vuelo se replica con el mecanismo normal de
## posición de cualquier mob (ver Enemigo._physics_process), sin RPC propio.
func lanzar_hacia(destino: Vector2, duracion: float = _DURACION_LANZAMIENTO) -> void:
	var tween := create_tween()
	tween.tween_property(self, "global_position", destino, duracion) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


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
				# Aro amarillo bien saturado: a diferencia del relleno y el borde, que
				# Enemigo._aplicar_datos() tiñe con datos.color (un crema que se pierde
				# contra el piso de piedra), este no depende de esa multiplicación
				# para notarse.
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
	# Relativo a la escala YA puesta (2.2 del placeholder, o 1.0 si algún
	# día hay arte real sin este ajuste) -- no un valor absoluto fijo, para
	# no pisar el tamaño real de arriba.
	var base := sprite.scale
	var tween := create_tween().set_loops()
	tween.tween_property(sprite, "scale", base * 1.2, 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "scale", base, 0.5).set_trans(Tween.TRANS_SINE)
