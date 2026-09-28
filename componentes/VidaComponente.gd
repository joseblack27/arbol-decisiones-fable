## VidaComponente.gd
## Componente responsable de gestionar la salud del agente.
## Debe ser adjuntado al nodo raíz del personaje o a un nodo hijo para recibir señales.

extends Area2D
class_name VidaComponente

signal cambio_valor_vida(valor: float)

# Señal emitida cuando la vida del agente llega o cae por debajo de cero.
signal muerte(valor: float)

@export var salud_maxima: float = 100.0
@export var salud_actual: float

@export_group("Regeneración")
## RESPALDO cuando la entidad no tiene AtributosComponente (mobs simples,
## pruebas): porcentaje de la vida máxima recuperado por tick. Si SÍ hay
## atributos, manda AtributosBase.regeneracion_vida (base + bonos de equipo,
## ver AtributosComponente.recalcular_con_equipo) y esto se ignora.
@export var regeneracion_porcentaje: float = 1.0
## Segundos entre ticks de regeneración. 0 = sin regeneración.
@export var intervalo_regeneracion: float = 10.0

var _acumulador_regen: float = 0.0

## Invulnerabilidad temporal: mientras sea > 0, quitar_vida() no aplica NADA
## (ver activar_invulnerabilidad). La usan la aparición y la reaparición del
## jugador: su cuerpo ya es atacable en el servidor mientras el cliente
## todavía carga o funde desde negro.
var _invulnerable_restante: float = 0.0

# --- Inicialización y Estado ---

func _ready():
	salud_actual = salud_maxima


## Vuelve a esta entidad inmune a TODO daño por "segundos". Nunca acorta una
## invulnerabilidad más larga ya en curso (maxf), así dos fuentes solapadas no
## se pisan.
func activar_invulnerabilidad(segundos: float) -> void:
	if segundos <= 0.0:
		return
	_invulnerable_restante = maxf(_invulnerable_restante, segundos)


func es_invulnerable() -> bool:
	return _invulnerable_restante > 0.0


## Corta la invulnerabilidad ya mismo. La usan las pruebas que necesitan
## golpear a un jugador recién aparecido (ver prueba_muerte_jugador).
func cancelar_invulnerabilidad() -> void:
	_invulnerable_restante = 0.0


func _process(delta: float) -> void:
	# Corre en TODOS los peers (no solo donde el daño es real): en el
	# servidor es lo que de verdad bloquea el golpe, y en el cliente es lo
	# que apaga a tiempo el feedback visual de "estoy protegido".
	if _invulnerable_restante > 0.0:
		_invulnerable_restante = maxf(0.0, _invulnerable_restante - delta)

	# Regeneración por ticks, SOLO donde el cálculo es el real (servidor o sin
	# red); al cliente le llega por la réplica de agregar_vida(). Los muertos no
	# regeneran.
	if intervalo_regeneracion <= 0.0:
		return
	if Utils.en_red() and not multiplayer.is_server():
		return
	_acumulador_regen += delta
	if _acumulador_regen < intervalo_regeneracion:
		return
	_acumulador_regen -= intervalo_regeneracion
	if salud_actual <= 0.0 or salud_actual >= salud_maxima:
		return
	var cantidad := _cantidad_regen()
	if cantidad <= 0.0:
		return
	agregar_vida(cantidad)


## Magnitud del tick, siempre en valores ENTEROS: parte porcentual (atributo
## regeneracion_vida, la base de la entidad — 1% de la vida máxima, mínimo 1
## punto para que máximas chicas no la dejen en cero) + parte PLANA (atributo
## regeneracion_vida_plana, lo que suman los ítems equipados: p. ej. un
## anillo de +10 → total 1% + 10). Como recalcular_con_equipo muta "base" en
## su sitio, equipar/quitar cambia el resultado en vivo. Sin
## AtributosComponente (mobs simples, pruebas), el export de respaldo.
func _cantidad_regen() -> float:
	var porcentaje := regeneracion_porcentaje
	var plana := 0.0
	var padre := get_parent()
	if padre:
		var atributos := padre.get_node_or_null("AtributosComponente") as AtributosComponente
		if atributos and atributos.base:
			porcentaje = atributos.base.regeneracion_vida
			plana      = atributos.base.regeneracion_vida_plana
	var total := 0.0
	if porcentaje > 0.0:
		total += maxf(1.0, floorf(salud_maxima * porcentaje / 100.0))
	total += floorf(maxf(0.0, plana))
	return total

