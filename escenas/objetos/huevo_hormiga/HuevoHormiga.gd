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
## Usa el sprite real `assets/sprites/ant_larva_48x48_v4.png` (asignado a
## mano en HuevoHormiga.tscn, ver Sprite2D.texture) — antes era una
## textura placeholder generada por código (óvalo relleno), reemplazada
## tras confirmarse en juego real que ni el contraste ni el tamaño del
## placeholder alcanzaban para que se notara en medio de una pelea de
## jefe. `_generar_textura_placeholder()` sigue acá como respaldo (ver
## _ready(), que solo la usa si Sprite2D.texture llega sin asignar).

const _ANCHO := 22
const _ALTO := 28
## Reportado en juego real (20 sep 2026, tras ya haberle subido el
## contraste): seguía sin verse NADA. Causa real -- no era contraste, era
## tamaño: 22x28px es más chico que UN SOLO tile (32x32) y bastante menos
## que una hormiga real en pantalla (guardián ~96x96px, sprite 64x64
## escalado x1.5, ver EnemigoHormigaSoldado.tscn) -- en medio de una
## pelea de jefe, con efectos y otras hormigas alrededor, un punto tan
## chico (aunque pulse) es prácticamente imperceptible en un celular real.
## Escala SOLO del placeholder generado acá -- si algún día se reemplaza
## por arte real asignado a mano en el .tscn (ver comentario de clase),
## ese sprite ya vendría con el tamaño que corresponda, sin necesidad de
## este ajuste.
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
	# DIAGNÓSTICO TEMPORAL (21 sep 2026) -- confirmar si el huevo llega a
	# crearse en el CLIENTE (réplica del MultiplayerSpawner) y en qué
	# estado -- ver [DIAG huevos] en HabilidadPuestaHuevos.gd para el
	# equivalente del lado servidor. Sacar cuando se resuelva.
	if Utils.en_red() and not multiplayer.is_server():
		print("[DIAG huevo cliente] creado en %s visible=%s sprite_visible=%s textura=%s escala=%s" % [
			global_position, visible, sprite.visible if sprite else "sin sprite",
			(sprite.texture != null) if sprite else "sin sprite", sprite.scale if sprite else "sin sprite"])


## Vuela desde donde nació (la Reina, ver HabilidadPuestaHuevos._ejecutar)
## hasta "destino" y se queda ahí quieto -- pedido explícito del usuario
## (21 sep 2026): "que la hormiga los lance como proyectiles hasta la
## ubicación donde desea invocarlos, para tener por lo menos una visual
## como habilidad" (antes aparecía de golpe en su posición final, sin
## ningún indicio visual de que la habilidad hizo algo). NO desaparece al
## llegar -- sigue siendo el mismo huevo de siempre, con su pulso y su
## eclosión normales (ver _iniciar_pulso/_al_terminar_descanso). Solo se
## llama del lado con autoridad real -- _ejecutar() ya está gateada a
## servidor/sin red -- así que el vuelo se replica solo con el mismo
## mecanismo genérico de posición de cualquier mob en movimiento (ver
## Enemigo._physics_process), sin necesidad de un RPC propio.
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
	# Relativo a la escala YA puesta (2.2 del placeholder, o 1.0 si algún
	# día hay arte real sin este ajuste) -- no un valor absoluto fijo, para
	# no pisar el tamaño real de arriba.
	var base := sprite.scale
	var tween := create_tween().set_loops()
	tween.tween_property(sprite, "scale", base * 1.2, 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "scale", base, 0.5).set_trans(Tween.TRANS_SINE)
