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
var tipo_dano: Enums.Habilidad.TipoDano = Enums.Habilidad.TipoDano.FISICO

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
func configurar(direccion: Vector2, poder: float, cantidad_daño: float, fuente: Node, tipo: Enums.Habilidad.TipoDano = Enums.Habilidad.TipoDano.FISICO) -> void:
	_direccion      = direccion.normalized()
	_alcance_maximo = alcance_base * clampf(poder, 0.2, 1.0)
	daño            = cantidad_daño
	entidad_fuente  = fuente
	tipo_dano       = tipo
	# El NODO RAÍZ ya no rota (antes: "rotation = _direccion.angle()") —
	# solo el/los Sprite2D hijos, ver _rotar_sprites(). Con el sprite
	# desplazado de su centro (offset vertical para que coincida mejor
	# visualmente con el arte), rotar el nodo entero hacía girar TAMBIÉN
	# ese desplazamiento alrededor del origen — al disparar hacia la
	# izquierda, el sprite terminaba de cabeza/espejado en vez de solo
	# "mirar" hacia el otro lado (reportado: "quedan volteados").
	_rotar_sprites()
	# Reinicio para reutilización desde la piscina (ver GestorPiscinas):
	# este proyectil puede llegar aquí recién creado o reciclado de un
	# disparo anterior, así que hay que rearmarlo por completo.
	_ya_impacto           = false
	_distancia_recorrida  = 0.0
	set_deferred("monitoring", true)


## Rota SOLO los Sprite2D hijos (arte propio de la escena y/o el ícono
## dinámico "SpriteIcono") para que miren hacia _direccion — nunca el nodo
## raíz, ver el comentario en configurar(). Se llama de nuevo desde
## poner_textura_icono() porque ese ícono puede crearse DESPUÉS de
## configurar() (HabilidadProyectil._ejecutar() llama configurar() primero
## y recién después pasa el ícono), así que en ese momento tiene que
## heredar la misma orientación ya calculada.
func _rotar_sprites() -> void:
	var angulo := _direccion.angle()
	for hijo in get_children():
		if hijo is Sprite2D:
			(hijo as Sprite2D).rotation = angulo


## GestorPiscinas.liberar() llama esto justo antes de esconder el nodo:
## apaga la detección de colisiones mientras espera en la piscina para que
## no vuelva a disparar impactos estando invisible en una posición vieja.
func _al_liberar_a_piscina() -> void:
	set_deferred("monitoring", false)

## Barrido de la trayectoria de ESTE fotograma con la propia forma del
## proyectil, no solo su posición final — antes se movía con un simple
## "position += paso" y dejaba que Area2D detectara el overlap DESPUÉS de
## moverse, chequeando solo dónde el proyectil TERMINÓ el fotograma, nunca
## el camino recorrido. A velocidad_base=450px/s y 60 físicas/seg, cada
## fotograma avanza ~7.5px — comparable al radio del proyectil (8px) y al
## de los mobs (~12-14px) — así que a veces "saltaba por encima" de un
## objetivo entero sin que ningún fotograma llegara a solaparlo (el golpe
## que a veces no registraba), y otras veces un roce apenas de esquina caía
## justo en el borde del overlap post-movimiento, un instante ambiguo que
## podía aplicar el daño sin que el resto del código (_ya_impacto,
## GestorPiscinas.liberar) llegara a resolverse limpio para ese mismo
## contacto (el "hace daño pero no se destruye" reportado). cast_motion()
## consulta la física directo con la forma real y el vector de movimiento
## completo del fotograma — no puede saltarse nada en el medio.
func _physics_process(delta: float) -> void:
	if _ya_impacto:
		return
	var paso := _direccion * velocidad_base * delta
	_distancia_recorrida += paso.length()

	var impacto := _buscar_impacto_en_trayecto(paso)
	if not impacto.is_empty():
		position += paso * impacto["fraccion"]
		_resolver_colision(impacto["collider"])
		if _ya_impacto:
			return  # Impacto real ya resuelto (dañado + liberado): no seguir.
		# El collider tocado NO era un objetivo válido (la propia fuente —
		# el proyectil NACE encima de quien lo lanza, así que esto pasaba
		# en el primer fotograma de CADA disparo—, un aliado, un obstáculo
		# que ya se rompió...): completar el resto del movimiento de este
		# fotograma con normalidad. Sin esto, el proyectil se quedaba
		# "trabado" avanzando solo la fracción hasta ese primer contacto
		# inválido, fotograma tras fotograma, en vez de seguir de largo —
		# se veía como si a veces simplemente no funcionara.
		position += paso * (1.0 - impacto["fraccion"])
	else:
		position += paso

	if not _ya_impacto and _distancia_recorrida >= _alcance_maximo:
		GestorPiscinas.liberar(self)