## Consulta la vida actual del agente.
func obtener_vida() -> float:
	return salud_actual

## Devuelve la vida máxima del agente.
func obtener_vida_maxima() -> float:
	return salud_maxima

## Fija la vida directo a un valor conocido (p. ej. al cargar una partida).
## A diferencia de quitar_vida()/agregar_vida(), no dispara "muerte" aunque el
## valor sea 0: cargar una partida nunca debería matar a nadie.
func restaurar_vida(valor: float) -> void:
	salud_actual = clampf(valor, 0.0, salud_maxima)
	cambio_valor_vida.emit(salud_actual)
	# Mismo criterio que quitar/agregar: si esto corre en el servidor (p. ej.
	# al cargar una partida guardada), el cliente tiene que enterarse.
	if Utils.en_red() and multiplayer.is_server():
		InteresEspacial.rpc_a_quien_lo_tiene(self, &"_recibir_vida_red", [salud_actual, "", salud_maxima])


## Agrega vida al agente. Retorna el exceso de vida (si se sobrepasa el máximo).
func agregar_vida(cantidad: float) -> float:
	# Mismo gate que quitar_vida(): en red, solo el SERVIDOR decide cuánta vida
	# hay; el cliente se entera por _recibir_vida_red.
	if Utils.en_red() and not multiplayer.is_server():
		return 0.0
	if cantidad <= 0:
		return 0.0

	var vida_anterior = salud_actual
	salud_actual = min(salud_actual + cantidad, salud_maxima)


	cambio_valor_vida.emit(salud_actual)
	# Número flotante verde "+N": lo dibuja GestorNumerosCuracion, que escucha
	# BusEventos.curacion_aplicada. Se emite lo ganado de verdad (no
	# "cantidad", que puede pasarse del máximo), y nada si ya estaba al tope,
	# para que no flote un "+0".
	if salud_actual > vida_anterior:
		BusEventos.curacion_aplicada.emit(get_parent(), salud_actual - vida_anterior)
	if Utils.en_red() and multiplayer.is_server():
		InteresEspacial.rpc_a_quien_lo_tiene(self, &"_recibir_vida_red", [salud_actual, "", salud_maxima])

	# Retorna la vida que se perdió al alcanzar el máximo
	return max(0.0, (vida_anterior + cantidad) - salud_maxima)

