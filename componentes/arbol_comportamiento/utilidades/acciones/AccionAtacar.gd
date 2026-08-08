# =============================================================================
# AccionAtacar.gd  (Acción)
#
# Combate a distancia de ataque: orienta al agente hacia el objetivo y usa
# el SelectorHabilidades HIJO para elegir/ejecutar habilidades (rango,
# cooldown y prioridad los resuelve él). Tras cada habilidad, pausa de
# recuperación. Si hay una habilidad libre pero fuera de rango, se acerca.
#
# Reemplaza a EstadoAtacar sin banderas: la recuperación es un timestamp
# interno y el "ataque largo en curso" (carga) se respeta leyendo la clave
# "ataque_en_curso" que la propia HabilidadCarga escribe en la memoria.
#
# ESTRUCTURA DE ESCENA:
#   Atacar (AccionAtacar)
#   └─ SelectorHabilidades   ← hijo directo (recibe la memoria automáticamente)
#
# RETORNA:
#   EXITOSO  → di un paso de combate (atacando, recuperando o acercándome).
#              (por paso: la rama de huida puede interrumpir en cada tick)
#   FALLIDO  → sin objetivo válido o fuera de distancia máxima
#              (el Selector raíz caerá en AccionPerseguir).
#
# MEMORIA:
#   lee "agente", "componente_movimiento", "objetivo", "ataque_en_curso"
# =============================================================================
class_name AccionAtacar
extends Accion

@export_group("Configuración Ataque")
## Distancia máxima para combatir; más lejos → FALLIDO (perseguir).
## Debe ser >= al rango máximo de tus habilidades.
@export var distancia_maxima_ataque: float = 200.0
## Si es true, IGNORA distancia_maxima_ataque y usa el mayor rango_maximo de
## las habilidades del SelectorHabilidades hijo. Así el alcance vive en UN
## solo sitio (el .tres de la habilidad) y subirlo ahí basta.
@export var usar_rango_de_habilidades: bool = false
## Velocidad al acercarse para entrar en rango de una habilidad libre.
@export var velocidad_aproximacion: float = 130.0
## Segundos de pausa tras ejecutar cualquier habilidad.
@export var duracion_recuperacion: float = 3.0
## Segundos entre intentos de selección de habilidad.
@export var intervalo_entre_intentos: float = 1.0
## Segundos que debe pasar "apuntando" hacia el objetivo (sin un giro brusco
## de dirección) antes de poder disparar una habilidad. Sin esto, el mob
## gira y dispara EN EL MISMO tick del árbol (10/s) apenas adquiere o
## reorienta hacia el objetivo — visualmente "no mira, solo tira la
## habilidad". Con esta ventana, direccion_mirada tiene un par de ticks para
## rotar de verdad antes del primer disparo.
@export var duracion_apuntado: float = 0.25
## Ángulo (rad) de cambio de dirección que reinicia la ventana de apuntado
## (objetivo se movió mucho / cambió de lado — hay que reapuntar de nuevo).
const _UMBRAL_CAMBIO_DIRECCION_APUNTADO := 0.35  # ~20°

@export_group("Reposicionamiento en recuperación")
## Tras atacar, en vez de quedarse plantado durante toda la recuperación, se
## desplaza a un costado del objetivo MANTENIENDO la distancia que ya
## tenía (un mob a distancia como el Arquero conserva su rango de disparo;
## uno cuerpo a cuerpo, su cercanía) — pedido del usuario: "se queda quieto
## esperando los golpes, se me hace muy fácil", y de paso se sentía "muerto"
## parado ahí. false = desactivado, vuelve a quedarse quieto como antes.
@export var reposicionarse_en_recuperacion: bool = true
## Cuánto puede variar el ángulo alrededor del objetivo, a cada lado de "la
## dirección opuesta a donde está parado ahora mismo" (así no siempre
## retrocede derecho para atrás ni siempre hacia el mismo lado).
@export var dispersion_angulo_reposicionamiento_grados: float = 70.0
## Velocidad al reposicionarse — más lenta que perseguir, no es una huida.
@export var velocidad_reposicionamiento: float = 130.0
## Distancia a la que el punto de reposicionamiento se considera alcanzado.
const _RADIO_LLEGADA_REPOSICIONAMIENTO := 10.0
## Radio de respaldo si agente y objetivo terminaran en la MISMA posición
## (no debería pasar en combate real, pero evita un from_angle degenerado).
const _DISTANCIA_MINIMA_REPOSICIONAMIENTO := 40.0
## Al llegar al punto elegido, cuánto espera parado antes de elegir OTRO y
## seguir moviéndose — sin esto, apenas llegaba (rápido, sobre todo a la
## velocidad actual) se quedaba plantado el resto de la ventana de
## recuperación, que es exactamente lo que se quería evitar (reportado por
## el usuario: "el lobo después de pegar se queda quieto en el puesto").
const _PAUSA_ENTRE_REPOSICIONAMIENTOS := 0.4

