extends Enemigo
class_name EnemigoCaballeroEsqueleto

# =============================================================================
# 💀 ENEMIGO CABALLERO ESQUELETO
# Mismo combo de ataque que el Lobo (arañazo cuerpo a cuerpo + carga/dash),
# pero persigue un 20% más rápido — ver EstadoPersigue.multiplicador_velocidad
# en la escena.
#
# Furia: mientras tenga un objetivo, cada _INTERVALO_CHEQUEO_FURIA segundos
# tira una moneda con _PROBABILIDAD_FURIA de activarla — HabilidadFuria
# Guerrero (ver esa clase) es quien sabe QUÉ hace la furia (más veloz, más
# daño, recarga más rápido) y CUÁNTO dura; acá solo se decide CUÁNDO
# intentar activarla. Mientras la furia esté activa no se vuelve a tirar
# la moneda (_habilidad_furia.esta_activa() corta la ventana entera, ni
# siquiera descuenta el temporizador), y recién se reinicia la ventana de
# _INTERVALO_CHEQUEO_FURIA segundos cuando la habilidad avisa que terminó
# (furia_terminada) — pedido explícito del usuario con estas reglas de
# timing exactas.
# =============================================================================

const _INTERVALO_CHEQUEO_FURIA := 10.0
const _PROBABILIDAD_FURIA := 0.10

@onready var ataque_arañazo: HabilidadArañazo = $Habilidades/HabilidadArañazo
@onready var habilidad_carga: HabilidadCarga  = $Habilidades/HabilidadCarga
@onready var _habilidad_furia: HabilidadFuriaGuerrero = $Habilidades/HabilidadFuria

var _tiempo_restante_chequeo_furia: float = _INTERVALO_CHEQUEO_FURIA


func _ready() -> void:
	super._ready()
	ataque_arañazo.habilidad_activada.connect(_on_arañazo_activado)
	habilidad_carga.preparacion_iniciada.connect(_on_carga_preparacion)
	habilidad_carga.carga_iniciada.connect(_on_carga_iniciada)
	habilidad_carga.carga_terminada.connect(_on_carga_terminada)
	_habilidad_furia.furia_terminada.connect(_on_furia_terminada)


func _physics_process(delta: float) -> void:
	# Misma decisión de IA que la cadencia rápida del arquero: solo del lado
	# de la autoridad real (servidor, o un solo jugador) — el cliente puro
	# solo interpola, ver Enemigo._physics_process.
	if not Utils.en_red() or multiplayer.is_server():
		_actualizar_chequeo_furia(delta)
	super._physics_process(delta)


# =============================================================================
# SEÑALES DE HABILIDADES (_on_arañazo_activado vive en Enemigo.gd, compartida)
# =============================================================================

## Este mob no tiene sprites propios de embestida (el AnimationTree solo
## tiene IDLE/CAMINAR — ver investigación del bug "esqueletos sin animación
## durante el dash"): mientras dure ataque_en_curso, Enemigo._aplicar_
## presentacion() deja de tocar debeCaminar/debeIdle, así que sin esto el
## mob quedaba congelado en lo que sea que mostrara justo antes. Pedido del
## usuario: que se vea caminando durante toda la preparación + el dash, ya
## que no hay arte propio para una pose de embestida. viajar_a_estado()
## (no la condición sola) porque el grafo puede no tener arista de salida
## desde el estado en que esté parado el mob en este instante (mismo
## criterio que EnemigoLobo._on_carga_preparacion).
func _on_carga_preparacion() -> void:
	componente_animacion.viajar_a_estado("CAMINAR")


func _on_carga_iniciada(_direccion: Vector2, _multiplicador: float) -> void:
	componente_animacion.viajar_a_estado("CAMINAR")


func _on_carga_terminada() -> void:
	memoria.establecer("ataque_en_curso", false)


# =============================================================================
# FURIA
# =============================================================================

func _actualizar_chequeo_furia(delta: float) -> void:
	if _muerto or _habilidad_furia.esta_activa():
		return
	var objetivo_raw = memoria.obtener("objetivo")
	if not is_instance_valid(objetivo_raw) or not (objetivo_raw is Node2D):
		return
	_tiempo_restante_chequeo_furia -= delta
	if _tiempo_restante_chequeo_furia > 0.0:
		return
	_tiempo_restante_chequeo_furia = _INTERVALO_CHEQUEO_FURIA
	if randf() < _PROBABILIDAD_FURIA:
		_habilidad_furia.activar()


func _on_furia_terminada() -> void:
	_tiempo_restante_chequeo_furia = _INTERVALO_CHEQUEO_FURIA
