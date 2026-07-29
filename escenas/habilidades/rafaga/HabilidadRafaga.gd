class_name HabilidadRafaga
extends HabilidadBase
## Ráfaga: dispara varios proyectiles en la MISMA dirección (la del momento
## de lanzar — queda congelada), uno cada "intervalo_disparo" segundos.
## Mientras la ráfaga está en curso, el lanzador no puede moverse ni girar
## (ver Jugador.bloquear_control) — es el costo de plantarse a disparar.
##
## Multijugador: _ejecutar corre en el cliente dueño (predicción visual),
## en el servidor (daño real) y en los espectadores (réplica visual, ver
## HabilidadBase._reproducir_visual_red) — cada lado corre SU ráfaga con el
## mismo timing; el daño de verdad solo lo aplica el servidor
## (VidaComponente ya lo gatea). El bloqueo de control solo tiene efecto
## donde importa: el cliente dueño (su joystick) y el servidor (el cuerpo
## autoritativo); en las réplicas de espectadores es un no-op inofensivo.

@export var cantidad_proyectiles: int = 5
@export var intervalo_disparo: float = 0.25
@export var daño_proyectil: float = 10.0
@export var escena_proyectil: PackedScene = preload("res://escenas/habilidades/proyectil/Proyectil.tscn")

var alcance_maximo: float = 400.0

## Ícono de la habilidad — sprite provisional del proyectil (ver
## Proyectil.poner_textura_icono, mismo mecanismo que HabilidadProyectil).
var _icono: Texture2D = null

var _disparos_restantes: int = 0
var _acumulador: float = 0.0
var _direccion_rafaga: Vector2 = Vector2.RIGHT


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Ráfaga"
	tipo_habilidad   = "rafaga"


func aplicar_datos(d: DatosHabilidad) -> void:
	super.aplicar_datos(d)
	alcance_maximo = d.alcance_metros * ESCALA_METROS_PIXEL
	_icono = d.icono


func _ejecutar(direccion: Vector2, _poder: float) -> void:
	# Si por configuración el enfriamiento fuera menor que la ráfaga y llega
	# un relanzamiento con una en curso, cerrar la anterior primero — sin
	# esto su bloqueo de control quedaba tomado para siempre (el contador
	# subía dos veces pero solo se soltaba una).
	if _disparos_restantes > 0:
		_terminar_rafaga()
	_direccion_rafaga = direccion.normalized() if direccion.length() > 0.1 else Vector2.RIGHT
	_disparos_restantes = cantidad_proyectiles
	_acumulador = 0.0
	if entidad_dueña and entidad_dueña.has_method("bloquear_control"):
		entidad_dueña.bloquear_control()
	# El primer proyectil sale YA — los siguientes, cada intervalo_disparo.
	_disparar_proyectil()


func _process(delta: float) -> void:
	super._process(delta)  # Tick de recarga (HabilidadBase)
	if _disparos_restantes <= 0:
		return
	# Un muerto no sigue disparando: cortar la ráfaga y soltar el control
	# (sin esto, el contador de bloqueo quedaba tomado para siempre).
	if is_instance_valid(entidad_dueña) and ("_muerto" in entidad_dueña) \
			and entidad_dueña.get("_muerto"):
		_terminar_rafaga()
		return
	_acumulador += delta
	if _acumulador >= intervalo_disparo:
		_acumulador -= intervalo_disparo
		_disparar_proyectil()


## Nombre propio (no "_disparar", que ahora es un método NO virtual de
## HabilidadBase con otra firma — chocaba con este) para el disparo de
## CADA proyectil individual de la ráfaga (uno por intervalo_disparo).
func _disparar_proyectil() -> void:
	if not is_instance_valid(entidad_dueña):
		_terminar_rafaga()
		return
	# Mismo patrón que HabilidadProyectil._ejecutar (pooling incluido).
	var proy := GestorPiscinas.obtener(escena_proyectil) as Proyectil
	proy.global_position = (entidad_dueña as Node2D).global_position
	proy.alcance_base = alcance_maximo
	proy.configurar(_direccion_rafaga, 1.0, _calcular_dano(int(daño_proyectil)), entidad_dueña, tipo_dano)
	proy.poner_textura_icono(_icono)
	_disparos_restantes -= 1
	if _disparos_restantes <= 0:
		_terminar_rafaga()


func _terminar_rafaga() -> void:
	if _disparos_restantes > 0:
		_disparos_restantes = 0
	if is_instance_valid(entidad_dueña) and entidad_dueña.has_method("desbloquear_control"):
		entidad_dueña.desbloquear_control()


## Si la habilidad se desequipa/libera a mitad de ráfaga, soltar el control
## igual — el contador de bloqueo no puede quedar tomado para siempre.
func _exit_tree() -> void:
	if _disparos_restantes > 0:
		_terminar_rafaga()