## Quita vida al agente. Retorna la vida restante (si es > 0).
## fuente (opcional): quién infligió el daño; solo viaja al cliente (ver
## _recibir_vida_red) para que el log de Actividad Reciente diga quién pegó.
## tipo (opcional): elemento del golpe. NO afecta el cálculo (el daño llega
## ya pasado por calcular_pipeline, resistencias incluidas); solo viaja para
## pintar el número flotante del color del elemento.
## critico (opcional): si el golpe fue crítico, para pintar el número amarillo.
## es_area / origen_dano (opcionales): SOLO los usa ParryComponente (ver
## HabilidadCorte). Los pasan Combate.golpear_area() (origen = el atacante,
## donde está anclado el hitbox) y EfectoDoT._aplicar_tick() (origen = el
## charco, no quien lo creó).
func quitar_vida(cantidad: float, fuente: Node = null,
		tipo: Enums.Habilidad.TipoDano = Enums.Habilidad.TipoDano.FISICO,
		critico: bool = false, es_area: bool = false,
		origen_dano: Vector2 = Vector2.INF) -> float:
	# En red, solo el SERVIDOR decide cuánta vida queda. Es el punto central
	# por el que pasa TODO el daño, así que el gate cubre a todas las
	# habilidades sin tocar cada una.
	if Utils.en_red() and not multiplayer.is_server():
		return salud_actual
	if cantidad <= 0:
		return salud_actual

	# Ya murió: la hurtbox recién se desactiva en el próximo frame físico
	# (_apagar_colision_de_muerto usa set_deferred), y un segundo golpe en el
	# MISMO frame (área con dos fuentes, dos proyectiles a la vez) volvía a
	# emitir "muerte": el botín y la XP se repartían dos veces.
	if salud_actual <= 0.0:
		return 0.0

	# Invulnerabilidad (ver activar_invulnerabilidad): corta ANTES que nada,
	# ni siquiera gasta el escudo temporal de abajo contra un golpe que igual
	# no iba a entrar.
	if _invulnerable_restante > 0.0:
		return salud_actual

	var padre := get_parent()

	# Parry direccional de HabilidadCorte (ver ParryComponente): corta ANTES
	# del escudo, porque un golpe parado no llegó a entrar. Se busca por
	# NOMBRE de nodo, no por tipo, como EscudoComponente acá abajo e
	# InmunidadDebuffsComponente en EfectoTemporalPegado.
	var parry := padre.get_node_or_null("ParryComponente") if padre else null
	if parry and parry.bloquea(es_area, origen_dano):
		return salud_actual

	# Escudo temporal (ver EscudoComponente/HabilidadEscudo): reduce o bloquea
	# el daño ANTES de aplicarlo, así todo ataque lo respeta sin chequeos en
	# cada habilidad. Es un hermano de este componente, colgado de la misma
	# entidad (ver Jugador.tscn).
	var escudo := padre.get_node_or_null("EscudoComponente") as EscudoComponente if padre else null
	if escudo:
		cantidad = escudo.aplicar(cantidad, fuente)
		if cantidad <= 0.0:
			return salud_actual

	# Vulnerabilidad temporal (ver VulnerabilidadComponente y
	# HabilidadPuestaHuevos): el espejo de EscudoComponente, amplifica en vez
	# de reducir.
	var vulnerabilidad := padre.get_node_or_null("VulnerabilidadComponente") as VulnerabilidadComponente if padre else null
	if vulnerabilidad:
		cantidad = vulnerabilidad.aplicar(cantidad, fuente)

	salud_actual -= cantidad


	cambio_valor_vida.emit(salud_actual)
	# El número flotante de daño NO se muestra desde acá: quien inflige el
	# daño emite BusEventos.daño_aplicado y GestorNumerosDano lo dibuja. Este
	# componente solo gestiona salud.

	# En red, avisarle el valor real a los clientes: su copia local nunca
	# corre este quitar_vida() (el gate de arriba), y sin esto la barra de
	# vida (BarraVidaEnergiaComponente) no se movería.
	if Utils.en_red() and multiplayer.is_server():
		# La ruta del atacante viaja como String: mobs y jugadores tienen el
		# MISMO path en todos los peers, así que el cliente la resuelve localmente.
		var ruta_fuente := str(fuente.get_path()) if is_instance_valid(fuente) else ""
		# Solo a los peers cercanos (InteresEspacial), no a todos, igual que la
		# posición de mobs y jugadores.
		if padre is Node2D:
			for peer_id in InteresEspacial.peers_cercanos((padre as Node2D).global_position):
				rpc_id(peer_id, "_recibir_vida_red", salud_actual, ruta_fuente, salud_maxima, tipo, critico)

	# Emitir señal si la vida es menor o igual a cero
	if salud_actual <= 0.0:
		muerte.emit(0.0)
		salud_actual = 0.0

	return max(0.0, salud_actual)


