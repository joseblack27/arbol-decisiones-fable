class_name HabilidadRebote
extends HabilidadProyectil
## Rebote: dispara un proyectil que, al golpear a un enemigo, sigue de
## largo hacia el enemigo válido más cercano que todavía no haya golpeado
## (dentro de radio_busqueda_rebote), hasta rebotes_maximos veces —
## efectiva contra grupos, ya que casi todo el resto del roster pega a un
## solo blanco (salvo Abanico/Lanzallamas, que cubren área fija en vez de
## perseguir de enemigo en enemigo). Ver ProyectilRebote._al_impactar_de_
## verdad para la lógica del rebote en sí.

@export_group("Rebote")
@export var rebotes_maximos: int = 2
@export var radio_busqueda_rebote: float = 200.0


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Rebote"
	tipo_habilidad   = "rebote"


func _ejecutar(direccion: Vector2, poder: float) -> void:
	var proy := GestorPiscinas.obtener(escena_proyectil) as ProyectilRebote
	proy.global_position = entidad_dueña.global_position
	proy.alcance_base = alcance_maximo
	var poder_efectivo := poder if alcance_segun_poder else 1.0
	proy.configurar(direccion, poder_efectivo, _calcular_dano(int(daño_proyectil)), entidad_dueña, tipo_dano)
	proy.poner_textura_icono(icono_provisional if usar_icono_como_sprite else null)
	proy.preparar_rebotes(rebotes_maximos, radio_busqueda_rebote)
