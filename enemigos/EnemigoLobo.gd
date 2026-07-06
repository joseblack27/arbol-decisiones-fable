extends Enemigo
class_name EnemigoLobo

# =============================================================================
# 🐺 ENEMIGO LOBO
# Subclase concreta. Tiene arañazo (melee rápido) y carga (dash).
# Las habilidades son activadas directamente por SelectorHabilidades via ruta_nodo.
# Esta clase solo reacciona a las señales de resultado.
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


# =============================================================================
# DATOS — extiende la base para aplicar stats de carga
# =============================================================================

func _aplicar_datos() -> void:
	super._aplicar_datos()
	if not datos:
		return
	# habilidad_carga es @onready, ya está lista cuando se llama desde _ready()
	if habilidad_carga:
		habilidad_carga.daño_carga                    = datos.daño_carga
		habilidad_carga.multiplicador_velocidad_carga = datos.velocidad_carga
		habilidad_carga.distancia_maxima_dash         = datos.distancia_carga
		habilidad_carga.duracion_recarga              = datos.cooldown_carga