var _selector_habilidades: SelectorHabilidades
var _fin_recuperacion: float = 0.0
var _proximo_intento: float = 0.0
var _inicio_apuntado: float = -INF
var _direccion_apuntado: Vector2 = Vector2.ZERO
var _destino_reposicionamiento: Vector2 = Vector2.ZERO
var _tiene_destino_reposicionamiento: bool = false
var _ataque_en_curso_anterior: bool = false
var _fin_pausa_reposicionamiento: float = 0.0


func _on_inicializar() -> void:
	for hijo in get_children():
		if hijo is SelectorHabilidades:
			_selector_habilidades = hijo
			return
	push_warning("AccionAtacar '%s': necesita un SelectorHabilidades hijo." % nombre_nodo)


func _on_ejecutar() -> Estado:
	var agente := _memoria.obtener("agente") as Node2D
	var movimiento: MovimientoComponente = _memoria.obtener("componente_movimiento")
	# En red: si el jugador-objetivo se desconecta a mitad de combate, su
	# nodo se libera con queue_free() (ver ServidorDedicado._al_desconectar)
	# pero la memoria del BT puede seguir apuntando a esa referencia ya
	# liberada — castear un Object liberado con "as" revienta con "Trying
	# to cast a freed object", por eso hay que validar ANTES de castear.
	var objetivo_raw = _memoria.obtener("objetivo")
	if not agente or not movimiento or not _selector_habilidades:
		return Estado.FALLIDO
	if not is_instance_valid(objetivo_raw):
		return Estado.FALLIDO
	# Un jugador muerto sigue existiendo como nodo (reaparece en el mismo
	# lugar, no se libera) — sin este chequeo, los mobs seguían atacando
	# "lo que queda" de un jugador ya muerto porque is_instance_valid()
	# sigue dando true. Se limpia el objetivo para que, si reaparece cerca,
	# haga falta redetectarlo por visión — no queda "enganchado" al mismo
	# cadáver para siempre.
	# Muerto U OCULTO: en los dos casos deja de ser objetivo. Sin el corte por
	# camuflaje, un mob que ya te tenía fichado seguía persiguiendo tu última
	# posición conocida unos segundos, o seguía pegándote si te tenía a
	# distancia — y el camuflaje no serviría para lo único que se hizo:
	# despegarte de una pelea.
	if _objetivo_perdido(objetivo_raw):
		_memoria.establecer("objetivo", null)
		_memoria.establecer("jugador_detectado", false)
		return Estado.FALLIDO
	var objetivo := objetivo_raw as Node2D

	var ahora := Time.get_ticks_msec() / 1000.0

	# Ataque largo en curso (p. ej. la carga conduce el movimiento ella misma):
	# soltar el control del cuerpo y esperar a que termine. La mirada NO se
	# actualiza acá: durante el dash del lobo, seguir apuntando al jugador
	# haría que al rebasarlo quedara "mirando hacia atrás" en pleno vuelo —
	# la mirada queda congelada en la dirección con la que arrancó el
	# ataque, que es lo natural para una embestida.
	if _memoria.obtener("ataque_en_curso", false):
		movimiento.liberar_comando()
		_ataque_en_curso_anterior = true
		return Estado.EXITOSO
	elif _ataque_en_curso_anterior:
		# Una habilidad de larga duración que conduce el cuerpo ella misma
		# (p. ej. HabilidadCarga: PREPARACION + DASH) recién soltó el
		# control. _fin_recuperacion se había fijado ni bien se DISPARÓ la
		# habilidad, contando duracion_recuperacion desde ESE instante — si
		# la preparación+dash duran menos que eso (lo normal), sobraba un
		# resto de la ventana original y el reposicionamiento arrancaba de
		# golpe apenas terminaba el dash, como si seguiera empujando al mob
		# (reportado por el usuario: "cuando usa el dash, el reposicionamiento
		# lo hace mover, no debería moverlo"). Arrancar la recuperación RECIÉN
		# ACÁ, desde la posición real post-dash, da el mismo respiro que
		# cualquier otra habilidad, sin el resto fantasma.
		_ataque_en_curso_anterior = false
		_fin_recuperacion = ahora + duracion_recuperacion
		_tiene_destino_reposicionamiento = false
		_fin_pausa_reposicionamiento = 0.0

	# Orientar hacia el objetivo (las habilidades disparan en esta dirección).
	# "direccion_mirada" (no "direccion"): esta última la pisa cada fotograma
	# MovimientoComponente con la dirección REAL de la ruta al acercarse
	# (comandar_destino más abajo), que al rodear un obstáculo puede apuntar
	# de costado o hacia atrás respecto al jugador — de ahí el parpadeo y el
	# "caminar de espaldas mirando al jugador" reportado antes de este fix.
	#
	# ANTES del corte de recuperación a propósito: ese return temprano
	# dejaba la mirada congelada durante los ~3s de recuperación entre
	# ataques — si el jugador rodeaba al mob en ese lapso, el mob seguía
	# "mirando" hacia donde el jugador ESTABA cuando atacó por última vez.
	var direccion := (objetivo.global_position - agente.global_position).normalized()
	if "direccion_mirada" in agente:
		agente.set("direccion_mirada", direccion)

	# Reiniciar la ventana de apuntado si es la primera vez que apunta a
	# este objetivo o si giró bruscamente (objetivo se movió mucho).
	if _direccion_apuntado == Vector2.ZERO \
			or direccion.angle_to(_direccion_apuntado) > _UMBRAL_CAMBIO_DIRECCION_APUNTADO:
		_inicio_apuntado = ahora
		_direccion_apuntado = direccion

	# Recuperación post-habilidad: reposicionarse a un costado del objetivo
	# en vez de quedarse plantado (ver _elegir_destino_reposicionamiento) —
	# al llegar, una pausa corta y elige OTRO punto, repitiendo mientras dure
	# la recuperación (sin esto, con la velocidad actual llegaba casi de
	# inmediato y se quedaba plantado el resto de la ventana — reportado por
	# el usuario). reposicionarse_en_recuperacion = false vuelve a quedarse
	# quieto, el comportamiento de siempre.
	if ahora < _fin_recuperacion:
		if reposicionarse_en_recuperacion:
			if not _tiene_destino_reposicionamiento:
				_elegir_destino_reposicionamiento(agente, objetivo)
			if agente.global_position.distance_to(_destino_reposicionamiento) > _RADIO_LLEGADA_REPOSICIONAMIENTO:
				movimiento.comandar_destino(_destino_reposicionamiento, velocidad_reposicionamiento)
				_fin_pausa_reposicionamiento = 0.0
			elif _fin_pausa_reposicionamiento == 0.0:
				movimiento.detener()
				_fin_pausa_reposicionamiento = ahora + _PAUSA_ENTRE_REPOSICIONAMIENTOS
			elif ahora >= _fin_pausa_reposicionamiento:
				_elegir_destino_reposicionamiento(agente, objetivo)
				_fin_pausa_reposicionamiento = 0.0
			else:
				movimiento.detener()
		else:
			movimiento.detener()
		return Estado.EXITOSO

	var distancia := agente.global_position.distance_to(objetivo.global_position)
	if distancia > _distancia_maxima():
		return Estado.FALLIDO

	# Intentar habilidad cada N segundos — pero solo si ya lleva
	# duracion_apuntado segundos apuntando establemente al objetivo.
	if ahora >= _proximo_intento and (ahora - _inicio_apuntado) >= duracion_apuntado:
		_proximo_intento = ahora + intervalo_entre_intentos
		if _selector_habilidades.ejecutar() == Estado.EXITOSO:
			_fin_recuperacion = ahora + duracion_recuperacion
			_tiene_destino_reposicionamiento = false
			movimiento.detener()
			return Estado.EXITOSO

	# Sin habilidad ejecutada: acercarse solo si sirve de algo.
	if _selector_habilidades.hay_habilidades_fuera_de_rango(distancia, agente):
		movimiento.comandar_destino(objetivo.global_position, velocidad_aproximacion)
	else:
		movimiento.detener()
	return Estado.EXITOSO


