extends Button
## Botón sin texto en la esquina superior derecha del menú de inicio para
## silenciar TODO el audio (efectos y música) de un toque. Mismo estilo que los
## slots de ícono del juego (theme_type_variation "RanuraHud", ver
## BarraConsumibles.tscn): fondo oscuro con borde.
##
## Íconos del spritesheet iconos_ui.png (icono_sonido/icono_silenciado,
## asignados en el .tscn, como BotonListaIp), no dibujados con _draw().

## Ícono cuando el sonido está activo (altavoz con ondas).
@export var icono_sonido: Texture2D
## Ícono cuando está silenciado (altavoz con una X).
@export var icono_silenciado: Texture2D

var _silenciado := false
## Volumen de SFX y música justo ANTES de silenciar, para restaurar
## exactamente el que el jugador tenía ajustado en Configuración.
var _volumen_sfx_previo := Utils.volumen_sfx
var _volumen_musica_previo := Utils.volumen_musica


func _ready() -> void:
	custom_minimum_size = Vector2(40, 40)
	theme_type_variation = &"RanuraHud"
	focus_mode = FOCUS_NONE
	_silenciado = Utils.volumen_sfx <= 0.0 and Utils.volumen_musica <= 0.0
	pressed.connect(_alternar)
	_actualizar_icono()


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
	_actualizar_icono()


func _actualizar_icono() -> void:
	icon = icono_silenciado if _silenciado else icono_sonido
