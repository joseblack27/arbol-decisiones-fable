class_name HabilidadMarcaColonia
extends HabilidadBase
## Marca de la Colonia: marca a un jugador AL AZAR entre los que estén cerca
## de la Reina (no necesariamente el que tiene enfrente) con una cuenta
## regresiva — al vencer, detona dañando al marcado Y a cualquiera que esté
## parado muy cerca suyo (a diferencia de la Marca del jugador, ver
## MarcaComponente._incluye_al_marcado). Escala igual jugando solo o en
## grupo: el daño no depende de cuánta gente haya, solo de si alguien se
## queda pegado al marcado — solo agrega la capa táctica de "separate antes
## de que explote" cuando hay más de un jugador cerca.
##
## Reutiliza MarcaComponente/BuffsComponente tal cual (mismo mecanismo ya
## probado por la Marca del jugador y ProyectilMarcaJefe) en vez de
## reinventar el temporizador/sello — solo cambia CÓMO se elige el objetivo
## (al azar entre los cercanos, no por dirección/proyectil) y que la
## detonación alcanza también al propio marcado.

const _TEXTURA_ICONOS := "res://assets/iconos/iconos habilidades.png"

@export_group("Marca de la Colonia")
## Hasta dónde busca candidatos a marcar, medido desde la propia Reina.
@export var radio_busqueda: float = 450.0
@export var duracion_marca: float = 4.0
@export var dano_detonacion: float = 35.0
@export var radio_detonacion: float = 100.0
@export var icono_debuff: Texture2D = preload(_TEXTURA_ICONOS)


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Marca de la Colonia"
	tipo_habilidad   = "marca_colonia"
	requiere_direccion = false
	# Región del ícono de "marcado" (Rect2(64,160,32,32) del mismo atlas que
	# ya usa la Marca del jugador y ProyectilMarcaJefe, ver EfectoMarcarJefe
	# .tscn) — misma lectura visual en todo el juego: "esto está marcado".
	var atlas := AtlasTexture.new()
	atlas.atlas = icono_debuff
	atlas.region = Rect2(64, 160, 32, 32)
	icono_debuff = atlas


func _ejecutar(_direccion: Vector2, _poder: float) -> void:
	_reproducir_sonido()
	if not is_instance_valid(entidad_dueña):
		return
	# Elegir el objetivo es autoridad exclusiva del servidor (o un solo
	# jugador): si cada cliente eligiera "al azar" por su cuenta, cada
	# pantalla marcaría a alguien distinto. Ver _marcar_objetivo_red, que
	# reproduce el mismo resultado ya elegido en cada espectador.
	if Utils.en_red() and not multiplayer.is_server():
		return

	var candidatos := _jugadores_cercanos()
	if candidatos.is_empty():
		return
	var objetivo: Node2D = candidatos.pick_random()
	_aplicar_marca(objetivo)

	if Utils.en_red() and multiplayer.is_server():
		var origen := entidad_dueña as Node2D
		if origen:
			for peer_id in InteresEspacial.peers_cercanos(origen.global_position):
				rpc_id(peer_id, "_marcar_objetivo_red", objetivo.get_path())


func _jugadores_cercanos() -> Array[Node2D]:
	var resultado: Array[Node2D] = []
	if not is_instance_valid(entidad_dueña) or not (entidad_dueña is Node2D):
		return resultado
	var origen := (entidad_dueña as Node2D).global_position
	for jugador in entidad_dueña.get_tree().get_nodes_in_group("jugadores"):
		if not is_instance_valid(jugador) or not (jugador is Node2D):
			continue
		if (jugador as Node2D).global_position.distance_to(origen) > radio_busqueda:
			continue
		resultado.append(jugador)
	return resultado


func _aplicar_marca(objetivo: Node2D) -> void:
	if not is_instance_valid(objetivo):
		return
	var marca := objetivo.get_node_or_null("MarcaComponente") as MarcaComponente
	if marca == null:
		marca = MarcaComponente.new()
		marca.name = "MarcaComponente"
		objetivo.add_child(marca)
	marca.activar(duracion_marca, 0.0, radio_detonacion, entidad_dueña, tipo_dano,
		dano_detonacion, true)
	if icono_debuff == null:
		return
	var buffs := objetivo.get_node_or_null("BuffsComponente") as BuffsComponente
	if buffs == null:
		buffs = BuffsComponente.new()
		buffs.name = "BuffsComponente"
		objetivo.add_child(buffs)
	buffs.agregar("marca_colonia", icono_debuff, duracion_marca, true, "Marcado por la Colonia")


## Réplica visual/de gameplay local en cada espectador (ver _ejecutar): el
## servidor ya eligió y aplicó la marca de verdad; acá solo se reproduce el
## MISMO resultado (sello + ícono) sobre el MISMO objetivo, sin volver a
## sortear nada. La propia MarcaComponente local de cada peer igual no hace
## daño real (VidaComponente.quitar_vida() se autobloquea fuera del
## servidor) — mismo criterio que cualquier otra habilidad replicada.
@rpc("authority", "reliable")
func _marcar_objetivo_red(ruta: NodePath) -> void:
	var objetivo := get_node_or_null(ruta) as Node2D
	if objetivo:
		_aplicar_marca(objetivo)
