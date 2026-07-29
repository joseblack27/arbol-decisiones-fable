class_name ProyectilRebote
extends Proyectil
## Proyectil de la habilidad Rebote: al pegarle a un enemigo no se detiene
## — busca el enemigo válido más cercano que todavía no haya golpeado
## dentro de radio_busqueda_rebote y sigue de largo hacia él, hasta
## rebotes_maximos veces o hasta quedarse sin objetivos nuevos cerca (ver
## Proyectil._al_impactar_de_verdad, el punto que esta clase sobreescribe).

@export var rebotes_maximos: int = 2
@export var radio_busqueda_rebote: float = 200.0

var _rebotes_restantes: int = 0
var _ya_golpeados: Array = []


## Llamar DESPUÉS de configurar() (mismo orden que GanchoProyectil.
## habilidad_dueña) — reinicia el estado de rebotes para reutilización
## desde la piscina, ya que configurar() no sabe nada de estos campos.
func preparar_rebotes(rebotes: int, radio_busqueda: float) -> void:
	rebotes_maximos = rebotes
	radio_busqueda_rebote = radio_busqueda
	_rebotes_restantes = rebotes
	_ya_golpeados.clear()


func _debe_ignorar_objetivo(defensor: Node) -> bool:
	return defensor in _ya_golpeados


func _al_impactar_de_verdad(defensor: Node) -> void:
	_spawnear_efecto_impacto(defensor)
	_ya_golpeados.append(defensor)
	if _rebotes_restantes <= 0:
		GestorPiscinas.liberar(self)
		return
	# Quien disparó puede haber muerto y liberado su nodo en algún rebote
	# anterior de este mismo vuelo — is_instance_valid() lo detecta, "if
	# entidad_fuente:" no (mismo criterio que Proyectil._resolver_colision,
	# ver ese comentario).
	var fuente_valida: Node = entidad_fuente if is_instance_valid(entidad_fuente) else null
	var siguiente := Combate.buscar_enemigo_mas_cercano(
			self, radio_busqueda_rebote, fuente_valida, _ya_golpeados)
	if siguiente == null:
		GestorPiscinas.liberar(self)
		return
	_rebotes_restantes -= 1
	_direccion = global_position.direction_to((siguiente as Node2D).global_position)
	_rotar_sprites()
	_distancia_recorrida = 0.0
	# _ya_impacto se queda en true por ESTE fotograma (Proyectil._physics_
	# process ya cortó el resto del movimiento del paso actual al verlo
	# así — evita que el proyectil avance un resto de fotograma en la
	# dirección VIEJA antes de redirigirse) y recién se destraba diferido,
	# a tiempo para el próximo fotograma de física con la dirección nueva
	# ya puesta. Mismo idiom que configurar() usa para "monitoring".
	set_deferred("_ya_impacto", false)
