class_name Proyectil
extends Area2D
## Proyectil en movimiento que daña al primer VidaComponente que toca.
## La velocidad es constante; poder escala el alcance máximo.
## Se crea puramente por código — no necesita escena .tscn.

@export var velocidad_base: float = 450.0
@export var alcance_base: float   = 400.0
@export var daño: float           = 20.0
@export var mostrar_debug: bool   = true
## Escena opcional que se instancia en el punto de impacto al chocar.
@export var escena_al_impactar: PackedScene = null

var entidad_fuente: Node = null
var tipo_dano: Enums.Skill.TypeDamage = Enums.Skill.TypeDamage.PHYSIC

var _direccion: Vector2         = Vector2.RIGHT
var _alcance_maximo: float      = 400.0
var _distancia_recorrida: float = 0.0
var _ya_impacto: bool           = false

func _ready() -> void:
	area_entered.connect(_on_area_entrada)
	body_entered.connect(_on_body_entrada)

## Inicializa el proyectil antes de añadirlo a la escena (o justo después).
## direccion    — vector de disparo (se normaliza internamente).
## poder        — escala el alcance (0.2–1.0).
## cantidad_daño — cuánto daño aplica al impactar.
## fuente       — entidad que disparó (para evitar auto-daño).
## tipo         — tipo de daño (afecta resistencias del defensor).
func configurar(direccion: Vector2, poder: float, cantidad_daño: float, fuente: Node, tipo: Enums.Skill.TypeDamage = Enums.Skill.TypeDamage.PHYSIC) -> void:
	_direccion      = direccion.normalized()
	_alcance_maximo = alcance_base * clampf(poder, 0.2, 1.0)
	daño            = cantidad_daño
	entidad_fuente  = fuente
	tipo_dano       = tipo
	rotation        = _direccion.angle()
	# Reinicio para reutilización desde la piscina (ver GestorPiscinas):
	# este proyectil puede llegar aquí recién creado o reciclado de un
	# disparo anterior, así que hay que rearmarlo por completo.
	_ya_impacto           = false
	_distancia_recorrida  = 0.0
	set_deferred("monitoring", true)


## GestorPiscinas.liberar() llama esto justo antes de esconder el nodo:
## apaga la detección de colisiones mientras espera en la piscina para que
## no vuelva a disparar impactos estando invisible en una posición vieja.
func _al_liberar_a_piscina() -> void:
	set_deferred("monitoring", false)

func _physics_process(delta: float) -> void:
	var paso := _direccion * velocidad_base * delta
	position  += paso
	_distancia_recorrida += paso.length()
	if _distancia_recorrida >= _alcance_maximo:
		GestorPiscinas.liberar(self)

func _spawnear_efecto_impacto(objetivo: Node2D) -> void:
	if not escena_al_impactar:
		return
	var efecto := escena_al_impactar.instantiate()
	if "fuente" in efecto:
		efecto.fuente = entidad_fuente
	# Diferido: esta función se llama desde area_entered (callback de física)
	# y añadir un CollisionObject al árbol aquí dispara "flushing queries".
	get_tree().current_scene.add_child.call_deferred(efecto)
	efecto.set_deferred("global_position", objetivo.global_position)


func _on_area_entrada(area: Area2D) -> void:
	if _ya_impacto:
		return
	# Caso normal: el área es el VidaComponente de una entidad (jugador o
	# mob) — el objetivo real es su padre. Caso genérico (p. ej. Muro, que
	# lleva su propia vida encima sin un VidaComponente aparte): cualquier
	# área con quitar_vida() es objetivo válido por sí misma — mismo criterio
	# que ya usa Arañazo._aplicar_daño().
	var defensor: Node
	var vida: Node
	if area is VidaComponente:
		vida     = area
		defensor = (area as VidaComponente).get_parent()
	elif area.has_method("quitar_vida"):
		vida     = area
		defensor = area
	else:
		return
	if defensor == entidad_fuente:
		return
	if Combate.mismo_equipo(entidad_fuente, defensor):
		return
	# Muro ALIADO: atravesarlo como si nada — sin gastarse ni dañarlo (el
	# muro igual bloquearía el daño por equipo, pero el proyectil moría
	# contra él de todos modos: disparo desperdiciado contra el muro propio).
	if defensor.has_method("es_aliado_de") and defensor.es_aliado_de(entidad_fuente):
		return
	# Obstáculos rompibles (p. ej. Muro): si el impacto (penetración de
	# armadura) de quien disparó supera su defensa, lo revienta y el
	# proyectil sigue de largo sin gastarse — no se marca _ya_impacto ni
	# se libera, sigue volando en busca de otro objetivo.
	# Obstáculo rompible (ver más abajo): no es un combatiente, así que no
	# muestra número de daño flotante — ese feedback es para golpes entre
	# personajes, no para chocar contra una pared.
	var es_obstaculo_rompible := defensor.has_method("recibir_impacto")
	if es_obstaculo_rompible and defensor.recibir_impacto(_obtener_impacto_fuente(), entidad_fuente):
		return
	_ya_impacto = true
	var dano_final := AtributosComponente.calcular_pipeline(entidad_fuente, defensor, daño, tipo_dano)
	if vida is VidaComponente:
		(vida as VidaComponente).quitar_vida(dano_final, entidad_fuente)
	else:
		vida.quitar_vida(dano_final, entidad_fuente)
	if not es_obstaculo_rompible and Utils.debe_mostrar_dano_local():
		BusEventos.daño_aplicado.emit(defensor, dano_final, entidad_fuente)
	BusEventos.habilidad_impacto.emit("proyectil", defensor)
	_spawnear_efecto_impacto(defensor)
	GestorPiscinas.liberar(self)

