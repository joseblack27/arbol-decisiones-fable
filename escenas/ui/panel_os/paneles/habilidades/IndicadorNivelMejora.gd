extends HBoxContainer
class_name IndicadorNivelMejora
## Puntos de progreso del nivel de mejora (ver MejorasComponente): un cuadrito
## relleno por tier comprado y uno apagado por cada uno que falta, para que se
## lea de un vistazo en vez de un texto "2/5".
##
## Cuadrados con ColorRect, como los cuadritos de cada estadística en
## PanelDetalleHabilidad/PanelDetallePasiva (no círculos con _draw(), para no
## mezclar técnicas). Colores del tema (recursos/temas/tema.tres): el dorado
## de la BarraXP y el gris del texto secundario.

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
		# Sin esto, tocar justo sobre un cuadrito no selecciona la fila —
		# mismo bug que el ícono/nombre de ItemHabilidad/ItemPasiva (ver esos
		# .tscn): un Control hijo sin mouse_filter explícito usa STOP por
		# defecto y se traga el toque antes de que llegue al Button padre.
		cuadro.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cuadro)
		_cuadros.append(cuadro)
	_actualizar_cuadros()


func _actualizar_cuadros() -> void:
	for i in _cuadros.size():
		_cuadros[i].color = _COLOR_LLENO if i < tier else _COLOR_VACIO
