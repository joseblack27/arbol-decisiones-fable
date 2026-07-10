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
@export var velocidad_aproximacion: float = 60.0
## Segundos de pausa tras ejecutar cualquier habilidad.
@export var duracion_recuperacion: float = 3.0
## Segundos entre intentos de selección de habilidad.
@export var intervalo_entre_intentos: float = 1.0

var _selector_habilidades: SelectorHabilidades
var _fin_recuperacion: float = 0.0
var _proximo_intento: float = 0.0


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
		return Estado.EXITOSO

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

	# Recuperación post-habilidad: quieto.
	if ahora < _fin_recuperacion:
		movimiento.detener()
		return Estado.EXITOSO

	var distancia := agente.global_position.distance_to(objetivo.global_position)
	if distancia > _distancia_maxima():
		return Estado.FALLIDO

	# Intentar habilidad cada N segundos.
	if ahora >= _proximo_intento:
		_proximo_intento = ahora + intervalo_entre_intentos
		if _selector_habilidades.ejecutar() == Estado.EXITOSO:
			_fin_recuperacion = ahora + duracion_recuperacion
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


func _distancia_maxima() -> float:
	if not usar_rango_de_habilidades or _selector_habilidades == null:
		return distancia_maxima_ataque
	var mayor := 0.0
	for habilidad: HabilidadBT in _selector_habilidades.habilidades:
		if habilidad.rango_maximo < 0.0:
			return INF  # -1 = sin límite de distancia.
		mayor = maxf(mayor, habilidad.rango_maximo)
	return mayor if mayor > 0.0 else distancia_maxima_ataque
