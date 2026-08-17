extends Control
class_name PanelCofre
## Panel para gestionar el contenido de un cofre del mundo: grilla del
## cofre a la izquierda, detalle del ítem tocado al centro, inventario
## propio a la derecha — se arrastra libremente entre las dos grillas,
## pedido del usuario: "recoger y dejar los objetos del cofre e inventario
## entre ellos". Las dos grillas son GrillaObjetos (ver ese archivo):
## genéricas, sin ninguna lógica de equipar ni reemplazar por tipo — acá
## un arrastre siempre es "sale de una colección, entra a la otra", pedido
## explícito del usuario ("el inventario que se muestra acá no debe tener
## la misma funcionalidad que el inventario del OS").
## Ocupa toda la pantalla para el layout (igual que PanelTienda), pero SIN
## fondo opaco (ver Fondo.color en el .tscn, alpha 0): a diferencia de una
## tienda, acá tiene sentido seguir viendo el mundo (el cofre, el
## personaje) detrás de las grillas — pedido explícito del usuario
## ("quiero ver lo de atras tambien").
## Se autosuscribe a BusEventos.cofre_solicitado (mismo patrón que
## PanelDialogo/PanelTienda) — Cofre.interactuar() la emite y además activa
## GestorUI.Modo.DIALOGO (mismo modo que ya usa PanelTienda: "hay un panel
## modal abierto", bloquea moverse/pelear mientras está abierto).
## Sin header propio (pedido del usuario: "los paneles lleguen hasta
## arriba") — el nombre real del cofre se muestra en GrillaCofre.titulo, y
## cada grilla trae su propio botón de cerrar (GrillaObjetos.
## mostrar_boton_cerrar) que hace lo mismo que el "Salir" de antes.

@onready var _grilla_cofre: GrillaObjetos = %GrillaCofre
@onready var _grilla_jugador: GrillaObjetos = %GrillaJugador

## Columna central de detalle — mismo diseño visual que el detalle de
## PanelInventario (nombre, ícono, tipo/cantidad, descripción,
## características), pedido explícito del usuario, pero SIN los botones de
## acción (Usar/Equipar/Barra rápida/Soltar): acá la única forma de mover
## un ítem es arrastrarlo, esto es solo información.
@onready var _panel_detalle: Panel = %PanelDetalle
@onready var _icono_item: TextureRect = %IconoItem
@onready var _nombre_item: Label = %NombreItem
@onready var _valor_tipo: Label = %ValorTipo
@onready var _valor_cantidad: Label = %ValorCantidad
@onready var _descripcion_item: RichTextLabel = %TextoDescripcion
@onready var _vbox_caracteristicas: VBoxContainer = %VBoxCaracteristicas

var _id_cofre: String = ""


func _ready() -> void:
	visible = false
	BusEventos.cofre_solicitado.connect(_abrir)
	_grilla_cofre.cerrar_solicitado.connect(_cerrar)
	_grilla_jugador.cerrar_solicitado.connect(_cerrar)
	_grilla_cofre.item_tocado.connect(_mostrar_detalle)
	_grilla_jugador.item_tocado.connect(_mostrar_detalle)
	if not BusEventos.item_agregado.is_connected(_al_cambiar_inventario):
		BusEventos.item_agregado.connect(_al_cambiar_inventario)


func _abrir(id_cofre: String, nombre_cofre: String = "Cofre") -> void:
	_id_cofre = id_cofre
	_grilla_cofre.titulo = nombre_cofre
	visible = true
	_limpiar_detalle()

	var cofres := Utils.cofres_componente_local()
	var fuente_cofre := FuenteCofre.new()
	fuente_cofre.cofres = cofres
	fuente_cofre.id_cofre = id_cofre
	_grilla_cofre.poblar(
		func() -> Array: return cofres.obtener_contenido(_id_cofre) if cofres else [],
		fuente_cofre
	)
	_grilla_jugador.poblar(
		func() -> Array:
			var inventario := Utils.inventario_componente_local()
			return inventario.items if inventario else [],
		FuenteInventario.new()
	)


## Pública: quien cambie el inventario desde AFUERA de un arrastre (loot
## recibido mientras el panel está abierto, ver _al_cambiar_inventario) la
## llama para refrescar la columna de la derecha.
func refrescar_inventario() -> void:
	_grilla_jugador.notificar_cambio()


func _al_cambiar_inventario(_item: DatosItem, _cantidad: int) -> void:
	if is_visible_in_tree():
		refrescar_inventario()


## Mismos datos y mismo helper compartido (Utils.llenar_caracteristicas_
## item) que PanelTienda/PanelInventario. modulate (no visible=false): el
## panel central sigue ocupando su lugar fijo en HBoxColumnas — si se lo
## sacara del layout con visible=false, las dos grillas se estirarían a
## llenar el hueco cada vez que se toca/destoca un ítem, mismo criterio
## que PanelTienda._mostrar_detalle/_limpiar_seleccion.
func _mostrar_detalle(item: DatosItem) -> void:
	_panel_detalle.modulate.a = 1.0
	_icono_item.texture = item.icon
	_nombre_item.text = item.name
	_valor_tipo.text = item.type_descripcion
	_valor_cantidad.text = str(item.quantity)
	_descripcion_item.text = item.description
	Utils.llenar_caracteristicas_item(_vbox_caracteristicas, item)


## Pedido del usuario: "si no hay ningun objeto seleccionado, sea invisible
## este panel" — arranca así al abrir el cofre, y vuelve a este estado si
## hiciera falta "deseleccionar" en el futuro (hoy no hay forma de hacerlo,
## solo queda invisible hasta el primer toque).
func _limpiar_detalle() -> void:
	_panel_detalle.modulate.a = 0.0
	_icono_item.texture = null
	_nombre_item.text = "Tocá un ítem para ver los detalles"
	_valor_tipo.text = "-"
	_valor_cantidad.text = "-"
	_descripcion_item.text = ""
	Utils.llenar_caracteristicas_item(_vbox_caracteristicas, null)


func _cerrar() -> void:
	visible = false
	_id_cofre = ""
	GestorUI.cerrar_dialogo()
