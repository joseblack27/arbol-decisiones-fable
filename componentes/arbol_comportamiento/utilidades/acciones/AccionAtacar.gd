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
## Distancia a la que apunta mientras se acerca (nunca el centro exacto del
## objetivo): un mob encima del jugador casi no le pega, porque el golpe se
## coloca por DELANTE del propio mob.
## OJO: tiene que quedar BIEN por debajo del rango_maximo real de la habilidad
## (donde el mob se frena, ver hay_habilidades_fuera_de_rango). Con un margen
## chico, lo que falta cerrar puede caer bajo MovimientoComponente.
## MARGEN_DESTINO (6 px) sin haber entrado en rango, y comandar_destino() no
## hace nada: el mob queda congelado (p. ej. rango_maximo 25 con este valor en
## 22 lo trababa a 26 px). Por eso los mobs con este valor en 50 usan
## rango_maximo 70.
@export var distancia_minima_acercamiento: float = 50.0
## Segundos de pausa tras ejecutar cualquier habilidad.
@export var duracion_recuperacion: float = 3.0
## Segundos entre intentos de selección de habilidad.
@export var intervalo_entre_intentos: float = 1.0
## Segundos que debe pasar "apuntando" hacia el objetivo (sin un giro brusco)
## antes de poder disparar. Sin esto, el mob gira y dispara en el mismo tick
## del árbol: se ve como que "no mira, solo tira la habilidad".
@export var duracion_apuntado: float = 0.25
## Ángulo (rad) de cambio de dirección que reinicia la ventana de apuntado
## (objetivo se movió mucho / cambió de lado — hay que reapuntar de nuevo).
const _UMBRAL_CAMBIO_DIRECCION_APUNTADO := 0.35  # ~20°

@export_group("Reposicionamiento en recuperación")
## Tras atacar, en vez de quedarse plantado toda la recuperación, se desplaza
## a un costado del objetivo MANTENIENDO la distancia que ya tenía (un Arquero
## conserva su rango de disparo; uno cuerpo a cuerpo, su cercanía): quieto era
## demasiado fácil de pegar. false = se queda quieto.
@export var reposicionarse_en_recuperacion: bool = true
## Cuánto puede variar el ángulo alrededor del objetivo, a cada lado de "la
## dirección opuesta a donde está parado ahora mismo" (así no siempre
## retrocede derecho para atrás ni siempre hacia el mismo lado).
@export var dispersion_angulo_reposicionamiento_grados: float = 70.0
## Velocidad al reposicionarse — más lenta que perseguir, no es una huida.
@export var velocidad_reposicionamiento: float = 130.0
## Distancia a la que el punto de reposicionamiento se considera alcanzado.
const _RADIO_LLEGADA_REPOSICIONAMIENTO := 10.0
## Al llegar al punto elegido, cuánto espera parado antes de elegir OTRO y
## seguir moviéndose; sin esto, llegaba rápido y se quedaba plantado el resto
## de la recuperación.
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
	# En red, si el jugador-objetivo se desconecta, su nodo se libera pero la
	# memoria del BT puede seguir apuntándolo, y castear un Object liberado con
	# "as" revienta: validar ANTES de castear.
	var objetivo_raw = _memoria.obtener("objetivo")
	if not agente or not movimiento or not _selector_habilidades:
		return Estado.FALLIDO
	if not is_instance_valid(objetivo_raw):
		return Estado.FALLIDO
	# Muerto (sigue existiendo como nodo, porque reaparece) u OCULTO: en los
	# dos casos deja de ser objetivo y se limpia, así haga falta redetectarlo
	# por visión. Sin el corte por camuflaje, un mob que ya lo tenía fichado
	# seguía persiguiéndolo o pegándole, y el camuflaje no serviría para
	# despegarse de una pelea.
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
		# Una habilidad que conduce el cuerpo ella misma (p. ej. HabilidadCarga:
		# preparación + dash) recién soltó el control. _fin_recuperacion se fijó
		# al DISPARARLA, así que sobraba un resto de la ventana y el
		# reposicionamiento arrancaba apenas terminaba el dash, como si siguiera
		# empujando al mob. La recuperación arranca RECIÉN ACÁ, desde la posición
		# real post-dash.
		_ataque_en_curso_anterior = false
		_fin_recuperacion = ahora + duracion_recuperacion
		_tiene_destino_reposicionamiento = false
		_fin_pausa_reposicionamiento = 0.0

	# Orientar hacia el objetivo (las habilidades disparan en esta dirección).
	# "direccion_mirada" y no "direccion": esta última la pisa cada fotograma
	# MovimientoComponente con la dirección REAL de la ruta, que al rodear un
	# obstáculo puede apuntar de costado o hacia atrás respecto al jugador.
	#
	# Va ANTES del corte de recuperación a propósito: si no, la mirada queda
	# congelada los ~3 s de recuperación mientras el jugador lo rodea.
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
	# en vez de quedarse plantado (ver _elegir_destino_reposicionamiento). Al
	# llegar, una pausa corta y elige OTRO punto, mientras dure la
	# recuperación.
	if ahora < _fin_recuperacion:
		if _corregir_si_demasiado_cerca(agente, objetivo, movimiento):
			return Estado.EXITOSO
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
	if _corregir_si_demasiado_cerca(agente, objetivo, movimiento):
		return Estado.EXITOSO

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
		movimiento.comandar_destino(_punto_de_acercamiento(agente, objetivo), velocidad_aproximacion)
	else:
		movimiento.detener()
	return Estado.EXITOSO


