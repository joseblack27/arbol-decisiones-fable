extends Node
## GestorBarraRapida (autoload) — fuente de verdad de qué ítem hay en cada
## una de las 4 casillas rápidas de consumibles. Existen DOS vistas de estas
## mismas 4 casillas: la barra flotante del HUD (BarraConsumibles.tscn,
## siempre presente durante el juego) y una fila dentro de PanelInventario
## (para poder arrastrar un ítem ahí con el inventario abierto, ya que la
## barra del HUD queda tapada por ese panel). Cada SlotConsumibleRapido solo
## dibuja lo que hay en su índice acá — nunca guarda su propio estado — así
## las dos vistas quedan sincronizadas solas vía casilla_cambiada.
##
## Es puramente una preferencia de UI del cliente (qué ítem puso el jugador
## en qué casilla): no necesita replicarse por red ni tener autoridad de
## servidor — usar el ítem sigue pasando por GestorInventario.usar_item(),
## que sí es servidor-autoritativo (ver InventarioComponente.gd).

signal casilla_cambiada(indice: int)

const CANTIDAD_CASILLAS := 4

var casillas: Array[DatosItem] = [null, null, null, null]


func _ready() -> void:
	# Lootear MÁS unidades de un consumible ya puesto en una casilla sube el
	# quantity del MISMO DatosItem que la casilla referencia — pero nadie
	# redibujaba su etiqueta de cantidad hasta el próximo casilla_cambiada
	# (reportado: "consigues más en el inventario y el valor no se
	# actualiza"). Escuchar el loot acá refresca ambas vistas de una.
	# Diferido: BusEventos se declara antes que este autoload, pero por las
	# dudas del orden se conecta al primer fotograma (mismo criterio que
	# GestorGuardado._conectar_eventos_guardado).
	(func():
		BusEventos.item_agregado.connect(_al_agregar_item)
	).call_deferred()


func _al_agregar_item(item: DatosItem, _cantidad: int) -> void:
	for i in casillas.size():
		if casillas[i] == item:
			refrescar(i)


func asignar(indice: int, item: DatosItem) -> void:
	if indice < 0 or indice >= CANTIDAD_CASILLAS:
		return
	casillas[indice] = item
	casilla_cambiada.emit(indice)


func limpiar(indice: int) -> void:
	asignar(indice, null)


## Avisa a ambas vistas que refresquen su casilla "indice" aunque el ítem
## que contiene siga siendo el mismo objeto (p. ej. tras usarlo y que su
## quantity haya cambiado, pero sin vaciarse del todo).
func refrescar(indice: int) -> void:
	casilla_cambiada.emit(indice)


func primer_indice_vacio() -> int:
	for i in casillas.size():
		if casillas[i] == null:
			return i
	return -1
