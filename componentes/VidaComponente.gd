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

# --- Inicialización y Estado ---

func _ready():
	salud_actual = salud_maxima


func _process(delta: float) -> void:
	# Regeneración por ticks — SOLO donde el cálculo es el real (servidor o
	# un jugador); al cliente le llega por la réplica de agregar_vida(). Los
	# muertos no regeneran (a 0 de vida se espera muerte/reaparición, no
	# resucitar de a 2 puntos).
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

## Fija la vida directo a un valor conocido (p. ej. al cargar una partida
## guardada) — a diferencia de quitar_vida()/agregar_vida(), no dispara la
## señal "muerte" aunque el valor sea 0 (cargar una partida nunca debería
## matar a nadie en el acto).
func restaurar_vida(valor: float) -> void:
	salud_actual = clampf(valor, 0.0, salud_maxima)
	cambio_valor_vida.emit(salud_actual)
	# Mismo criterio que quitar/agregar: si esto corre en el servidor (p. ej.
	# al cargar una partida guardada), el cliente tiene que enterarse.
	if Utils.en_red() and multiplayer.is_server():
		rpc("_recibir_vida_red", salud_actual)


## Agrega vida al agente. Retorna el exceso de vida (si se sobrepasa el máximo).
func agregar_vida(cantidad: float) -> float:
	# Mismo gate que quitar_vida(): en red, solo el SERVIDOR decide cuánta
	# vida hay de verdad. Sin esto, curar (poción, la cura-a-100 al morir en
	# Jugador.manejar_muerte) nunca llegaba al cliente — la barra se quedaba
	# clavada en el valor bajo hasta el próximo golpe, que la hacía saltar
	# de golpe a un número sin sentido.
	if Utils.en_red() and not multiplayer.is_server():
		return 0.0
	if cantidad <= 0:
		return 0.0

	var vida_anterior = salud_actual
	salud_actual = min(salud_actual + cantidad, salud_maxima)


	cambio_valor_vida.emit(salud_actual)
	if Utils.en_red() and multiplayer.is_server():
		rpc("_recibir_vida_red", salud_actual)

	# Retorna la vida que se perdió al alcanzar el máximo
	return max(0.0, (vida_anterior + cantidad) - salud_maxima)

## Quita vida al agente. Retorna la vida restante (si es > 0).
## fuente (opcional) — quién infligió el daño: solo se usa para replicarle
## al cliente QUIÉN pegó (ver _recibir_vida_red), así el log de Actividad
## Reciente puede decir "EnemigoLobo hizo X daño a ..." en vez de "???".
func quitar_vida(cantidad: float, fuente: Node = null) -> float:
	# Fase 3 del plan de multijugador: en red, solo el SERVIDOR decide
	# cuánta vida queda — es el punto central por el que pasa TODO el daño
	# (Proyectil, Arañazo, GolpeBasico, AreaEfecto, HabilidadCarga...), así
	# que gatearlo acá cubre a todas las habilidades sin tocar cada una.
	# Sin multiplayer activo (un solo jugador, de siempre) esto no cambia nada.
	if Utils.en_red() and not multiplayer.is_server():
		return salud_actual
	if cantidad <= 0:
		return salud_actual
	
	salud_actual -= cantidad


	cambio_valor_vida.emit(salud_actual)
	# El número flotante de daño NO se muestra desde aquí: este componente
	# solo gestiona salud. Quien inflige el daño ya emite
	# BusEventos.daño_aplicado (ver Proyectil.gd, Arañazo.gd, etc.), y
	# GestorNumerosDano (autoload de presentación pura) es quien escucha esa
	# señal y dibuja el número — así "cuánta vida queda" y "cómo se ve" están
	# completamente separados.

	# En red: la vida NUNCA se replicaba — el cliente veía el golpe (efecto
	# visual, ver HabilidadBase) pero la barra de vida se quedaba clavada
	# en el valor inicial, porque su propia copia local de VidaComponente
	# jamás recibía este quitar_vida() de verdad (el gate de arriba lo
	# bloquea ahí). Avisarle al cliente el valor real para que la barra
	# (BarraVidaEnergiaComponente, escucha cambio_valor_vida) sí se mueva.
	if Utils.en_red() and multiplayer.is_server():
		# La ruta del atacante viaja como String: los mobs/jugadores existen
		# con el MISMO path en todos los peers (así funcionan ya todos los
		# RPCs por nodo), así que el cliente puede resolverla localmente.
		var ruta_fuente := str(fuente.get_path()) if is_instance_valid(fuente) else ""
		rpc("_recibir_vida_red", salud_actual, ruta_fuente)

	# Emitir señal si la vida es menor o igual a cero
	if salud_actual <= 0.0:
		muerte.emit(0.0)
		salud_actual = 0.0

	return max(0.0, salud_actual)


## unreliable_ordered: si se pierde un paquete no importa, el siguiente
## golpe (o la réplica de "muerte" ya vía despawn/RPC dedicado) lo corrige.
## No emite "muerte" acá a propósito: eso ya lo maneja Enemigo._despawn_red
## / el flujo de muerte del jugador — emitirlo también acá duplicaría la
## reacción (animación de muerte, etc.) del lado del cliente.
@rpc("authority", "unreliable_ordered")
func _recibir_vida_red(valor: float, ruta_fuente: String = "") -> void:
	# El número de daño en pantalla, del lado del cliente, sale de ACÁ (el
	# delta real ya replicado) — no del cálculo local de cada habilidad
	# (Arañazo/Proyectil/GolpeBasico/etc, que corren en el cliente como
	# predicción visual pura, ver HabilidadBase.activar()). Ese cálculo
	# local usa AtributosComponente.calcular_pipeline(), que tira su propio
	# randf() de crítico — cada peer (atacante, espectadores, servidor)
	# sacaba un número DISTINTO para el MISMO golpe, y ninguno coincidía
	# con la vida que de verdad bajaba. Por eso cada habilidad SUPRIME su
	# propio BusEventos.daño_aplicado en cliente (ver Utils.debe_mostrar_
	# daño_local()) y acá se emite el único número real.
	var valor_clamp := clampf(valor, 0.0, salud_maxima)
	if valor_clamp < salud_actual:
		var delta := salud_actual - valor_clamp
		# El atacante llega como ruta de nodo (String) desde el servidor:
		# mobs y jugadores existen con el mismo path en todos los peers, así
		# que acá se resuelve al nodo local.
		var fuente: Node = get_node_or_null(ruta_fuente) if ruta_fuente != "" else null
		BusEventos.daño_aplicado.emit(get_parent(), delta, fuente)
		# Nombre del atacante SIEMPRE resoluble como texto, para el log de
		# Actividad Reciente: si el nodo no existe en este peer (¡mob
		# invisible! — existe en el servidor pero acá no), se saca el nombre
		# de la ruta igual y se marca — así el log identifica al fantasma en
		# vez de un "???" mudo. "???" queda solo para ruta vacía (el servidor
		# tampoco sabía quién pegó: fuente ya liberada o daño ambiental).
		var nombre_fuente := "???"
		if fuente != null:
			nombre_fuente = Utils.nombre_visible(fuente)
		elif ruta_fuente != "":
			nombre_fuente = "%s [invisible]" % ruta_fuente.get_file()
		BusEventos.daño_replicado.emit(get_parent(), delta, nombre_fuente)
	salud_actual = valor_clamp
	cambio_valor_vida.emit(salud_actual)
