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
			if tope >= 0 and casillas.size() >= tope:
				break
			if entrada == null or entrada.item == null:
				continue
			if randf() <= entrada.probabilidad:
				casillas.append(entrada.item)
	contenidos[id_cofre] = casillas
	return casillas


## -1 = sin límite (ver DatosCofre.capacidad).
func capacidad(id_cofre: String) -> int:
	var datos: DatosCofre = GestorCofres.obtener_por_id(id_cofre)
	return datos.capacidad if datos else 20


## Agrega [item] si hay lugar bajo la capacidad — false y no hace nada si
## ya está lleno (el llamador decide qué hacer con el ítem en ese caso).
## capacidad -1 (sin límite) nunca rechaza. Bug real reportado: "si paso
## dos veces el mismo recurso [al cofre], se crean 2 slots diferentes
## mientras que en el inventario sí se acumulan" — fusiona en una entrada
## existente del mismo nombre/tipo si hay una (igual que InventarioComponente
## .agregar_item() y que agregar_cantidad() acá abajo); si no hay, recién
## ahí "casillas.append(item)" reusa la referencia tal cual, sin duplicar
## (mismo criterio que GrillaObjetos._transferir para un stack ENTERO).
func agregar(id_cofre: String, item: DatosItem) -> bool:
	var casillas := obtener_contenido(id_cofre)
	if item.type != InventarioComponente.TYPE_EQUIPABLE:
		for existente in casillas:
			# existente != item: [item] YA podría estar en esta misma lista
			# (ej. mutación directa de pruebas, o cualquier llamador que
			# reuse una referencia que ya vive acá) — fusionarlo consigo
			# mismo duplicaría su quantity y se saltearía la capacidad.
			if existente != item and existente.name == item.name and existente.type == item.type:
				existente.quantity += item.quantity
				return true
	var tope := capacidad(id_cofre)
	if tope >= 0 and casillas.size() >= tope:
		return false
	casillas.append(item)
	return true


## Saca [item] de la lista por REFERENCIA (no por índice, igual que
## InventarioComponente.quitar_item) — no-op si no estaba.
func quitar(id_cofre: String, item: DatosItem) -> void:
	var casillas := obtener_contenido(id_cofre)
	casillas.erase(item)


## Agrega "cantidad" unidades de [item] — usado al transferir solo PARTE de
## un stack (ver GrillaObjetos/PopupCantidad, pedido del usuario: "elegir
## cuantos quiero pasar"). A diferencia de agregar(), SIEMPRE duplica el
## ítem antes de guardarlo (nunca reusa la referencia del origen, que
## sigue existiendo con el resto del stack) y fusiona en una entrada
## existente del mismo nombre/tipo si hay una — mismo criterio que
## InventarioComponente.agregar_item().
func agregar_cantidad(id_cofre: String, item: DatosItem, cantidad: int) -> bool:
	if item == null or cantidad <= 0:
		return false
	var casillas := obtener_contenido(id_cofre)
	if item.type != InventarioComponente.TYPE_EQUIPABLE:
		for existente in casillas:
			if existente != item and existente.name == item.name and existente.type == item.type:
				existente.quantity += cantidad
				return true
	var tope := capacidad(id_cofre)
	if tope >= 0 and casillas.size() >= tope:
		return false
	var copia := item.duplicate() as DatosItem
	copia.quantity = cantidad
	copia.id_recurso = item.id_recurso if item.id_recurso != "" else item.resource_path
	casillas.append(copia)
	return true


## Saca "cantidad" unidades de [item] — decrementa quantity y recién saca
## la entrada entera si llega a 0, mismo criterio que InventarioComponente
## .quitar_cantidad(). No-op silencioso si no alcanza tanto como se pide
## (no debería pasar nunca: GrillaObjetos ya valida contra item.quantity
## antes de llamar acá).
func quitar_cantidad(id_cofre: String, item: DatosItem, cantidad: int) -> void:
	if item == null or cantidad <= 0 or item.quantity < cantidad:
		return
	item.quantity -= cantidad
	if item.quantity <= 0:
		obtener_contenido(id_cofre).erase(item)
