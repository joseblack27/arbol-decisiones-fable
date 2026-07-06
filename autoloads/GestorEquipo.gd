extends Node
## GestorEquipo.gd — Autoload: qué ítems equipables tiene puesto el jugador
## ahora mismo. PanelInventario (la UI de equipo) es quien manda la lista
## completa cada vez que algo cambia (equipar, quitar, reemplazar) — este
## autoload solo la guarda y avisa por BusEventos a quien le interese
## (típicamente el AtributosComponente del jugador, para recalcular bonos).

var equipados: Array[DatosItem] = []


func actualizar(items: Array[DatosItem]) -> void:
	equipados = items
	BusEventos.equipo_cambiado.emit(equipados)
