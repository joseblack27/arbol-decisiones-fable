extends StaticBody2D
class_name AlmacenLenador
## Almacén compartido donde el leñador deja la madera (ver Lenador.gd y
## GestorLenador.gd). A diferencia de Cofre.gd (contenido POR JUGADOR, sin
## validar), es un pozo ÚNICO para todos, validado por el servidor. Mismo
## patrón de proximidad + GestorInteraccion que Cofre.gd, pero sin "id": hay
## una sola instancia.

## Para la lista de objetos cuando hay otro interactuable superpuesto cerca
## (ver GestorInteraccion) — no hace falta un título de panel aparte como
## Cofre.nombre, esto ya cumple las dos cosas.
@export var nombre: String = "Almacén del Leñador"
@export var texto_interaccion: String = "Abrir"
@export var area_interaccion: Area2D

const CAPA_CUERPO_JUGADOR := 8
## Radio (escalado) de area_interaccion, derivado solo, como
## ObjetoRecolectable.radio_interaccion_servidor. El leñador (Lenador.gd,
## estado YENDO_AL_ALMACEN) lo usa para saber que llegó, en vez de caminar
## hasta el origen del nodo, que puede quedar pegado a la colisión SÓLIDA del
## mueble donde el agente de navegación nunca converge.
var radio_interaccion: float = 64.0

var _cuerpos_dentro: int = 0


func _ready() -> void:
	if area_interaccion:
		area_interaccion.collision_mask = CAPA_CUERPO_JUGADOR
		area_interaccion.body_entered.connect(_al_entrar_cuerpo)
		area_interaccion.body_exited.connect(_al_salir_cuerpo)
		for hijo in area_interaccion.get_children():
			if hijo is CollisionShape2D and hijo.shape is CircleShape2D:
				radio_interaccion = hijo.shape.radius * area_interaccion.global_scale.x
				break


func _al_entrar_cuerpo(cuerpo: Node2D) -> void:
	if cuerpo != Utils.jugador_local():
		return
	_cuerpos_dentro += 1
	if _cuerpos_dentro == 1:
		GestorInteraccion.registrar(self, nombre, acciones_interaccion())


func _al_salir_cuerpo(cuerpo: Node2D) -> void:
	if cuerpo != Utils.jugador_local():
		return
	_cuerpos_dentro = maxi(0, _cuerpos_dentro - 1)
	if _cuerpos_dentro == 0:
		GestorInteraccion.quitar(self)


func interactuar() -> void:
	GestorUI.abrir_dialogo()
	BusEventos.almacen_lenador_solicitado.emit()


func acciones_interaccion() -> Array[Dictionary]:
	return [{"texto": texto_interaccion, "callback": interactuar}]
