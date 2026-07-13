class_name HabilidadEscudo
extends HabilidadBase
## Activa un escudo temporal (ver EscudoComponente) que reduce o bloquea el
## daño entrante por unos segundos. Self-buff sin dirección: se usa como
## botón tap (requiere_direccion queda en false), no como joystick.

@export_group("Escudo")
@export var duracion_escudo: float = 3.0
## 1.0 = bloquea el 100% del daño mientras dure; 0.5 = lo reduce a la mitad.
@export_range(0.0, 1.0) var reduccion: float = 1.0
## Ícono que muestra BarraBuffs (ver BuffsComponente) mientras el escudo
## está activo. Null = no se anota en BuffsComponente (queda solo el efecto
## real, sin ícono en el HUD) — útil para una variante silenciosa.
@export var icono_buff: Texture2D = null

var _componente_escudo: EscudoComponente = null


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Escudo"
	tipo_habilidad   = "escudo"
	requiere_direccion = false


func _ejecutar(_direccion: Vector2, _poder: float) -> void:
	if not is_instance_valid(entidad_dueña):
		return
	if _componente_escudo == null:
		# Buscarlo primero (ver EscudoComponente.tscn en Jugador.tscn); si la
		# entidad dueña no lo trae de fábrica (p. ej. un mob que use esta
		# misma habilidad sin haberlo agregado a mano), crearlo solo —
		# genérico y reusable sin depender de tocar cada escena.
		_componente_escudo = entidad_dueña.get_node_or_null("EscudoComponente") as EscudoComponente
		if _componente_escudo == null:
			_componente_escudo = EscudoComponente.new()
			_componente_escudo.name = "EscudoComponente"
			entidad_dueña.add_child(_componente_escudo)
	_componente_escudo.activar(duracion_escudo, reduccion)

	if icono_buff != null:
		var buffs := entidad_dueña.get_node_or_null("BuffsComponente") as BuffsComponente
		if buffs == null:
			buffs = BuffsComponente.new()
			buffs.name = "BuffsComponente"
			entidad_dueña.add_child(buffs)
		buffs.agregar("escudo", icono_buff, duracion_escudo, false)
