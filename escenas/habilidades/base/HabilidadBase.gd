class_name HabilidadBase
extends Node

## Píxeles por metro — factor de conversión para alcance_metros → píxeles.
const ESCALA_METROS_PIXEL := 40.0
## Clase base abstracta para todas las habilidades.
## Gestiona el ciclo de vida de la recarga y provee una interfaz de activación uniforme.
## Para añadir una nueva habilidad: extender esta clase y sobreescribir _ejecutar().
##
## entidad_dueña es asignada externamente por SlotHabilidades antes de add_child.

## Emitida al activar la habilidad.
signal habilidad_activada(habilidad: HabilidadBase)
## Emitida al terminar la recarga.
signal recarga_terminada(habilidad: HabilidadBase)

@export var nombre_habilidad: String = "Habilidad"
## Identificador usado en BusEventos para distinguir habilidades.
@export var tipo_habilidad: String = "base"
@export var duracion_recarga: float = 1.0
## Energía consumida al activar. 0 = gratis.
@export var costo_energia: float = 0.0
## Si true, el control UI se adapta a modo joystick (direccional).
## Si false, se usa como botón tap.
@export var requiere_direccion: bool = false
## Tipo de daño que inflige esta habilidad. Afecta las resistencias del defensor.
@export var tipo_dano: Enums.Skill.TypeDamage = Enums.Skill.TypeDamage.PHYSIC

## Entidad a la que pertenece esta habilidad (asignada automáticamente en _ready).
var entidad_dueña: Node = null
## Índice del slot donde está equipada. -1 si no está en ningún slot (ej: enemigos).
var slot_index: int = -1

var _recarga_restante: float = 0.0
## Rango de daño cargado desde DatosHabilidad. 0,0 = usar valor por defecto de la subclase.
var _dano_min: int = 0
var _dano_max: int = 0

func _ready() -> void:
	# Fallback para habilidades que no pasan por SlotHabilidades (ej: enemigos).
	# SlotHabilidades asigna entidad_dueña antes de add_child, así que aquí
	# solo entra cuando aún está en null (jerarquía clásica: hab → contenedor → entidad).
	if entidad_dueña == null and get_parent() != null:
		entidad_dueña = get_parent().get_parent()

func _process(delta: float) -> void:
	if _recarga_restante > 0.0:
		_recarga_restante -= delta
		if _recarga_restante <= 0.0:
			_recarga_restante = 0.0
			recarga_terminada.emit(self)
			BusEventos.recarga_terminada.emit(entidad_dueña, slot_index)

# ── API Pública ───────────────────────────────────────────────────────────────

## Devuelve true si la habilidad no está en recarga.
func puede_usarse() -> bool:
	return _recarga_restante <= 0.0

## Devuelve la proporción de recarga restante (0.0 = lista, 1.0 = recién usada).
func obtener_ratio_recarga() -> float:
	if duracion_recarga <= 0.0:
		return 0.0
	return clampf(_recarga_restante / duracion_recarga, 0.0, 1.0)

## Devuelve los segundos restantes de recarga.
func obtener_recarga_restante() -> float:
	return maxf(0.0, _recarga_restante)

## Activa la habilidad en la dirección dada con la potencia indicada.
## direccion — vector normalizado (joystick o dirección del agente).
## poder     — valor 0..1 para escalar distancia/alcance.
func activar(direccion: Vector2 = Vector2.ZERO, poder: float = 1.0) -> void:
	if not puede_usarse():
		return
	if costo_energia > 0.0:
		var energia := entidad_dueña.get_node_or_null("EnergiaComponente") as EnergiaComponente
		if energia and not energia.consumir(costo_energia):
			return  # Sin energía suficiente
	_ejecutar(direccion, poder)
	_iniciar_recarga()
	habilidad_activada.emit(self)
	BusEventos.habilidad_usada.emit(entidad_dueña, tipo_habilidad)

# ── Internos — sobreescribir en subclases ─────────────────────────────────────

## Aplica los valores de un DatosHabilidad a esta instancia.
## Las subclases pueden llamar super.aplicar_datos(d) y añadir sus propios campos.
func aplicar_datos(d: DatosHabilidad) -> void:
	if not d:
		return
	nombre_habilidad = d.nombre
	costo_energia    = float(d.costo_energia)
	duracion_recarga = d.enfriamiento
	_dano_min        = d.dano_calculado_min
	_dano_max        = d.dano_calculado_max

## Devuelve un daño entero aleatorio entre _dano_min y _dano_max.
## Si no hay rango definido (DatosHabilidad no aplicado), usa el fallback de la subclase.
func _calcular_dano(fallback: int) -> int:
	if _dano_min > 0 or _dano_max > 0:
		return randi_range(_dano_min, _dano_max)
	return fallback

## Lógica específica de la habilidad. Sobreescribir en cada subclase.
func _ejecutar(_direccion: Vector2, _poder: float) -> void:
	pass

func _iniciar_recarga() -> void:
	_recarga_restante = duracion_recarga
	BusEventos.recarga_iniciada.emit(entidad_dueña, slot_index, duracion_recarga)
