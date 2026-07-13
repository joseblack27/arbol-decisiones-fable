extends Enemigo
class_name EnemigoCaballeroEsqueleto

# =============================================================================
# 💀 ENEMIGO CABALLERO ESQUELETO
# Mismo combo de ataque que el Lobo (arañazo cuerpo a cuerpo + carga/dash),
# pero persigue un 20% más rápido — ver EstadoPersigue.multiplicador_velocidad
# en la escena.
# =============================================================================

@onready var ataque_arañazo: HabilidadArañazo = $Habilidades/HabilidadArañazo
@onready var habilidad_carga: HabilidadCarga  = $Habilidades/HabilidadCarga


func _ready() -> void:
	super._ready()
	ataque_arañazo.habilidad_activada.connect(_on_arañazo_activado)
	habilidad_carga.preparacion_iniciada.connect(_on_carga_preparacion)
	habilidad_carga.carga_iniciada.connect(_on_carga_iniciada)
	habilidad_carga.carga_terminada.connect(_on_carga_terminada)


# =============================================================================
# SEÑALES DE HABILIDADES
# =============================================================================

## El daño ya lo aplica Arañazo.gd internamente — aquí solo notificamos al BT.
func _on_arañazo_activado(_habilidad: HabilidadBase) -> void:
	componente_animacion.establecer_condicion("parameters/conditions/debeIdle", true)
	memoria.establecer("habilidad_lanzada", true)


func _on_carga_preparacion() -> void:
	pass


func _on_carga_iniciada(_direccion: Vector2, _multiplicador: float) -> void:
	pass


func _on_carga_terminada() -> void:
	memoria.establecer("ataque_en_curso", false)
	componente_animacion.establecer_condicion("parameters/conditions/debeCargar", false)
