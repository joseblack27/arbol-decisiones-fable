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
# SEÑALES DE HABILIDADES (_on_arañazo_activado vive en Enemigo.gd, compartida)
# =============================================================================

## Arranca el telegrafiado (el árbol de animación tiene IDLE -> MORDIDA_
## PREPARACION -> MORDIDA_DASH -> IDLE ya armado, pero nadie disparaba esas
## 3 condiciones — quedaba viéndose con caminar/idle en vez de su propia
## animación de mordida, con la única transición real siendo "debeCargar",
## que no existe en este árbol (typo/resto viejo, no hacía nada).
func _on_carga_preparacion() -> void:
	componente_animacion.establecer_condicion("parameters/conditions/debeMordidaPrep", true)
	# No alcanza con la condición sola: el grafo solo tiene la arista
	# IDLE->MORDIDA_PREPARACION. Si el lobo todavía está en CAMINAR (lo más
	# común — recién llega al rango y dispara el ataque, movimiento.detener()
	# recién se llama DESPUÉS en AccionAtacar) esa condición no tiene ninguna
	# arista de salida que la escuche desde ahí y se queda pegado mostrando
	# caminar — mismo bug ya encontrado y resuelto para el Arquero (ver
	# HabilidadFlechaArquero._ejecutar). viajar_a_estado() fuerza el viaje
	# pase lo que pase (ver AnimacionComponente).
	componente_animacion.viajar_a_estado("MORDIDA_PREPARACION")


func _on_carga_iniciada(_direccion: Vector2, _multiplicador: float) -> void:
	componente_animacion.establecer_condicion("parameters/conditions/debeMordidaPrep", false)
	componente_animacion.establecer_condicion("parameters/conditions/debeMordidaDash", true)
	componente_animacion.viajar_a_estado("MORDIDA_DASH")


func _on_carga_terminada() -> void:
	memoria.establecer("ataque_en_curso", false)
	componente_animacion.establecer_condicion("parameters/conditions/debeMordidaDash", false)
	componente_animacion.establecer_condicion("parameters/conditions/debeSalirMordida", true)
	componente_animacion.establecer_condicion("parameters/conditions/debeIdle", true)


## Defensivo: reportado en juego real (solo en el servidor multijugador,
## nunca en local/un jugador — no se pudo reproducir con pruebas locales,
## que corren la MISMA HabilidadCarga sin red y siempre completan bien las
## 3 fases) que a veces la embestida se queda fija en la pose de
## preparación para siempre, sin llegar nunca a debeMordidaDash/
## debeSalirMordida (ver _on_carga_iniciada/_on_carga_terminada arriba).
## La sospecha es la réplica visual al cliente (HabilidadBase._reproducir_
## visual_red llama _ejecutar() directo en la copia del cliente, sin pasar
## por el chequeo de recarga de activar()) — pero sin poder reproducirlo
## en un servidor real de prueba, esto no ataca la causa de raíz, solo el
## síntoma: un Arañazo nuevo es la señal más clara de que el lobo YA NO
## sigue en esa embestida vieja, así que fuerza la salida de esa pose
## aunque HabilidadCarga nunca haya avisado que terminó.
func _on_arañazo_activado(habilidad: HabilidadBase) -> void:
	super._on_arañazo_activado(habilidad)
	componente_animacion.establecer_condicion("parameters/conditions/debeMordidaPrep", false)
	componente_animacion.establecer_condicion("parameters/conditions/debeMordidaDash", false)
	componente_animacion.establecer_condicion("parameters/conditions/debeSalirMordida", true)
