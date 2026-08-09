extends Control
class_name PanelTienda
## Se autosuscribe a BusEventos.tienda_solicitada (mismo patrón que
## PanelDialogo con dialogo_solicitado). Se abre desde una opción de
## diálogo con action ABRIR_TIENDA — GestorUI.Modo.DIALOGO ya está activo
## cuando esto pasa (PanelDialogo lo deja así a propósito, ver su
## _elegir_opcion), así que este panel no necesita tocar el modo al abrir,
## solo al cerrar de verdad.

@onready var _lista: VBoxContainer = %Lista
@onready var _texto_creditos: Label = %Creditos
@onready var _boton_salir: Button = %BotonSalir

var _creditos: CreditosComponente = null


func _ready() -> void:
	visible = false
	BusEventos.tienda_solicitada.connect(_abrir)
	_boton_salir.pressed.connect(_cerrar)


func _abrir(datos: DatosTienda) -> void:
	if datos == null:
		return
	_creditos = Utils.creditos_componente_local()
	if _creditos and not _creditos.creditos_cambiados.is_connected(_actualizar_creditos):
		_creditos.creditos_cambiados.connect(_actualizar_creditos)
	visible = true
	_actualizar_creditos(_creditos.obtener_creditos() if _creditos else 0)
	_llenar_lista(datos)


func _llenar_lista(datos: DatosTienda) -> void:
	for hijo in _lista.get_children():
		hijo.queue_free()
	for item_tienda in datos.items_en_venta:
		if item_tienda == null or item_tienda.item == null:
			continue
		var fila := HBoxContainer.new()
		var nombre := Label.new()
		nombre.text = item_tienda.item.name
		nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(nombre)
		var boton := Button.new()
		boton.text = "%d créditos" % item_tienda.precio
		boton.pressed.connect(_comprar.bind(item_tienda))
		fila.add_child(boton)
		_lista.add_child(fila)


func _comprar(item_tienda: ItemTienda) -> void:
	var tienda := Utils.tienda_componente_local()
	if tienda:
		tienda.comprar_item(item_tienda)


func _actualizar_creditos(nuevo: int) -> void:
	_texto_creditos.text = "%d créditos" % nuevo


func _cerrar() -> void:
	visible = false
	GestorUI.cerrar_dialogo()