## OJO: acá NO se limpia direccion_mirada (antes se hacía en _on_salir):
## esta acción retorna EXITOSO POR TICK (nunca EN_EJECUCION), y NodoBT
## dispara _on_salir en CADA tick que no termina EN_EJECUCION — así que la
## mirada se borraba en el mismo tick en que se seteaba, y para cuando
## Enemigo._physics_process la leía siempre estaba en ZERO (el mob nunca
## miraba de verdad al objetivo, ni siquiera en un solo jugador). La
## limpieza vive ahora en AccionDeambular (la rama de "no combate"), que
## es cuando de verdad corresponde soltar la mirada.
func _on_reiniciar() -> void:
	super._on_reiniciar()
	_fin_recuperacion = 0.0
	_proximo_intento = 0.0
	_inicio_apuntado = -INF
	_direccion_apuntado = Vector2.ZERO
	_tiene_destino_reposicionamiento = false
	_ataque_en_curso_anterior = false
	_fin_pausa_reposicionamiento = 0.0


## Punto a la MISMA distancia del objetivo que el agente ya tenía (nunca una
## distancia fija: un mob a rango como el Arquero debe conservar SU rango de
## disparo, no que lo jale a una cercanía de melee — reportado al probar
## esto la primera vez), rotado al azar respecto de "la dirección opuesta a
## donde está parado ahora mismo" (dispersion_angulo_reposicionamiento_grados
## a cada lado) — así no siempre retrocede derecho para atrás ni siempre
## hacia el mismo lado. Elegido al entrar en recuperación y de nuevo cada vez
## que llega y pasa la pausa (ver _on_ejecutar) — no recalculado cada tick
## mientras está en camino, o moverse hacia un objetivo que se mueve por su
## cuenta tironearía sin llegar nunca.
func _elegir_destino_reposicionamiento(agente: Node2D, objetivo: Node2D) -> void:
	var vector_actual := agente.global_position - objetivo.global_position
	var distancia_actual := vector_actual.length()
	if distancia_actual < 1.0:
		vector_actual = Vector2.RIGHT
		distancia_actual = _DISTANCIA_MINIMA_REPOSICIONAMIENTO
	var dispersion := deg_to_rad(dispersion_angulo_reposicionamiento_grados)
	# El giro nunca es casi-cero: a un mob cuerpo a cuerpo (radio de órbita
	# chico) un ángulo mínimo daría una cuerda más corta que el radio de
	# llegada, y el destino quedaría "ya alcanzado" sin moverse ni un
	# píxel — justo lo que se quería evitar. Por eso la MAGNITUD del giro
	# se sortea entre la mitad y el máximo de la dispersión (nunca cerca
	# de 0), y el lado (izquierda/derecha) sí es al azar.
	var magnitud := randf_range(dispersion * 0.5, dispersion)
	if randf() < 0.5:
		magnitud = -magnitud
	var angulo := vector_actual.angle() + magnitud
	_destino_reposicionamiento = objetivo.global_position + Vector2.from_angle(angulo) * distancia_actual
	_tiene_destino_reposicionamiento = true


func _distancia_maxima() -> float:
	if not usar_rango_de_habilidades or _selector_habilidades == null:
		return distancia_maxima_ataque
	var mayor := 0.0
	for habilidad: HabilidadBT in _selector_habilidades.habilidades:
		if habilidad.rango_maximo < 0.0:
			return INF  # -1 = sin límite de distancia.
		mayor = maxf(mayor, habilidad.rango_maximo)
	return mayor if mayor > 0.0 else distancia_maxima_ataque


## true si el objetivo dejó de contar: muerto (sigue siendo un nodo válido
## porque reaparece, no se libera) u oculto (ver CamuflajeComponente).
func _objetivo_perdido(objetivo) -> bool:
	if "_muerto" in objetivo and objetivo.get("_muerto"):
		return true
	# Por nombre de nodo, no por tipo: ver la nota en
	# VisionComponente._es_objetivo_valido sobre por qué no se referencia la
	# clase CamuflajeComponente desde acá.
	var camuflaje = objetivo.get_node_or_null("CamuflajeComponente")
	return camuflaje != null and camuflaje.esta_activo()