## Devuelve {"collider": Object, "fraccion": float} del primer contacto real
## a lo largo de "paso" (0..1, qué fracción del movimiento de este fotograma
## hace falta para llegar al contacto), o {} si no hay nada en el camino.
func _buscar_impacto_en_trayecto(paso: Vector2) -> Dictionary:
	var forma := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not forma or not forma.shape:
		return {}
	var espacio := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = forma.shape
	query.transform = global_transform
	query.motion = paso
	query.collision_mask = collision_mask
	query.exclude = [self]
	query.collide_with_areas = true
	query.collide_with_bodies = true
	# [fraccion_segura, fraccion_insegura] — sin colisión, ambas dan 1.0.
	var fracciones := espacio.cast_motion(query)
	if fracciones.size() < 2 or fracciones[1] >= 1.0:
		return {}
	# Reubicar la MISMA forma justo en el punto de contacto (no en el
	# origen) para preguntar QUÉ hay ahí — cast_motion() solo dice "hasta
	# dónde se puede mover", no quién bloqueó el paso.
	var transform_contacto := query.transform
	transform_contacto.origin += paso * fracciones[1]
	query.transform = transform_contacto
	query.motion = Vector2.ZERO
	for resultado in espacio.intersect_shape(query, 4):
		return {"collider": resultado["collider"], "fraccion": fracciones[1]}
	return {}

func _spawnear_efecto_impacto(objetivo: Node2D) -> void:
	if not escena_al_impactar:
		return
	var efecto := escena_al_impactar.instantiate()
	if "fuente" in efecto:
		efecto.fuente = entidad_fuente
	# Dos sabores de efecto (los distingue su propia interfaz):
	#  - con propiedad "objetivo" (EfectoLentitud): debuff PEGADO al blanco —
	#    se agrega como hijo suyo, lo sigue a donde vaya y muere con él.
	#  - sin ella (EfectoInmovilizar y demás áreas): zona suelta en el punto
	#    de impacto, como siempre.
	# Diferido en ambos casos: esta función se llama desde area_entered
	# (callback de física) y añadir nodos al árbol aquí dispara
	# "flushing queries".
	if "objetivo" in efecto:
		efecto.objetivo = objetivo
		objetivo.add_child.call_deferred(efecto)
	else:
		get_tree().current_scene.add_child.call_deferred(efecto)
		efecto.set_deferred("global_position", objetivo.global_position)


## Señales de Area2D — se dejan conectadas como RED DE SEGURIDAD (p. ej. un
## objetivo que se mueve hacia un proyectil ya detenido por algún motivo, o
## cualquier overlap que el barrido de _physics_process no cubriera), pero
## ya NO son el camino principal de detección — ver _buscar_impacto_en_
## trayecto() en _physics_process().
func _on_area_entrada(area: Area2D) -> void:
	_resolver_colision(area)

func _on_body_entrada(cuerpo: Node2D) -> void:
	_resolver_colision(cuerpo)


## Único punto que decide qué hacer al tocar algo, sin importar si vino del
## barrido de trayectoria (cast_motion) o de las señales area_entered/
## body_entered — antes esta lógica estaba duplicada casi igual en ambas.
func _resolver_colision(objeto: Object) -> void:
	if _ya_impacto or not (objeto is Node):
		return
	var nodo := objeto as Node
	# Caso normal: el nodo es el VidaComponente de una entidad (jugador o
	# mob) — el objetivo real es su padre. Caso genérico (p. ej. Muro, que
	# lleva su propia vida encima sin un VidaComponente aparte): cualquier
	# nodo con quitar_vida() es objetivo válido por sí mismo — mismo
	# criterio que ya usa Arañazo._aplicar_daño().
	var defensor: Node
	var vida: Node
	if nodo is VidaComponente:
		vida     = nodo
		defensor = (nodo as VidaComponente).get_parent()
	elif nodo.has_method("quitar_vida"):
		vida     = nodo
		defensor = nodo
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
	# SpriteIcono se crea DESPUÉS de configurar() (ver ese comentario) —
	# heredar la orientación ya calculada, no quedarse apuntando a 0°.
	sprite.rotation = _direccion.angle()


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
