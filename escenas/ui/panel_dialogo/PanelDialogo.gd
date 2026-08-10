extends Control
class_name PanelDialogo
## Se autosuscribe a BusEventos.dialogo_solicitado (mismo patrón que
## PanelInventario con el resto del bus) — el NPC no necesita ninguna
## referencia directa a este panel. Mientras está abierto, GestorUI.Modo.
## DIALOGO bloquea el resto del juego (ver ControlJuego.gd).
##
## A propósito NUNCA se toca "visible" acá (ver _ready/_abrir/_ocultar):
## un Control oculto con visible=false deja de recibir notificaciones de
## layout, y Texto (autowrap) necesita conocer su ancho real para medir
## cuántas líneas ocupa. Al volver a mostrarlo con visible=true, esa
## primera medición se hace "en frío" (comprobado a mano: el mismo texto
## midió 197px y 20px de alto entre dos aperturas seguidas, sin que nada
## lo pidiera) y Fondo — anclado abajo, ver PanelDialogo.tscn — terminaba
## con otro tamaño/posición cada vez que se reabría el mismo diálogo. En
## vez de forzar un tamaño fijo, se evita apagar el layout: el panel
## queda SIEMPRE en el árbol activo (Texto sigue midiéndose cada
## fotograma, con o sin diálogo abierto) y solo se oculta visualmente
## (modulate) y se desactiva como blanco de toques (mouse_filter).

@onready var _speaker: Label = %Speaker
@onready var _texto: Label = %Texto
@onready var _opciones_vbox: VBoxContainer = %Opciones
@onready var _boton_continuar: Button = %BotonContinuar
@onready var _fondo: PanelContainer = $Fondo

const _ICONOS_CATEGORIA := {
	Enums.Dialogo.CategoriaOpcion.MISION: preload("res://assets/iconos/buttons/dialogo/dialogo_mision_aceptable.png"),
	Enums.Dialogo.CategoriaOpcion.MISION_HABLAR: preload("res://assets/iconos/buttons/dialogo/dialogo_mision_hablar.png"),
	Enums.Dialogo.CategoriaOpcion.MERCADO: preload("res://assets/iconos/buttons/dialogo/dialogo_intercambio.png"),
	Enums.Dialogo.CategoriaOpcion.HABLAR: preload("res://assets/iconos/buttons/dialogo/dialogo_hablar.png"),
	Enums.Dialogo.CategoriaOpcion.VOLVER: preload("res://assets/iconos/buttons/dialogo/dialogo_volver.png"),
	Enums.Dialogo.CategoriaOpcion.ACEPTAR: preload("res://assets/iconos/buttons/dialogo/dialogo_aceptar.png"),
}

var _datos: DatosDialogo = null
var _npc: Node = null
var _indice: int = 0


func _ready() -> void:
	modulate.a = 0.0
	_fondo.mouse_filter = MOUSE_FILTER_IGNORE
	BusEventos.dialogo_solicitado.connect(_abrir)
	_boton_continuar.pressed.connect(_avanzar)


func _abrir(npc: Node, datos: DatosDialogo) -> void:
	if datos == null or datos.lineas.is_empty():
		return
	_npc = npc
	_datos = datos
	_indice = 0
	modulate.a = 1.0
	_fondo.mouse_filter = MOUSE_FILTER_STOP
	GestorUI.abrir_dialogo()
	_mostrar_linea()


func _mostrar_linea() -> void:
	if _indice < 0 or _indice >= _datos.lineas.size():
		_cerrar()
		return
	var linea: LineaDialogo = _datos.lineas[_indice]
	_speaker.text = linea.hablante
	_texto.text = linea.texto
	_limpiar_opciones()
	var opciones_visibles := linea.opciones.filter(_opcion_visible)
	if opciones_visibles.is_empty():
		# También cubre el caso "todas las opciones tenían condición y
		# ninguna aplica ahora mismo" — sin este respaldo, la línea se
		# quedaría sin ningún botón, un diálogo sin salida.
		_boton_continuar.visible = true
		_opciones_vbox.visible = false
	else:
		_opciones_vbox.visible = true
		_boton_continuar.visible = false
		for opcion in opciones_visibles:
			var boton := Button.new()
			boton.custom_minimum_size = Vector2(0, 32)
			boton.text = opcion.texto
			boton.icon = _ICONOS_CATEGORIA.get(opcion.categoria)
			boton.alignment = HORIZONTAL_ALIGNMENT_LEFT
			boton.pressed.connect(_elegir_opcion.bind(opcion))
			_opciones_vbox.add_child(boton)


