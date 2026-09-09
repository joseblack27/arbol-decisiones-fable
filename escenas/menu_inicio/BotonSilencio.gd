extends Button
## Botón sin texto en la esquina superior derecha del menú de inicio para
## silenciar TODO el audio (efectos + música) de un toque — pedido
## explícito del usuario. Mismo estilo que el resto de los slots de ícono
## del juego (theme_type_variation "RanuraHud", ver BarraConsumibles.tscn):
## fondo oscuro con borde, no un botón plano invisible. Sin ícono de
## imagen: dibuja su propio altavoz en _draw(), 32x32, blanco, y cambia de
## forma según esté silenciado o no — así no hace falta generar/importar
## ningún asset nuevo para esto.

var _silenciado := false
## Volumen de SFX/música justo ANTES de silenciar, para restaurarlo tal
## cual al volver a activar (no a un valor fijo) — si el usuario ya tenía
## el suyo propio ajustado en Configuración, vuelve exactamente a ese.
var _volumen_sfx_previo := Utils.volumen_sfx
var _volumen_musica_previo := Utils.volumen_musica


func _ready() -> void:
	custom_minimum_size = Vector2(40, 40)
	theme_type_variation = &"RanuraHud"
	focus_mode = FOCUS_NONE
	_silenciado = Utils.volumen_sfx <= 0.0 and Utils.volumen_musica <= 0.0
	pressed.connect(_alternar)
	queue_redraw()


func _alternar() -> void:
	_silenciado = not _silenciado
	if _silenciado:
		# Guardar el volumen real solo si no era ya 0 — evita que silenciar
		# dos veces seguidas (sin pasar por "reactivar" en el medio) termine
		# grabando 0.0 como "el volumen de antes".
		if Utils.volumen_sfx > 0.0:
			_volumen_sfx_previo = Utils.volumen_sfx
		if Utils.volumen_musica > 0.0:
			_volumen_musica_previo = Utils.volumen_musica
		Utils.volumen_sfx = 0.0
		Utils.volumen_musica = 0.0
	else:
		Utils.volumen_sfx = _volumen_sfx_previo
		Utils.volumen_musica = _volumen_musica_previo
	GestorSonido.aplicar_volumen()
	GestorMusica.aplicar_volumen()
	Utils.guardar_config()
	queue_redraw()


func _draw() -> void:
	const BLANCO := Color.WHITE
	# Ícono centrado en el botón de 40x40 (dibujado sobre una grilla de 32,
	# desplazada +4 en cada eje). Cuerpo del altavoz (el "driver") + cono
	# que se abre hacia la derecha.
	draw_rect(Rect2(10, 17, 6, 6), BLANCO)
	var cono := PackedVector2Array([
		Vector2(16, 17), Vector2(24, 11), Vector2(24, 29), Vector2(16, 23),
	])
	draw_colored_polygon(cono, BLANCO)
	if _silenciado:
		# Silenciado: una X a la derecha del altavoz, sin ondas de sonido.
		draw_line(Vector2(27, 14), Vector2(33, 26), BLANCO, 2.0, true)
		draw_line(Vector2(33, 14), Vector2(27, 26), BLANCO, 2.0, true)
	else:
		# Con sonido: dos ondas concéntricas a la derecha del altavoz.
		draw_arc(Vector2(24, 20), 5.0, -PI / 3.0, PI / 3.0, 8, BLANCO, 2.0, true)
		draw_arc(Vector2(24, 20), 9.0, -PI / 3.0, PI / 3.0, 8, BLANCO, 2.0, true)
