class_name AliadoInvocado
extends Enemigo
## Aliado invocado temporal: reusa Enemigo.gd de base (vida, red, muerte),
## pero en el equipo del JUGADOR (no "enemigos") y con su propia IA simple
## en código plano en vez del árbol de comportamiento completo — evita
## reconstruir toda la maquinaria de nodos BT (Selector/Secuencia/Condicion/
## AccionAtacar/AccionPerseguir) para algo que solo necesita "perseguir y
## golpear al enemigo más cercano". Combate.buscar_enemigo_mas_cercano ya
## hace exactamente esa búsqueda (mismo criterio de equipo, ya probado por
## Rebote y Golpe Vampírico).
##
## Vive un tiempo limitado (ver activar()) y se desvanece solo al vencer —
## Enemigo.gd no tenía ningún mecanismo de "duración limitada" (todo mob de
## siempre vive hasta que lo maten); reusa _desvanecer_y_eliminar() (mismo
## fundido visual que una muerte real) en vez de reinventar el desvanecido.

@export var rango_ataque: float = 40.0
@export var rango_deteccion: float = 300.0
@export var dano_ataque: float = 10.0
@export var intervalo_ataque: float = 1.0
@export var velocidad_persecucion: float = 140.0
@export var tipo_dano_ataque: Enums.Habilidad.TipoDano = Enums.Habilidad.TipoDano.FISICO

## Quién lo invocó — el aliado no ataca a este nodo ni a su equipo (ver
## Combate.mismo_equipo, ya cubre esto solo por estar ambos en "jugadores"),
## y sin un enemigo cerca vuelve a seguirlo en vez de quedarse plantado.
var dueño: Node = null

var _restante: float = 0.0
var _acumulador_ataque: float = 0.0


func _ready() -> void:
	super._ready()
	# Enemigo._ready() ya hizo add_to_group("enemigos") — invertir el equipo
	# es lo único que hace falta para que Combate.mismo_equipo() (usado en
	# TODO el juego para fuego amigo/targeting) trate a este aliado como un
	# jugador más: no le pega el dueño, no le pegan otros jugadores, y los
	# mobs de verdad SÍ lo atacan (comportamiento deseado: es un tanque más).
	remove_from_group("enemigos")
	add_to_group("jugadores")
	queue_redraw()
	# Pedido del usuario: el aliado no debe sobrevivir a que el dueño cambie
	# de zona (portal a otro nivel). Un chequeo dentro de _physics_process no
	# alcanza: en cuanto el nivel viejo se queda sin jugadores,
	# GestorNiveles._actualizar_actividad_niveles() le pone
	# PROCESS_MODE_DISABLED a TODO su subárbol (este aliado incluido) para
	# ahorrar CPU en el servidor — su propio _physics_process deja de correr
	# antes de poder notar el cambio. Por eso esto reacciona a la señal en el
	# momento exacto en que el servidor mueve al peer, todavía con el nivel
	# viejo despierto. Inofensivo en el cliente/un jugador: esa señal nunca
	# se emite fuera del servidor (ver GestorNiveles.mover_peer_a_nivel).
	GestorNiveles.jugador_cambio_de_nivel.connect(_al_dueño_cambiar_de_nivel)


## Arranca la cuenta regresiva de vida útil — llamar apenas se instancia,
## antes de que corra el primer _physics_process.
func activar(duracion: float) -> void:
	_restante = duracion


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _muerto:
		return
	# Mismo criterio que el resto del proyecto: la IA vive SOLO en el
	# servidor/single-player — un cliente puro solo interpola la posición
	# replicada (ya resuelto arriba, en Enemigo._physics_process).
	if Utils.en_red() and not multiplayer.is_server():
		return
	if not is_instance_valid(dueño):
		_al_vencer_duracion()
		return
	_restante -= delta
	if _restante <= 0.0:
		_al_vencer_duracion()
		return
	_actualizar_ia(delta)


