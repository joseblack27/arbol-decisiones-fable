extends HBoxContainer
class_name IndicadorNivelMejora
## Puntos de progreso para el nivel de mejora (ver MejorasComponente) — un
## cuadrito relleno por tier ya comprado, uno apagado por el resto.
## Reemplaza el texto plano "2/5" por algo que se lee de un vistazo
## (pedido del usuario: "se ve muy simple, quiero que la persona pueda
## entender todo sin tutorial").
##
## Cuadrados con ColorRect en vez de círculos dibujados a mano con
## _draw() (pedido del usuario, para no mezclar dos técnicas — el resto
## del panel ya usa ColorRect para los cuadritos de cada estadística, ver
## PanelDetalleHabilidad/PanelDetallePasiva). Colores REUSADOS del tema ya
## definido (recursos/temas/tema.tres) — el dorado es el mismo que ya usa
## BarraXP para el progreso de nivel de personaje, y el gris apagado es
## el mismo que ya usa el texto secundario/no-seleccionado — nada de
## acentos nuevos.

const _TAMAÑO := 8.0
const _SEPARACION := 3
const _COLOR_LLENO := Color(0.72, 0.56, 0.08, 1)
const _COLOR_VACIO := Color(0.6666667, 0.6666667, 0.6666667, 1)

@export var tier: int = 0:
	set(valor):
		tier = valor
		_actualizar_cuadros()
@export var max_tier: int = 5:
	set(valor):
		max_tier = maxi(1, valor)
		_reconstruir_cuadros()

var _cuadros: Array[ColorRect] = []


func _ready() -> void:
	add_theme_constant_override("separation", _SEPARACION)
	_reconstruir_cuadros()


## Un ColorRect por tier posible — se reconstruye entera solo cuando
## cambia max_tier (poco frecuente); cambiar tier solo? recolorea, sin
## crear/borrar nodos.
func _reconstruir_cuadros() -> void:
	for hijo in get_children():
		hijo.free()
	_cuadros.clear()
	for i in max_tier:
		var cuadro := ColorRect.new()
		cuadro.custom_minimum_size = Vector2(_TAMAÑO, _TAMAÑO)
		cuadro.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(cuadro)
		_cuadros.append(cuadro)
	_actualizar_cuadros()


func _actualizar_cuadros() -> void:
	for i in _cuadros.size():
		_cuadros[i].color = _COLOR_LLENO if i < tier else _COLOR_VACIO
