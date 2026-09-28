extends Node2D
class_name IndicadorZonaEfecto
## Flash visual puro (sin física ni daño) que muestra el radio real de una
## habilidad de área instantánea justo al activarse. Mismo estilo que
## AreaEfecto._draw() (Onda de Choque, Golpe Vampírico): círculo relleno
## translúcido con borde marcado.
##
## Para las habilidades que NO pasan por AreaEfecto porque hacen su propia
## consulta de física (Sacudida, la detonación de Acumulación): sin esto,
## aplicaban su efecto sin nada visible que confirmara dónde ni hasta dónde.
##
## Se posiciona en el punto de activación y NO sigue a nadie: es una foto del
## momento, como OndaChoque y AreaEfecto.

@export var radio: float = 60.0
@export var color_relleno: Color = Color(0.6, 0.7, 1.0, 0.35)
@export var color_borde: Color = Color(0.65, 0.75, 1.0, 0.9)
@export var duracion: float = 0.35
## Si tiene puntos, se dibuja ESTE polígono (en coordenadas locales, ya
## rotado por quien lo arma) en vez del círculo de "radio" — para
## habilidades cuya zona real no es circular, como el rectángulo alargado
## de HabilidadCorte. Vacío (por defecto) = círculo de siempre.
@export var poligono: PackedVector2Array = PackedVector2Array()

var _tiempo: float = 0.0


func _ready() -> void:
	queue_redraw()


func _process(delta: float) -> void:
	_tiempo += delta
	if _tiempo >= duracion:
		queue_free()


func _draw() -> void:
	if not poligono.is_empty():
		draw_colored_polygon(poligono, color_relleno)
		# closed=true: el borde tiene que cerrar el rectángulo, si no queda
		# un lado abierto entre el último punto y el primero.
		draw_polyline(poligono + PackedVector2Array([poligono[0]]), color_borde, 2.0)
		return
	draw_circle(Vector2.ZERO, radio, color_relleno)
	draw_arc(Vector2.ZERO, radio, 0.0, TAU, 32, color_borde, 2.0)