## Punto al que se acerca — nunca el centro exacto del objetivo, se queda a
## distancia_minima_acercamiento del lado por el que ya viene acercándose
## (ver el @export de arriba para el motivo). Mismo respaldo por distancia
## casi nula que ya usa _elegir_destino_reposicionamiento más abajo.
func _punto_de_acercamiento(agente: Node2D, objetivo: Node2D) -> Vector2:
	var hacia_agente := agente.global_position - objetivo.global_position
	if hacia_agente.length() < 1.0:
		hacia_agente = Vector2.RIGHT
	return objetivo.global_position + hacia_agente.normalized() * distancia_minima_acercamiento


## Cuánto más allá del piso apunta la corrección, NUNCA justo al piso: el
## último tramo cae bajo MovimientoComponente.MARGEN_DESTINO (6 px) y el mob
## deja de moverse antes de cruzarlo, congelado sin reposicionar ni atacar.
## Mismo motivo que el margen entre rango_maximo y
## distancia_minima_acercamiento.
const _MARGEN_CORRECCION_CERCANIA := 15.0

## Corrección dura, chequeada CADA tick: si la distancia REAL ya cayó por
## debajo del piso, manda a alejarse derecho y devuelve true (el llamador corta
## ahí). Sin este chequeo, un tick de más al acercarse deja al mob más cerca de
## lo pensado, y como el próximo ciclo "preserva la distancia actual", se iría
## acercando ciclo tras ciclo.
func _corregir_si_demasiado_cerca(agente: Node2D, objetivo: Node2D, movimiento: MovimientoComponente) -> bool:
	var lejos := agente.global_position - objetivo.global_position
	if lejos.length() >= distancia_minima_acercamiento:
		return false
	if lejos.length() < 1.0:
		lejos = Vector2.RIGHT
	var destino_seguro := objetivo.global_position \
		+ lejos.normalized() * (distancia_minima_acercamiento + _MARGEN_CORRECCION_CERCANIA)
	movimiento.comandar_destino(destino_seguro, velocidad_aproximacion)
	_tiene_destino_reposicionamiento = false
	return true


## OJO: acá NO se limpia direccion_mirada. Esta acción retorna EXITOSO POR TICK
## (nunca EN_EJECUCION) y NodoBT dispara _on_salir en cada uno, así que
## limpiarla acá la borraría en el mismo tick en que se fija. La limpieza vive
## en AccionDeambular (la rama de "no combate").
func _on_reiniciar() -> void:
	super._on_reiniciar()
	_fin_recuperacion = 0.0
	_proximo_intento = 0.0
	_inicio_apuntado = -INF
	_direccion_apuntado = Vector2.ZERO
	_tiene_destino_reposicionamiento = false
	_ataque_en_curso_anterior = false
	_fin_pausa_reposicionamiento = 0.0


## Punto a la MISMA distancia del objetivo que el agente ya tenía (un Arquero
## conserva SU rango de disparo), rotado al azar respecto de "la dirección
## opuesta a donde está parado" (dispersion_angulo_reposicionamiento_grados a
## cada lado), para que no siempre retroceda derecho ni hacia el mismo lado. Se
## elige al entrar en recuperación y cada vez que llega y pasa la pausa, no en
## cada tick: recalcularlo con el objetivo moviéndose tironearía sin llegar.
func _elegir_destino_reposicionamiento(agente: Node2D, objetivo: Node2D) -> void:
	var vector_actual := agente.global_position - objetivo.global_position
	# Piso en distancia_minima_acercamiento + _MARGEN_CORRECCION_CERCANIA:
	# - Sin piso, si el acercamiento se pasó del rango en un tick, ese "de más"
	#   quedaba como la nueva distancia a mantener y el mob se acercaba más en
	#   cada ataque (medido: 16 → 10 px en cinco ciclos).
	# - Sin el margen extra, la cuerda entre dos puntos del círculo del piso pasa
	#   por DENTRO del círculo, dispara _corregir_si_demasiado_cerca a mitad de
	#   camino y el mob queda oscilando sin avanzar.
	var distancia_actual := maxf(vector_actual.length(), distancia_minima_acercamiento + _MARGEN_CORRECCION_CERCANIA)
	if vector_actual.length() < 1.0:
		vector_actual = Vector2.RIGHT
	var dispersion := deg_to_rad(dispersion_angulo_reposicionamiento_grados)
	# El giro nunca es casi cero: a un mob cuerpo a cuerpo (órbita chica) un
	# ángulo mínimo daría un destino "ya alcanzado". La magnitud se sortea
	# entre la mitad y el máximo de la dispersión; el lado, al azar.
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
