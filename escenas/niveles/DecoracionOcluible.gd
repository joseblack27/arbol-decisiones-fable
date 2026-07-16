class_name DecoracionOcluible
extends StaticBody2D
## Decoración estática del mapa (árbol, arbusto, roca...).
##
## Estructura de la escena (todo se edita visualmente en el editor):
##   DecoracionOcluible (StaticBody2D — este script; su origen es la BASE
##   │                   del objeto: el punto de ordenamiento en Y)
##   ├── Sprite2D          → la textura (imagen o AtlasTexture con recorte)
##   ├── CollisionShape2D  → por dónde NO se puede pasar (la base sólida)
##   └── AreaOclusion      → silueta que, al tapar al jugador, se transparenta
##
## Este script NO calcula tamaños ni crea nodos: solo conecta las señales
## del área y aplica el fundido de oclusión.

## Sprite al que se le aplica la transparencia.
@export var sprite: Sprite2D
## Área cuya silueta detecta al jugador. OPCIONAL: si se deja vacía (objetos
## pequeños a ras de suelo que nunca tapan a nadie), la oclusión se desactiva
## por completo y el nodo no evalúa nada.
@export var area_oclusion: Area2D

@export_group("Oclusión")
## Opacidad cuando está tapando al jugador.
@export_range(0.1, 1.0) var opacidad_oculto := 0.45
## Velocidad del fundido (unidades de alfa por segundo).
@export var velocidad_fundido := 5.0

## Jugadores dentro de la silueta. El nodo solo procesa mientras haya alguien
## dentro (o quede fundido por deshacer): los árboles que nadie toca cuestan
## CERO script por frame.
var _cuerpos_dentro := 0


## Capa física del CUERPO del jugador (ver Jugador.tscn, collision_layer=8):
## desde que dejó la capa 1 (para que los personajes no choquen entre sí),
## una máscara por defecto (1) ya no lo detecta.
const CAPA_CUERPO_JUGADOR := 8


func _ready() -> void:
	set_physics_process(false)
	# Sin área de oclusión (o sin sprite) no hay nada que evaluar: el nodo
	# queda como decoración sólida pasiva, con coste cero.
	if area_oclusion == null or sprite == null:
		return
	# Por código y no en la escena: los niveles tienen MUCHAS decoraciones
	# armadas a mano (no instancias de DecoracionOcluible.tscn) — fijarlo acá
	# cubre todas, presentes y futuras, sin depender de editar cada .tscn.
	area_oclusion.collision_mask = CAPA_CUERPO_JUGADOR
	area_oclusion.body_entered.connect(_al_entrar_cuerpo)
	area_oclusion.body_exited.connect(_al_salir_cuerpo)


func _physics_process(delta: float) -> void:
	var objetivo := 1.0
	for cuerpo in area_oclusion.get_overlapping_bodies():
		if cuerpo.is_in_group(&"jugadores") and global_position.y > cuerpo.global_position.y:
			objetivo = opacidad_oculto
			break
	sprite.modulate.a = move_toward(sprite.modulate.a, objetivo, velocidad_fundido * delta)
	# Nadie dentro y ya opaco: volver a dormir.
	if _cuerpos_dentro == 0 and is_equal_approx(sprite.modulate.a, 1.0):
		set_physics_process(false)


func _al_entrar_cuerpo(cuerpo: Node2D) -> void:
	if cuerpo.is_in_group(&"jugadores"):
		_cuerpos_dentro += 1
		set_physics_process(true)


func _al_salir_cuerpo(cuerpo: Node2D) -> void:
	if cuerpo.is_in_group(&"jugadores"):
		_cuerpos_dentro = maxi(0, _cuerpos_dentro - 1)