func _on_body_entrada(cuerpo: Node2D) -> void:
	if _ya_impacto:
		return
	if cuerpo == entidad_fuente:
		return
	if Combate.mismo_equipo(entidad_fuente, cuerpo):
		return
	if not cuerpo.has_method("quitar_vida"):
		return
	# Muro ALIADO: atravesarlo sin gastarse (ver _on_area_entrada).
	if cuerpo.has_method("es_aliado_de") and cuerpo.es_aliado_de(entidad_fuente):
		return
	var es_obstaculo_rompible := cuerpo.has_method("recibir_impacto")
	if es_obstaculo_rompible and cuerpo.recibir_impacto(_obtener_impacto_fuente(), entidad_fuente):
		return
	_ya_impacto = true
	var dano_final := AtributosComponente.calcular_pipeline(entidad_fuente, cuerpo, daño, tipo_dano)
	# Enemigos/jugadores reenvían el atacante a su VidaComponente; los
	# quitar_vida() genéricos (Muro...) también lo aceptan, para poder
	# chequear equipo (ver Muro._bloqueado_por_equipo).
	cuerpo.quitar_vida(dano_final, entidad_fuente)
	if not es_obstaculo_rompible and Utils.debe_mostrar_dano_local():
		BusEventos.daño_aplicado.emit(cuerpo, dano_final, entidad_fuente)
	BusEventos.habilidad_impacto.emit("proyectil", cuerpo)
	_spawnear_efecto_impacto(cuerpo)
	GestorPiscinas.liberar(self)

## Sprite provisional: el ÍCONO de la habilidad como imagen del proyectil,
## mientras no exista arte dedicado. Las habilidades que usan el
## Proyectil.tscn base (bola de fuego, ráfaga, abanico...) pasan su
## DatosHabilidad.icono acá tras configurar(). Los proyectiles custom con
## arte propio (AnimatedSprite2D en su escena, como la bola de telaraña o el
## inmovilizador) se ignoran solos. Con null se vuelve a los círculos de
## debug de _draw() — importante para el pooling: la MISMA instancia
## reciclada puede servir a habilidades distintas, así que esto se fija en
## cada disparo, nunca se asume el valor del uso anterior.
func poner_textura_icono(tex: Texture2D) -> void:
	# Arte propio de una escena custom (AnimatedSprite2D, como la bola de
	# telaraña; o un Sprite2D fijo con nombre propio, como ProyectilAbanico)
	# — no pisarlo. "SpriteIcono" es el nombre reservado que crea ESTA
	# función más abajo, así que un Sprite2D con otro nombre es arte real.
	if get_node_or_null("AnimatedSprite2D") != null:
		return
	for hijo in get_children():
		if hijo is Sprite2D and hijo.name != "SpriteIcono":
			return
	var sprite := get_node_or_null("SpriteIcono") as Sprite2D
	if tex == null:
		if sprite:
			sprite.visible = false
		mostrar_debug = true
		queue_redraw()
		return
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "SpriteIcono"
		add_child(sprite)
	sprite.texture = tex
	sprite.visible = true
	mostrar_debug = false
	queue_redraw()


## Penetración de armadura ("impacto") de quien disparó este proyectil, o 0
## si no tiene AtributosComponente. Usado para romper obstáculos como Muro.
func _obtener_impacto_fuente() -> float:
	if not is_instance_valid(entidad_fuente):
		return 0.0
	var atributos := entidad_fuente.get_node_or_null("AtributosComponente") as AtributosComponente
	if not atributos or not atributos.base:
		return 0.0
	return atributos.base.impacto

func _draw() -> void:
	if not mostrar_debug:
		return
	draw_circle(Vector2.ZERO, 8.0, Color(0.9, 0.5, 0.1))
	draw_circle(Vector2(12.0, 0.0), 5.0, Color(1.0, 0.8, 0.3))
