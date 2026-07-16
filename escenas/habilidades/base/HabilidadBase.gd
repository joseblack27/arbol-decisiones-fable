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
## Apagar SOLO en habilidades cuyo propósito ES moverse (dash, parpadeo):
## para esas, congelar al activar no tiene sentido (el desplazamiento es la
## habilidad misma) y ya tienen su propio manejo de posición. El resto
## (proyectiles, áreas, ráfaga...) se congela por defecto — ver activar().
@export var congela_movimiento_en_red := true
## Ida y vuelta de red que se le da al dueño para congelarse ANTES de que
## el servidor procese _activar_red — ver activar(). Si el ping real supera
## esto, la mitigación no alcanza a cubrir todo el hueco (mejor que nada,
## pero no es una garantía dura — la solución completa sería lag
## compensation del lado del servidor).
const _MARGEN_CONGELAMIENTO_RED := 0.25

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
	if _debe_pedirle_al_servidor():
		# Congelar ANTES de mandar el RPC de activación (no después): el
		# dueño deja de moverse en el mismo instante que decide disparar,
		# y bloquear_control() ya manda su propio aviso de "parate" al
		# servidor por un canal reliable — ver Jugador.bloquear_control().
		# Sin esto, el servidor seguía moviendo el cuerpo real durante toda
		# la ida y vuelta de red, y el proyectil "real" salía desde un
		# punto distinto al que el cliente ya mostraba quieto ("el golpe
		# no acierta, más si disparo en movimiento" — reportado).
		if congela_movimiento_en_red and entidad_dueña and entidad_dueña.has_method("bloquear_control"):
			entidad_dueña.bloquear_control()
			var dueño_congelado := entidad_dueña
			get_tree().create_timer(_MARGEN_CONGELAMIENTO_RED).timeout.connect(func():
				if is_instance_valid(dueño_congelado) and dueño_congelado.has_method("desbloquear_control"):
					dueño_congelado.desbloquear_control()
			)
		# Fase 3 del plan de multijugador: el servidor es quien de verdad
		# corre _ejecutar() con autoridad (el daño real, vía
		# VidaComponente.quitar_vida, está gateado a "solo servidor") para
		# que dos clientes no calculen resultados de combate distintos por
		# su cuenta. PERO no cortar acá: seguir abajo y llamar _ejecutar()
		# también en este cliente es predicción visual pura — el golpe se
		# ve y se anima al instante en vez de esperar la ida y vuelta de
		# red, sin aplicar daño de verdad (VidaComponente ya lo bloquea).
		rpc_id(1, "_activar_red", direccion, poder)
	if costo_energia > 0.0:
		var energia := entidad_dueña.get_node_or_null("EnergiaComponente") as EnergiaComponente
		if energia and not energia.consumir(costo_energia):
			return  # Sin energía suficiente
	_ejecutar(direccion, poder)
	_iniciar_recarga()
	habilidad_activada.emit(self)
	BusEventos.habilidad_usada.emit(entidad_dueña, tipo_habilidad)
	# Avisar a los DEMÁS clientes (espectadores, y toda habilidad de
	# enemigos — _debe_pedirle_al_servidor() siempre da false para mobs,
	# así que esta rama es la única que corre para ellos) para que también
	# vean el efecto. Solo tiene sentido si esto corrió con autoridad real
	# (el servidor, o un solo jugador sin red no necesita avisarle a nadie).
	if Utils.en_red() and multiplayer.is_server():
		rpc("_reproducir_visual_red", direccion, poder)


## true si esto corre en red, la dueña es un jugador con identidad de peer
## (ver Jugador.peer_id_dueño), y YO NO SOY el servidor. Sin multiplayer
## activo (juego de un jugador, o habilidades de enemigos sin peer_id_dueño)
## siempre da false — cero cambio de comportamiento en esos casos.
func _debe_pedirle_al_servidor() -> bool:
	if not Utils.en_red():
		return false
	if not is_instance_valid(entidad_dueña) or not ("peer_id_dueño" in entidad_dueña):
		return false
	var dueño: int = entidad_dueña.peer_id_dueño
	return dueño >= 0 and not multiplayer.is_server()


## El servidor recibe acá la intención de activar del cliente dueño de esta
## habilidad. "any_peer" = cualquiera puede llamarlo, pero se verifica que
## el remitente sea el dueño real antes de aceptarlo (autoridad real, mismo
## criterio que Jugador._pedir_mover_red()).
@rpc("any_peer", "reliable")
func _activar_red(direccion: Vector2, poder: float) -> void:
	if not multiplayer.is_server():
		return
	if not is_instance_valid(entidad_dueña) or not ("peer_id_dueño" in entidad_dueña):
		return
	if multiplayer.get_remote_sender_id() != entidad_dueña.peer_id_dueño:
		return
	# Un muerto no lanza habilidades — el cliente ya lo bloquea en su UI
	# (Jugador._activar_slot), pero la autoridad real vive acá.
	if ("_muerto" in entidad_dueña) and entidad_dueña.get("_muerto"):
		return
	activar(direccion, poder)


## El servidor le avisa a TODOS los clientes que reproduzcan el efecto
## visual de esta habilidad — el cliente dueño (si lo hay) ya lo mostró
## solo con predicción (ver activar()), así que se salta acá para no
## duplicar el golpe/animación. Nunca aplica daño de verdad: eso lo decide
## únicamente VidaComponente.quitar_vida(), gateado a "solo servidor".
## reliable: es UN paquete por activación (no un flujo continuo como la
## posición) — si se pierde, el jugador recibe el golpe "de la nada", sin
## ninguna animación (reportado con el lobo).
@rpc("authority", "reliable")
func _reproducir_visual_red(direccion: Vector2, poder: float) -> void:
	if is_instance_valid(entidad_dueña) and ("peer_id_dueño" in entidad_dueña) \
			and entidad_dueña.peer_id_dueño == multiplayer.get_unique_id():
		return
	_ejecutar(direccion, poder)

# ── Internos — sobreescribir en subclases ─────────────────────────────────────

## Aplica los valores de un DatosHabilidad a esta instancia.
## Las subclases pueden llamar super.aplicar_datos(d) y añadir sus propios campos.
func aplicar_datos(d: DatosHabilidad) -> void:
	if not d:
		return
	nombre_habilidad = d.nombre
	costo_energia    = float(d.costo_energia)
	duracion_recarga = d.enfriamiento
	_dano_min        = d.dano_base_min
	_dano_max        = d.dano_base_max

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
