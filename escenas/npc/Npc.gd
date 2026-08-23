extends Area2D
class_name Npc
## NPC base: habla (obligatorio) y opcionalmente vende y/o da/recibe
## misiones. Ver el plan de NPCs para el diseño completo.
##
## Detección de proximidad: mismo criterio que DecoracionOcluible/
## PortalNivel — capa física del CUERPO del jugador (8, fijada en el
## .tscn como collision_mask) + filtro Utils.jugador_local(), para que
## solo reaccione al jugador PROPIO de esta pantalla, no a réplicas de
## otros jugadores visibles en el mapa. Al entrar/salir se registra en
## GestorInteraccion — la lista fija de interacción (ver
## ListaInteraccion.gd) es quien decide mostrarse, este nodo no tiene
## ningún botón propio.

## Id estable para objetivos de misión tipo HABLAR (ver DatosObjetivoMision.
## target_id) — vacío si este NPC no participa de ninguno.
@export var id: String = ""
## Texto que muestra el botón de interacción fijo mientras el jugador está
## cerca de ESTE NPC (ver GestorInteraccion.registrar).
@export var texto_interaccion: String = "Hablar"
## Obligatorio: todo NPC habla.
@export var datos_dialogo: DatosDialogo
## null = este NPC no vende nada.
@export var datos_tienda: DatosTienda = null
## Informativo (a futuro, para un ícono "!" sobre el NPC) — quién decide
## de verdad qué misión acepta/entrega cada opción es OpcionDialogo.
## mision_objetivo, no esta lista.
@export var misiones_ofrecidas: Array[DatosMision] = []

@onready var _label_nombre: Label = %Nombre

var _cuerpos_dentro: int = 0


func _ready() -> void:
	body_entered.connect(_al_entrar_cuerpo)
	body_exited.connect(_al_salir_cuerpo)


func _al_entrar_cuerpo(cuerpo: Node2D) -> void:
	if cuerpo != Utils.jugador_local():
		return
	_cuerpos_dentro += 1
	if _cuerpos_dentro == 1:
		GestorInteraccion.registrar(self, nombre(), acciones_interaccion())


func _al_salir_cuerpo(cuerpo: Node2D) -> void:
	if cuerpo != Utils.jugador_local():
		return
	_cuerpos_dentro = maxi(0, _cuerpos_dentro - 1)
	if _cuerpos_dentro == 0:
		GestorInteraccion.quitar(self)


## Llamado al tocar la acción "Hablar" (ver ListaInteraccion.gd) mientras
## este NPC está en rango.
func interactuar() -> void:
	if datos_dialogo == null:
		return
	BusEventos.dialogo_solicitado.emit(self, datos_dialogo)


## Un solo NPC, una sola acción por ahora (hablar es obligatorio, ver el
## comentario de la clase) — lista de un elemento para calzar con el
## contrato genérico de GestorInteraccion (ver ese archivo).
func acciones_interaccion() -> Array[Dictionary]:
	return [{"texto": texto_interaccion, "callback": interactuar}]


## Nombre visible de este NPC — el mismo texto que ya muestra su cartel
## flotante (Nombre en Npc.tscn), no un campo aparte: así PanelTienda titula
## su columna de mercancía sin que haya dos lugares para mantener el mismo
## nombre sincronizados.
func nombre() -> String:
	return _label_nombre.text