## SERVIDOR: el dueño acaba de cambiar de nivel — el nombre del nodo Jugador
## ES el peer id (ver Jugador.gd/GestorNiveles.nivel_de_jugador), así que
## comparar por nombre no depende de peer_id_dueño (que en single-player/
## pruebas sueltas se queda en -1 por no pasar nunca por Utils.en_red()).
func _al_dueño_cambiar_de_nivel(peer_id: int) -> void:
	if _muerto or not is_instance_valid(dueño):
		return
	if String(dueño.name) == str(peer_id):
		_al_vencer_duracion()


func _actualizar_ia(delta: float) -> void:
	if not is_instance_valid(dueño):
		return
	var objetivo := Combate.buscar_enemigo_mas_cercano(self, rango_deteccion, dueño, [])
	if objetivo == null:
		# Sin nada que pelear: quedarse cerca del dueño en vez de plantado.
		direccion_mirada = Vector2.ZERO
		if componente_movimiento and global_position.distance_to(dueño.global_position) > rango_ataque:
			componente_movimiento.comandar_destino(dueño.global_position, velocidad_persecucion)
		elif componente_movimiento:
			componente_movimiento.detener()
		return

	var pos_objetivo: Vector2 = (objetivo as Node2D).global_position
	var distancia := global_position.distance_to(pos_objetivo)
	if distancia > rango_ataque:
		direccion_mirada = Vector2.ZERO
		if componente_movimiento:
			componente_movimiento.comandar_destino(pos_objetivo, velocidad_persecucion)
		return

	direccion_mirada = global_position.direction_to(pos_objetivo)
	if componente_movimiento:
		componente_movimiento.detener()
	_acumulador_ataque += delta
	if _acumulador_ataque >= intervalo_ataque:
		_acumulador_ataque = 0.0
		_atacar(objetivo)


func _atacar(objetivo: Node) -> void:
	var vida: Node = objetivo.get_node_or_null("VidaComponente") as VidaComponente
	if vida == null and objetivo.has_method("quitar_vida"):
		vida = objetivo
	if vida == null:
		return
	var dano_final := AtributosComponente.calcular_pipeline(self, objetivo, dano_ataque, tipo_dano_ataque)
	var fue_critico := AtributosComponente.ultimo_pipeline_critico
	# "fuente" acá es el DUEÑO, no self: GestorNumerosDano._al_aplicar_daño
	# solo pinta el número flotante si fuente u objetivo es Utils.jugador_
	# local() (pedido del usuario: "que al menos el invocador pudiera ver el
	# daño" + luego "quiero que se vean con números flotantes") — con
	# self (el aliado, sin peer_id_dueño) el filtro nunca reconocía el golpe
	# como "mío" y lo descartaba en silencio. Mismo motivo por el que
	# Enemigo._peer_dueño_del_atacante()/_es_mi_propio_golpe() necesitan que
	# "fuente" resuelva a un Jugador real: con self, ni el botín/xp ni el
	# parpadeo de "mi golpe conectó" funcionaban tampoco.
	if vida is VidaComponente:
		(vida as VidaComponente).quitar_vida(dano_final, dueño, tipo_dano_ataque, fue_critico)
	else:
		vida.quitar_vida(dano_final, dueño, tipo_dano_ataque, fue_critico)
	if Utils.debe_mostrar_dano_local():
		BusEventos.daño_aplicado.emit(objetivo, dano_final, dueño, tipo_dano_ataque, fue_critico)
	BusEventos.habilidad_impacto.emit("aliado_invocado", objetivo)


## Igual que _on_muerte() (frenar cuerpo, apagar de verdad) pero SIN pasar
## por _procesar_muerte() — no otorga botín ni XP: no murió, se le acabó el
## tiempo. _desvanecer_y_eliminar() es la misma función que usa una muerte
## real, así que el desvanecido visual es idéntico.
func _al_vencer_duracion() -> void:
	if _muerto:
		return
	_muerto = true
	if componente_movimiento:
		componente_movimiento.detener()
	_desvanecer_y_eliminar()
