class_name Cepo
extends Area2D
## Trampa oculta — mismo patrón que Trampa.gd (espera a que un enemigo pise
## su radio de detección) pero en vez de una explosión única de área, le
## PEGA un EfectoCepo al enemigo que la activa: lo inmoviliza y le hace
## daño por tick durante duracion_inmovilizacion segundos (ver
## EfectoCepo.gd). Se apaga sola a los duracion_maxima segundos si nadie la
## pisa. Se reutiliza vía GestorPiscinas, igual que Trampa.
##
## Sprite real (Bear_Trap.png, 4 frames de 32x32 — ver Cepo.tscn): frame 0
## es el cepo "puesto" en el suelo (animación estática, se ve todo el
## tiempo que espera), frames 1-3 son la mordida al pisarlo ("pisado", una
## sola vez, ~0.3s a 10fps — calzado con duracion_destello). A diferencia
## del radio de detección (SOLO visible para quien lo colocó, ver _draw),
## el sprite se ve para todos: es un objeto físico real en el mapa, no
## rompe nada que un mob no "vea" sprites y el cepo solo daña enemigos.

## Capa física de los mobs (ver Enemigo.CAPA_MOB) — el cepo SOLO reacciona
## a esto, nunca a jugadores ni obstáculos.
const _CAPA_MOB := 2
const _ESCENA_EFECTO := "res://escenas/efectos/EfectoCepo.gd"

@export var dano_por_tick: float             = 10.0
@export var intervalo_tick: float            = 0.5
@export var duracion_inmovilizacion: float   = 3.0
@export var radio_deteccion: float           = 15.0
@export var duracion_maxima: float           = 20.0
## Cuánto queda visible el destello al activarse antes de volver a la
## piscina (mismo criterio que Trampa.duracion_destello).
@export var duracion_destello: float         = 0.3
## Mismo ícono que la habilidad, para que BuffsComponente lo muestre igual
## que en el botón (ver EfectoCepo.icono_debuff).
@export var icono_debuff: Texture2D          = null

var entidad_fuente: Node = null
var tipo_dano: Enums.Habilidad.TipoDano = Enums.Habilidad.TipoDano.FISICO

@onready var _col_shape: CollisionShape2D = $CollisionShape2D
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
var _forma_deteccion: CircleShape2D
var _timer: float      = 0.0
var _activada: bool    = false
var _configurada: bool = false


func _ready() -> void:
	_forma_deteccion = _col_shape.shape as CircleShape2D
	collision_mask = _CAPA_MOB
	body_entered.connect(_on_body_entrada)


## Arma el cepo antes de dejarlo en el mapa.
## dano_tick   — daño de cada tick del EfectoCepo.
## intervalo   — segundos entre tick y tick.
## duracion_ci — segundos que dura la inmovilización una vez que se activa.
## radio_det   — radio de detección (cuándo se dispara).
## fuente      — quien lo colocó (evita auto-daño, escala con sus atributos).
## duracion    — segundos que espera antes de apagarse solo sin usar.
## tipo        — tipo de daño (afecta resistencias del defensor).
## icono       — ícono para BuffsComponente mientras dura el efecto.
func configurar(dano_tick: float, intervalo: float, duracion_ci: float, radio_det: float,
		fuente: Node, duracion: float,
		tipo: Enums.Habilidad.TipoDano = Enums.Habilidad.TipoDano.FISICO,
		icono: Texture2D = null) -> void:
	dano_por_tick             = dano_tick
	intervalo_tick            = intervalo
	duracion_inmovilizacion   = duracion_ci
	_forma_deteccion.radius   = radio_det
	entidad_fuente            = fuente
	duracion_maxima           = duracion
	tipo_dano                 = tipo
	icono_debuff              = icono
	# Reinicio para reutilización desde la piscina (ver GestorPiscinas):
	# esta instancia puede llegar recién creada o reciclada de un cepo
	# anterior.
	_timer       = 0.0
	_activada    = false
	_configurada = true
	set_deferred("monitoring", true)
	_sprite.play("puesto")
	queue_redraw()


## GestorPiscinas.liberar() llama esto justo antes de esconder el nodo —
## sin esto, un cepo "en espera" en la piscina seguiría reaccionando a
## cuerpos que pasen cerca mientras está oculto.
func _al_liberar_a_piscina() -> void:
	set_deferred("monitoring", false)
	_configurada = false


func _on_body_entrada(cuerpo: Node2D) -> void:
	if _activada or not _configurada:
		return
	_activada = true
	_timer = 0.0
	_sprite.play("pisado")
	# Diferido: esto corre desde body_entered (callback de física) —
	# agregar un nodo al árbol acá mismo dispara "flushing queries" (mismo
	# criterio que Proyectil._spawnear_efecto_impacto).
	call_deferred("_aplicar_efecto", cuerpo)
	queue_redraw()


func _aplicar_efecto(objetivo: Node2D) -> void:
	if not is_instance_valid(objetivo):
		return
	var efecto = (load(_ESCENA_EFECTO) as GDScript).new()
	efecto.objetivo      = objetivo
	efecto.fuente        = entidad_fuente
	efecto.dano_por_tick = dano_por_tick
	efecto.intervalo_tick = intervalo_tick
	efecto.duracion      = duracion_inmovilizacion
	efecto.tipo_dano     = tipo_dano
	efecto.icono_debuff  = icono_debuff
	objetivo.add_child(efecto)


func _process(delta: float) -> void:
	if not _configurada:
		return
	_timer += delta
	if _activada:
		if _timer >= duracion_destello:
			GestorPiscinas.liberar(self)
		return
	if _timer >= duracion_maxima:
		GestorPiscinas.liberar(self)


## La animación "pisado" del sprite ya muestra que se activó — el flash de
## debug de acá quedaba pisándola encima. Se deja solo la marca del radio
## de detección mientras espera, SOLO en la pantalla de quien lo colocó
## (mismo criterio que Trampa._draw).
func _draw() -> void:
	if _activada:
		return
	if _configurada and is_instance_valid(entidad_fuente) and entidad_fuente == Utils.jugador_local():
		draw_circle(Vector2.ZERO, _forma_deteccion.radius, Color(0.0, 0.0, 0.0, 0.35))
		draw_circle(Vector2.ZERO, 6.0, Color(0.6, 0.4, 0.1, 0.4))