## Filtro de OpcionDialogo.condicion/mision_condicion — una opción puede
## depender del estado de una misión sin ser ella misma quien la acepta/
## entrega (ver el export de condicion en OpcionDialogo.gd). Pedido
## explícito del usuario: "ya me encargué de los lobos" no debería
## ofrecerse antes de aceptar la misión ni mientras sigue en curso, solo
## cuando los objetivos ya están cumplidos.
func _opcion_visible(opcion: OpcionDialogo) -> bool:
	if opcion.condicion == Enums.Dialogo.CondicionMision.SIEMPRE or opcion.mision_condicion == null:
		return true
	var misiones := Utils.misiones_componente_local()
	if misiones == null:
		return true
	var id_mision := opcion.mision_condicion.id
	var estado := misiones.estado_de(id_mision)
	match opcion.condicion:
		Enums.Dialogo.CondicionMision.NO_ACEPTADA:
			return estado == Enums.Mision.Estado.BLOQUEADA or estado == Enums.Mision.Estado.DISPONIBLE
		Enums.Dialogo.CondicionMision.EN_PROGRESO:
			return estado == Enums.Mision.Estado.EN_PROGRESO and not misiones.objetivos_completos(id_mision)
		Enums.Dialogo.CondicionMision.LISTA_PARA_ENTREGAR:
			return estado == Enums.Mision.Estado.EN_PROGRESO and misiones.objetivos_completos(id_mision)
		Enums.Dialogo.CondicionMision.COMPLETADA:
			return estado == Enums.Mision.Estado.COMPLETADA
	return true


func _avanzar() -> void:
	var actual: LineaDialogo = _datos.lineas[_indice] if _indice >= 0 and _indice < _datos.lineas.size() else null
	if actual and actual.siguiente_linea >= 0:
		_indice = actual.siguiente_linea
	else:
		_indice += 1
	_mostrar_linea()


func _elegir_opcion(opcion: OpcionDialogo) -> void:
	_ejecutar_accion(opcion)
	if opcion.accion == Enums.Dialogo.Accion.ABRIR_TIENDA:
		# El modo DIALOGO queda activo a propósito — PanelTienda sigue
		# bloqueando el juego con el mismo modo, no hace falta pasar por
		# JUEGO en el medio. Ver _ocultar() vs. _cerrar().
		_ocultar()
	elif opcion.accion == Enums.Dialogo.Accion.CERRAR or opcion.siguiente_linea < 0:
		_cerrar()
	else:
		_indice = opcion.siguiente_linea
		_mostrar_linea()


## Efectos secundarios de una opción — la decisión de cerrar o avanzar
## vive en _elegir_opcion, esto solo dispara el efecto.
func _ejecutar_accion(opcion: OpcionDialogo) -> void:
	match opcion.accion:
		Enums.Dialogo.Accion.ABRIR_TIENDA:
			# El diálogo se cierra (ver _elegir_opcion) — comprar pasa a ser
			# su propia interacción, ya no hace falta seguir hablando.
			if _npc and "datos_tienda" in _npc and _npc.datos_tienda:
				var nombre_comerciante: String = _npc.nombre() if _npc.has_method("nombre") else "Comerciante"
				BusEventos.tienda_solicitada.emit(_npc.datos_tienda, nombre_comerciante)
		Enums.Dialogo.Accion.ACEPTAR_MISION:
			if opcion.mision_objetivo:
				Utils.misiones_componente_local().aceptar_mision(opcion.mision_objetivo)
		Enums.Dialogo.Accion.ENTREGAR_MISION:
			if opcion.mision_objetivo:
				Utils.misiones_componente_local().completar_mision(opcion.mision_objetivo)
		Enums.Dialogo.Accion.NINGUNA, Enums.Dialogo.Accion.CERRAR:
			pass


## remove_child() inmediato + queue_free() diferido — no alcanza con
## queue_free() solo: _mostrar_linea() puede llamarse más de una vez dentro
## del mismo fotograma, y los hijos siguen en el árbol hasta el final del
## fotograma, así que se acumulaban en vez de reemplazarse. Pero tampoco
## alcanza con .free() solo: cuando esto corre porque el jugador tocó una
## de estas mismas opciones (_elegir_opcion → _mostrar_linea, misma pila),
## el botón tocado todavía está "locked" por su propia señal pressed en
## emisión, y Godot rechaza liberarlo ("Object is locked and can't be
## freed"). remove_child() sí es seguro en ese momento (solo desvincula,
## no destruye) y deja al hijo fuera de get_children() de inmediato.
func _limpiar_opciones() -> void:
	for hijo in _opciones_vbox.get_children():
		_opciones_vbox.remove_child(hijo)
		hijo.queue_free()


func _ocultar() -> void:
	modulate.a = 0.0
	_fondo.mouse_filter = MOUSE_FILTER_IGNORE
	_boton_continuar.visible = false
	_limpiar_opciones()
	_npc = null
	_datos = null


func _cerrar() -> void:
	_ocultar()
	GestorUI.cerrar_dialogo()
