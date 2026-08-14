extends StaticBody2D
class_name Cofre
## Cofre estático del mundo — abre PanelCofre para gestionar su contenido
## (ver ese archivo/CofresComponente): cada jugador tiene su PROPIA copia
## del contenido de un mismo cofre, se deja y se saca libremente
## arrastrando entre esa grilla y el inventario propio. Basado en
## DecoracionOcluible (StaticBody2D quieto + visual + CollisionShape2D
## sólida) pero con proximidad + registro en GestorInteraccion en vez de
## oclusión — mismo patrón que Npc.gd.

## Debe coincidir con el DatosCofre.id correspondiente en
## GestorCofres.catalogo — así CofresComponente sabe qué contenido inicial
## sembrar y bajo qué clave guardar lo que el jugador deje/saque.
@export var id: String = ""
## Título del panel al abrirlo (ver DatosCofre.nombre).
@export var nombre: String = "Cofre"
## Texto que muestra el botón de interacción fijo mientras el jugador está
## cerca (ver GestorInteraccion.registrar).
@export var texto_interaccion: String = "Abrir"
## Área cuya proximidad activa el botón de interacción.
@export var area_interaccion: Area2D

## Capa física del CUERPO del jugador (ver Jugador.tscn, collision_layer=8)
## — mismo criterio que DecoracionOcluible/Npc.
const CAPA_CUERPO_JUGADOR := 8

var _cuerpos_dentro: int = 0


func _ready() -> void:
	if area_interaccion:
		area_interaccion.collision_mask = CAPA_CUERPO_JUGADOR
		area_interaccion.body_entered.connect(_al_entrar_cuerpo)
		area_interaccion.body_exited.connect(_al_salir_cuerpo)


func _al_entrar_cuerpo(cuerpo: Node2D) -> void:
	if cuerpo != Utils.jugador_local():
		return
	_cuerpos_dentro += 1
	if _cuerpos_dentro == 1:
		GestorInteraccion.registrar(self, texto_interaccion)


func _al_salir_cuerpo(cuerpo: Node2D) -> void:
	if cuerpo != Utils.jugador_local():
		return
	_cuerpos_dentro = maxi(0, _cuerpos_dentro - 1)
	if _cuerpos_dentro == 0:
		GestorInteraccion.quitar(self)


## Llamado por GestorInteraccion.interactuar() al presionar el botón fijo
## de interacción mientras este cofre es el interactuable activo. Mismo
## modo que PanelTienda (GestorUI.Modo.DIALOGO: "hay un panel modal
## abierto", bloquea moverse/pelear) — a diferencia de la tienda (que
## siempre se abre DESDE un diálogo, con el modo ya activo), acá hace
## falta activarlo acá mismo.
func interactuar() -> void:
	GestorUI.abrir_dialogo()
	BusEventos.cofre_solicitado.emit(id, nombre)
