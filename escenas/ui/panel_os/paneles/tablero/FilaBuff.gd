extends HBoxContainer
class_name FilaBuff
## Una fila del panel "Buffs Activos" (ver PanelTablero): ícono, nombre,
## descripción y tiempo restante de UN buff/debuff activo del jugador —
## instanciada dinámicamente, una por cada entrada de BuffsComponente.
## Mismo dato de origen que BarraBuffs/IndicadorBuff (el ícono chico del
## HUD), pero con más detalle para este panel.

@onready var _icono: TextureRect = %Icono
@onready var _nombre: Label = %Nombre
@onready var _descripcion: Label = %Descripcion
@onready var _tiempo: Label = %Tiempo

const COLOR_DEBUFF := Color(1.0, 0.55, 0.55, 1.0)
const COLOR_BUFF := Color(0.75, 0.95, 0.75, 1.0)


func configurar(icono: Texture2D, nombre: String, descripcion: String, es_debuff: bool) -> void:
	_icono.texture = icono
	_nombre.text = nombre if nombre != "" else "Buff"
	_nombre.add_theme_color_override("font_color", COLOR_DEBUFF if es_debuff else COLOR_BUFF)
	_descripcion.text = descripcion
	_descripcion.visible = descripcion != ""


func actualizar_tiempo(segundos_restantes: float) -> void:
	_tiempo.text = "%ds" % maxi(0, int(ceil(segundos_restantes)))
