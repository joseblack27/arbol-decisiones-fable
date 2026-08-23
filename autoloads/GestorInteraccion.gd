extends Node
## Registro de TODOS los interactuables cerca del jugador LOCAL. Un objeto
## de mundo (Npc, Cofre, AlmacenLenador, ObjetoRecolectable) se registra al
## entrar en su propio radio de detección y se quita al salir — no necesita
## saber nada del botón/lista de interacción fijo en pantalla (ver
## ListaInteraccion.gd), que a su vez no necesita saber nada de NPCs/cofres/
## árboles: solo consume nombre + acciones().
##
## Pila, no un solo valor: si dos interactuables se superponen, salir del
## radio de uno no debe apagar la lista mientras el otro siga cerca.
## Pedido real del usuario: con dos cofres uno al lado del otro no había
## forma de elegir CUÁL abrir — ofrecer siempre "el último que entró" no
## alcanza. Ahora se transmite la pila COMPLETA en cada cambio; decidir qué
## mostrar (un botón directo, o una lista para elegir) es responsabilidad
## de quien escucha, no de este autoload.

## items: Array[Dictionary], cada entrada {"objeto": Node, "nombre":
## String, "acciones": Array[Dictionary]} — la pila completa, ya podada de
## instancias inválidas. Vacío cuando no hay nada cerca (reemplaza a la
## vieja no_disponible()).
signal cambio(items: Array[Dictionary])

var _pila: Array[Dictionary] = []


## acciones: Array[Dictionary], cada entrada {"texto": String, "callback":
## Callable} — ver el comentario de cada interactuable (Cofre.gd, Npc.gd,
## etc.) para el molde de acciones_interaccion().
func registrar(objeto: Node, nombre: String, acciones: Array[Dictionary]) -> void:
	if _indice_de(objeto) != -1:
		return
	_pila.append({"objeto": objeto, "nombre": nombre, "acciones": acciones})
	cambio.emit(_pila)


func quitar(objeto: Node) -> void:
	var indice := _indice_de(objeto)
	if indice == -1:
		return
	_pila.remove_at(indice)
	_refrescar()


func _indice_de(objeto: Node) -> int:
	for i in _pila.size():
		if _pila[i]["objeto"] == objeto:
			return i
	return -1


## Poda entradas liberadas (p. ej. un interactuable que desaparece sin
## avisar) antes de transmitir el cambio.
func _refrescar() -> void:
	_pila = _pila.filter(func(entrada): return is_instance_valid(entrada["objeto"]))
	cambio.emit(_pila)
