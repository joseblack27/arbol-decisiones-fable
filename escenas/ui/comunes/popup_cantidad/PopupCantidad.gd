extends Control
class_name PopupCantidad
## Confirmación de cuántas unidades transferir de un ítem apilado — pedido
## del usuario: "cuando se este arrastrando un objeto con mas de 1 cantidad,
## aparezca y me deje elegir cuantos quiero pasar" (ver mockup: título,
## fila -/valor/+, fila MIN/MAX, fila Cancelar/Aceptar). GrillaObjetos la
## instancia (ver GrillaObjetos.tscn) y la abre desde recibir_desde() en vez
## de mover el stack entero de una.
##
## top_level = true (ver .tscn): vive como hija de GrillaObjetos (un Panel
## chico, 265px) pero se dibuja en coordenadas de VIEWPORT completo,
## centrada en pantalla — igual que GrillaObjetos, no le importa dónde la
## use quien la instancia.

signal confirmada(cantidad: int)
signal cancelada

@onready var _valor_input: LineEdit = %ValorInput
@onready var _boton_menos: Button = %BotonMenos
@onready var _boton_mas: Button = %BotonMas
@onready var _boton_min: Button = %BotonMin
@onready var _boton_max: Button = %BotonMax
@onready var _boton_cancelar: Button = %BotonCancelar
@onready var _boton_aceptar: Button = %BotonAceptar

var _cantidad: int = 1
var _maximo: int = 1


func _ready() -> void:
	visible = false
	_boton_menos.pressed.connect(func(): _fijar(_cantidad - 1))
	_boton_mas.pressed.connect(func(): _fijar(_cantidad + 1))
	_boton_min.pressed.connect(func(): _fijar(1))
	_boton_max.pressed.connect(func(): _fijar(_maximo))
	_boton_cancelar.pressed.connect(_cancelar)
	_boton_aceptar.pressed.connect(_aceptar)
	_valor_input.text_submitted.connect(func(_texto): _fijar_desde_texto())
	_valor_input.focus_exited.connect(_fijar_desde_texto)


## Pública: [maximo] es el tamaño real del stack que se está arrastrando
## (item.quantity) — arranca en el máximo, mover el stack entero es el caso
## más común y "-"/MIN quedan a mano para partirlo.
func abrir(maximo: int) -> void:
	_maximo = maxi(maximo, 1)
	_fijar(_maximo)
	visible = true


func _fijar(valor: int) -> void:
	_cantidad = clampi(valor, 1, _maximo)
	_valor_input.text = str(_cantidad)


## Pedido del usuario: "que sea un cuadro de texto donde si se desea se
## coloque el numero manualmente" — se llama al confirmar con Enter
## (text_submitted) o al tocar afuera del campo (focus_exited). to_int()
## devuelve 0 para texto vacío o no numérico, que _fijar() ya recorta a 1.
func _fijar_desde_texto() -> void:
	_fijar(_valor_input.text.to_int())


func _cancelar() -> void:
	visible = false
	cancelada.emit()


func _aceptar() -> void:
	visible = false
	confirmada.emit(_cantidad)
