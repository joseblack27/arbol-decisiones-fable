extends Node
## Registro del interactuable más cercano al jugador LOCAL. Un objeto de
## mundo (Npc, y a futuro cofres/palancas/etc.) se registra al entrar en su
## propio radio de detección y se quita al salir — no necesita saber nada
## del botón de interacción fijo en pantalla (ver BotonInteraccion.gd), que
## a su vez no necesita saber nada de NPCs: solo pide que el objeto
## registrado tenga un método interactuar().
##
## Pila, no un solo valor: si dos interactuables se superponen, salir del
## radio de uno no debe apagar el botón mientras el otro siga cerca —
## siempre se ofrece el último que sigue activo. Guarda el PAR (objeto,
## texto) en cada entrada — no alcanza con guardar solo el objeto y leer
## texto_interaccion de vuelta al volver a uno anterior: no todo
## interactuable tiene por qué exponer esa propiedad exacta.

signal disponible(objeto: Node, texto: String)
signal no_disponible()

var _pila: Array[Dictionary] = []


func registrar(objeto: Node, texto: String = "Interactuar") -> void:
	if _indice_de(objeto) != -1:
		return
	_pila.append({"objeto": objeto, "texto": texto})
	disponible.emit(objeto, texto)


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
## avisar) antes de decidir qué mostrar.
func _refrescar() -> void:
	while not _pila.is_empty() and not is_instance_valid(_pila.back()["objeto"]):
		_pila.pop_back()
	if _pila.is_empty():
		no_disponible.emit()
	else:
		var tope: Dictionary = _pila.back()
		disponible.emit(tope["objeto"], tope["texto"])


func interactuar() -> void:
	_refrescar()
	if _pila.is_empty():
		return
	var objeto: Node = _pila.back()["objeto"]
	if objeto.has_method("interactuar"):
		objeto.interactuar()