## reliable: los NÚMEROS flotantes de daño salen del delta entre dos réplicas
## consecutivas, así que un paquete perdido era un número que nunca aparecía
## (o dos golpes seguidos mostrados como uno solo con la suma). Es un paquete
## por golpe real: la fiabilidad cuesta poco.
## No emite "muerte" a propósito: la reacción del cliente ya la manejan
## Enemigo.desvanecer_replica y el flujo de muerte del jugador.
##
## maxima: la vida MÁXIMA del servidor viaja en cada réplica: al subir de
## nivel crece solo en el servidor (ver ExperienciaComponente), y el clamp con
## la máxima vieja del cliente recortaba el valor nuevo.
@rpc("authority", "reliable")
func _recibir_vida_red(valor: float, ruta_fuente: String = "", maxima: float = -1.0,
		tipo: int = Enums.Habilidad.TipoDano.FISICO, critico: bool = false) -> void:
	if maxima > 0.0 and not is_equal_approx(maxima, salud_maxima):
		salud_maxima = maxima
	# El número de daño del cliente sale de ACÁ (el delta real ya replicado),
	# no del cálculo local de cada habilidad: ese corre como predicción visual
	# (ver HabilidadBase.activar()) con su propio randf() de crítico, y cada
	# peer sacaba un número distinto para el mismo golpe. Por eso las
	# habilidades no emiten su daño_aplicado en un cliente (ver
	# Utils.debe_mostrar_dano_local()) y acá se emite el único número real.
	var valor_clamp := clampf(valor, 0.0, salud_maxima)
	if valor_clamp < salud_actual:
		var delta := salud_actual - valor_clamp
		# El atacante llega como ruta de nodo: mobs y jugadores tienen el mismo
		# path en todos los peers, así que se resuelve al nodo local.
		var fuente: Node = get_node_or_null(ruta_fuente) if ruta_fuente != "" else null
		BusEventos.daño_aplicado.emit(get_parent(), delta, fuente, tipo, critico)
		# Nombre del atacante SIEMPRE como texto, para el log de Actividad
		# Reciente. Si el nodo no existe en este peer (un mob que existe en el
		# servidor pero no acá), se saca el nombre de la ruta y se marca como
		# invisible. "???" queda solo para ruta vacía (fuente ya liberada o daño
		# ambiental).
		var nombre_fuente := "???"
		if fuente != null:
			nombre_fuente = Utils.nombre_visible(fuente)
		elif ruta_fuente != "":
			nombre_fuente = "%s [invisible]" % ruta_fuente.get_file()
			# Autocuración: pedirle al servidor los datos de ese nodo para
			# instanciar la réplica que faltó (ver _pedir_resync_nodo_red).
			rpc_id(1, "_pedir_resync_nodo_red", ruta_fuente)
		BusEventos.daño_replicado.emit(get_parent(), delta, nombre_fuente)
	elif valor_clamp > salud_actual:
		# Mismo criterio para la curación: el "+N" del cliente sale de ACÁ.
		# agregar_vida() emite el suyo en el servidor y sin red.
		BusEventos.curacion_aplicada.emit(get_parent(), valor_clamp - salud_actual)
	salud_actual = valor_clamp
	cambio_valor_vida.emit(salud_actual)


## CLIENTE → SERVIDOR: "no tengo el nodo en ruta_fuente" (un mob que pegó
## desde el servidor pero nunca se replicó acá). El servidor resuelve la ruta
## en SU árbol y, si el nodo sigue vivo, le manda lo necesario para
## reconstruirlo solo a quien preguntó.
@rpc("any_peer", "reliable")
func _pedir_resync_nodo_red(ruta_nodo: String) -> void:
	if not multiplayer.is_server():
		return
	var nodo := get_tree().root.get_node_or_null(ruta_nodo)
	if nodo == null or not (nodo is Node2D):
		return
	var padre := nodo.get_parent()
	if padre == null:
		return
	var escena_base: String = (nodo.scene_file_path if nodo.scene_file_path != "" \
		else (nodo.get_owner().scene_file_path if nodo.get_owner() else ""))
	if escena_base == "":
		return
	rpc_id(multiplayer.get_remote_sender_id(), "_recibir_resync_nodo_red",
		str(padre.get_path()), escena_base, String(nodo.name), (nodo as Node2D).global_position)


## SERVIDOR → CLIENTE (solo a quien preguntó): instancia la réplica que le
## faltaba, con el mismo nombre bajo el mismo padre que en el servidor, así los
## RPC por ruta le empiezan a llegar. Idempotente, por si dos golpes seguidos
## dispararon el mismo pedido.
@rpc("authority", "reliable")
func _recibir_resync_nodo_red(ruta_padre: String, escena_ruta: String, nombre: String, posicion: Vector2) -> void:
	var padre := get_tree().root.get_node_or_null(ruta_padre)
	if padre == null or padre.has_node(nombre):
		return
	var escena := load(escena_ruta) as PackedScene
	if escena == null:
		return
	var nodo := escena.instantiate()
	nodo.name = nombre
	padre.add_child(nodo)
	if nodo is Node2D:
		(nodo as Node2D).global_position = posicion
