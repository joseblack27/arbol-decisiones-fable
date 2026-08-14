extends Node
class_name CofresComponente
## Contenido de los cofres del MUNDO que este jugador ya visitó — cada
## jugador tiene su PROPIA copia del contenido de un mismo cofre (ver
## Cofre.gd/GestorCofres/PanelCofre), como una caja de guardado personal en
## ese punto del mapa: se puede dejar y sacar ítems libremente, arrastrando
## entre la grilla del cofre y el inventario general.
##
## Lista DENSA por cofre (sin huecos, sin posiciones fijas) — mismo
## criterio que InventarioComponente: DatosCofre.capacidad es un TOPE de
## cuántos ítems puede haber a la vez, no una grilla de casillas fijas.
## Pedido del usuario: "no quiero slots precreados" — se agrega/saca por
## ÍTEM, nunca por índice (ver ScrollContainerObjetos._drop_data, el único
## lugar que llama agregar()/quitar() acá).
##
## Mutación SIN RPC — mismo nivel de confianza que InventarioComponente/
## EquipoSlot (ver esos comentarios): mover un ítem entre el cofre propio y
## el inventario propio no es distinto de equipar o soltar algo, no hace
## falta que el servidor valide cada arrastre.

## id_cofre -> Array[DatosItem] — la PRIMERA vez que se pide el contenido
## de un id nunca antes visitado, se arma sembrado con el botín inicial de
## esa definición (ver obtener_contenido()); de ahí en más es lo que el
## jugador haya dejado o sacado, nunca se vuelve a sortear.
var contenidos: Dictionary = {}


## Contenido de este cofre PARA ESTE JUGADOR — lo arma la primera vez que
## se pide (sembrado con el botín inicial, respetando la probabilidad de
## cada entrada Y la capacidad); después siempre devuelve la MISMA
## referencia, mutable en el lugar por agregar()/quitar().
func obtener_contenido(id_cofre: String) -> Array[DatosItem]:
	if contenidos.has(id_cofre):
		return contenidos[id_cofre]
	var datos: DatosCofre = GestorCofres.obtener_por_id(id_cofre)
	var tope := capacidad(id_cofre)
	var casillas: Array[DatosItem] = []
	if datos:
		for entrada in datos.tabla_botin:
			if casillas.size() >= tope:
				break
			if entrada == null or entrada.item == null:
				continue
			if randf() <= entrada.probabilidad:
				casillas.append(entrada.item)
	contenidos[id_cofre] = casillas
	return casillas


func capacidad(id_cofre: String) -> int:
	var datos: DatosCofre = GestorCofres.obtener_por_id(id_cofre)
	return datos.capacidad if datos else 20


## Agrega [item] si hay lugar bajo la capacidad — false y no hace nada si
## ya está lleno (el llamador decide qué hacer con el ítem en ese caso).
func agregar(id_cofre: String, item: DatosItem) -> bool:
	var casillas := obtener_contenido(id_cofre)
	if casillas.size() >= capacidad(id_cofre):
		return false
	casillas.append(item)
	return true


## Saca [item] de la lista por REFERENCIA (no por índice, igual que
## InventarioComponente.quitar_item) — no-op si no estaba.
func quitar(id_cofre: String, item: DatosItem) -> void:
	var casillas := obtener_contenido(id_cofre)
	casillas.erase(item)
