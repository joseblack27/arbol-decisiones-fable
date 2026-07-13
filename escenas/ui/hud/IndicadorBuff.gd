extends Control
class_name IndicadorBuff
## Ícono chico de UN buff/debuff activo, con un velo que se va achicando a
## medida que se acaba (ProgressBar vertical, fill_mode BOTTOM_TO_TOP — con
## íconos cuadrados un "pastel" circular como el de las habilidades se ve
## raro, ver PieCooldown). Puramente presentacional: no sabe nada de escudo
## ni de ningún efecto puntual, solo dibuja lo que le dicen (ver
## configurar()/actualizar()) — instanciado dinámicamente por BarraBuffs,
## una copia por cada entrada activa en BuffsComponente.
##
## El color del velo distingue buff (oscuro neutro) de debuff (rojizo) —
## ver configurar().

@onready var _icono: TextureRect = %Icono
@onready var _barra_tiempo: ProgressBar = %BarraTiempo

const COLOR_VELO_BUFF := Color(0.0, 0.0, 0.0, 0.6)
const COLOR_VELO_DEBUFF := Color(0.6, 0.05, 0.05, 0.6)


func configurar(icono: Texture2D, es_debuff: bool = false) -> void:
	_icono.texture = icono
	# StyleBoxFlat NUEVO acá (no mutar el que trae el .tscn): esa instancia
	# es un sub_resource compartido entre TODAS las copias de esta escena —
	# tocarlo en el lugar pintaría el velo de todos los indicadores, no
	# solo el de este buff puntual.
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COLOR_VELO_DEBUFF if es_debuff else COLOR_VELO_BUFF
	_barra_tiempo.add_theme_stylebox_override("fill", estilo)


## ratio: 1.0 = recién activado (ícono tapado del todo), 0.0 = a punto de vencer.
func actualizar(ratio: float) -> void:
	_barra_tiempo.value = clampf(ratio, 0.0, 1.0)
