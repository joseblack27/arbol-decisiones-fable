class_name HabilidadDisparoLinea
extends HabilidadBase
## Escupitajo: dispara un proyectil rápido en línea recta hacia la
## dirección de activación — sin ningún telégrafo previo (pedido del
## usuario), la dirección queda fijada tal cual estaba al apretar, sin
## reapuntar si el objetivo se movió mientras el disparo viaja.

@export var daño: float = 85.0
@export var escena_proyectil: PackedScene = \
	preload("res://escenas/habilidades/disparo_linea/ProyectilEscupitajoJefe.tscn")


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Escupitajo"
	tipo_habilidad   = "escupitajo_jefe"


func _ejecutar(direccion: Vector2, _poder: float) -> void:
	if not is_instance_valid(entidad_dueña):
		return
	var dir := direccion.normalized() if direccion != Vector2.ZERO else Vector2.RIGHT
	var proy := GestorPiscinas.obtener(escena_proyectil) as Proyectil
	proy.global_position = entidad_dueña.global_position
	proy.configurar(dir, 1.0, daño, entidad_dueña, tipo_dano)
