class_name HabilidadLlamadaAuxilio
extends HabilidadBase
## Firma de la Reina de las Hormigas: alerta a TODA la colonia viva en el
## mismo nivel. Cada hormiga (obrera o soldado) abandona lo que esté
## haciendo —incluso pelear con un jugador— y viaja directo a la cámara de
## la reina, ignorando a cualquier jugador que se cruce en el camino; solo
## vuelve a atacar una vez que llega cerca de ella (ver
## Enemigo.responder_llamada_auxilio() y la rama "ResponderLlamada" —
## Secuencia + CondicionMemoria + AccionIrAPunto— que trae cada .tscn de
## hormiga). Sin daño propio: es pura coordinación de la colonia.

func _ready() -> void:
	super._ready()
	nombre_habilidad = "Llamada de Auxilio"
	tipo_habilidad   = "llamada_auxilio"


func _ejecutar(_direccion: Vector2, _poder: float) -> void:
	# El sonido SÍ corre en todos lados (server + réplica visual en los
	# clientes cercanos vía _reproducir_visual_red) — es lo único que un
	# cliente necesita escuchar/ver de esta habilidad. El efecto real
	# (mover a cada hormiga) es autoridad exclusiva del servidor, mismo
	# criterio que _invocar_refuerzos() en los jefes de la Mina: un mob
	# vive una sola vez, con una sola fuente de verdad.
	_reproducir_sonido()
	if not is_instance_valid(entidad_dueña):
		return
	if Utils.en_red() and not multiplayer.is_server():
		return

	var nivel := _buscar_nivel_ancestro(entidad_dueña)
	if nivel == null:
		return
	var destino: Vector2 = (entidad_dueña as Node2D).global_position

	for mob in entidad_dueña.get_tree().get_nodes_in_group("enemigos"):
		if mob == entidad_dueña or not is_instance_valid(mob):
			continue
		if not mob.has_method("responder_llamada_auxilio"):
			continue
		if _buscar_nivel_ancestro(mob) != nivel:
			continue
		mob.responder_llamada_auxilio(destino)


## Sube por los padres hasta encontrar el NivelBase que contiene a "nodo" —
## mismo patrón que GestorNiveles.mapa_navegacion_de(), necesario para no
## alertar hormigas de OTRO nivel (con varios hormigueros/niveles cargados a
## la vez en el servidor, separados 100.000px entre sí — ver NivelBase).
func _buscar_nivel_ancestro(nodo: Node) -> Node:
	var arriba := nodo
	while arriba != null:
		if arriba is NivelBase:
			return arriba
		arriba = arriba.get_parent()
	return null
