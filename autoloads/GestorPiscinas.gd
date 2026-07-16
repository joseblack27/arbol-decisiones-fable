extends Node
## GestorPiscinas (autoload): reutiliza instancias en vez de crearlas y
## destruirlas sin parar (proyectiles, números de daño, futuros efectos).
## Object pooling: crear/destruir nodos todo el rato reserva y libera
## memoria en cada disparo; en su lugar, un nodo "usado" se esconde y se
## guarda para la próxima vez que se necesite uno igual — el coste de
## instanciar solo se paga la primera vez.
##
## USO (reemplaza instantiate()+add_child() ... queue_free()):
##   var nodo = GestorPiscinas.obtener(mi_escena)
##   nodo.configurar(...)          # tu método de siempre
##   ...
##   GestorPiscinas.liberar(nodo)  # en vez de nodo.queue_free()
##
## Cada .tscn tiene su PROPIA piscina (identificada por su ruta): un
## Proyectil y una BolaDeTelaraña nunca se mezclan aunque ambos sean
## "proyectiles". El nodo pooled puede implementar opcionalmente:
##   _al_obtener_de_piscina()   -> se llama al reactivarlo
##   _al_liberar_a_piscina()    -> se llama justo antes de esconderlo

## z_index alto para que los efectos pooled (proyectiles, números de daño)
## siempre se dibujen por encima del terreno/decoración, ya que viven fuera
## del árbol Y-sort de cada nivel (ver nota de diseño más abajo).
const Z_INDEX_EFECTOS := 50

## rutas de escena (String) -> Array[Node] libres para reutilizar.
var _libres: Dictionary = {}
## Nodos actualmente "en uso" (fuera de la piscina), para poder recogerlos
## todos de golpe si el nivel cambia a mitad de vuelo (ver liberar_todos_los_activos).
var _activos: Array[Node] = []

## Nota de diseño: este contenedor NO cuelga de ningún nivel (Mundo →
## ContenedorNivel → NivelX se destruye entero al cambiar de nivel). Si un
## proyectil pooled colgara de un nivel y ese nivel se liberase a mitad de
## vuelo, moriría con él y GestorPiscinas quedaría con una referencia rota.
## Al colgar de este autoload (que vive toda la partida), sobrevive a
## cualquier cambio de nivel sin más que perder su participación en el
## Y-sort de ese nivel — por eso se dibuja con z_index fijo en vez de por Y.
var _contenedor: Node2D


func _ready() -> void:
	_contenedor = Node2D.new()
	_contenedor.name = "InstanciasPiscina"
	_contenedor.z_index = Z_INDEX_EFECTOS
	add_child(_contenedor)


func obtener(escena: PackedScene) -> Node:
	var ruta := escena.resource_path
	var lista: Array = _libres.get(ruta, [])
	var nodo: Node
	if lista.is_empty():
		nodo = escena.instantiate()
		_contenedor.add_child(nodo)
	else:
		nodo = lista.pop_back()

	# set_deferred, NO asignación directa: liberar() apaga process_mode
	# también en diferido — si este mismo nodo se recicla en el MISMO
	# fotograma en que fue liberado (número de daño que termina y otro golpe
	# llega enseguida), el apagado diferido de liberar() caía DESPUÉS de esta
	# reactivación y el nodo quedaba desactivado a mitad de su animación
	# nueva (números congelados/perdidos). En diferido, este encendido se
	# encola después del apagado y gana.
	nodo.set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)
	if nodo is CanvasItem:
		(nodo as CanvasItem).show()
	if nodo.has_method(&"_al_obtener_de_piscina"):
		nodo.call(&"_al_obtener_de_piscina")
	_activos.append(nodo)
	return nodo


func liberar(nodo: Node) -> void:
	if not _activos.has(nodo):
		return  # Ya liberado (evita doble-liberación si dos callbacks coinciden).
	_activos.erase(nodo)

	if nodo.has_method(&"_al_liberar_a_piscina"):
		nodo.call(&"_al_liberar_a_piscina")
	# Diferido: liberar() suele llegar desde callbacks de física (el impacto
	# de un proyectil, p. ej.) y apagar process_mode ahí desactiva el
	# CollisionObject en pleno paso físico — el motor lo prohíbe ("Disabling
	# a CollisionObject node during a physics callback...") y llenaba el log
	# del servidor con ese error por cada impacto.
	nodo.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	if nodo is CanvasItem:
		(nodo as CanvasItem).hide()

	var ruta := nodo.scene_file_path
	if ruta.is_empty():
		# No viene de una PackedScene (creado por código): no se puede
		# devolver a ninguna piscina con garantías; liberar de verdad.
		nodo.queue_free()
		return
	var lista: Array = _libres.get(ruta, [])
	lista.append(nodo)
	_libres[ruta] = lista


## Recoge de golpe todo lo que esté "en vuelo" (proyectiles, números de daño
## a medio animar...). GestorNiveles lo llama justo antes de cambiar de
## nivel: con la pantalla ya en negro por el fundido, nada se nota.
func liberar_todos_los_activos() -> void:
	for nodo in _activos.duplicate():
		liberar(nodo)
