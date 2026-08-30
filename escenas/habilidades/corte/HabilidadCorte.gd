class_name HabilidadCorte
extends HabilidadBase
## Definitiva de counter: un tajo en un RECTÁNGULO alargado desde el
## jugador hacia donde apunta el joystick, que además abre una ventana
## corta en la que (a) el jugador queda inmune al daño de área que venga
## de ese lado y (b) los ataques enemigos que hayan quedado dentro del
## rectángulo se destruyen. Pedido explícito del usuario, pensada para
## "hacer counter a habilidades mortales de jefes o enemigos de máxima
## dificultad, o como habilidad de remate".
##
## TRES cosas la separan de cualquier otra habilidad del juego, y cada una
## tiene su plomería propia (ver los archivos citados):
##
## 1. DAÑO VERDADERO — ignora defensa, fortaleza y resistencias elementales
##    del objetivo ("sin importar qué buffos tenga encima... debe recibir
##    el daño completo"). Vía AtributosComponente.calcular_pipeline(...,
##    ignora_defensa=true). La única excepción que SÍ lo para sigue siendo
##    la inmunidad total (VidaComponente._invulnerable_restante), tal cual
##    lo pidió el usuario ("a menos que sea inmunidad") — vive aguas abajo,
##    en quitar_vida(), así que se respeta sola.
##
## 2. PARRY DIRECCIONAL — ver ParryComponente (se crea al vuelo la primera
##    vez, mismo criterio que HabilidadPurga con InmunidadDebuffs). El
##    lanzallamas del enemigo queda cubierto sin nada especial: su daño
##    pasa por Combate.golpear_area() como cualquier otro golpe de área,
##    así que la ventana lo bloquea; y como NO deja ningún nodo en el
##    mundo (es un golpe repetido cada tick, ver HabilidadLanzallamas), no
##    hay nada que cortar y sigue quemando apenas la ventana se cierra —
##    exactamente el caso especial que describió el usuario.
##
## 3. SE LANZA AUNQUE ESTÉS ATURDIDO — "siempre debe estar disponible para
##    lanzarse, sin importar si el jugador está en algún estado alterado".
##    Vía la propiedad ignora_bloqueos, que HabilidadBase.activar(),
##    Jugador._activar_slot() y UIHabilidad._dueño_muerto() consultan por
##    duck typing. MUERTO no cuenta como estado alterado: un muerto no
##    lanza nada (ver esos tres archivos).

@export_group("Corte")
## Largo del tajo (px). Se pisa con alcance_metros del .tres (ver
## aplicar_datos) — "corto-medio y fijo": no depende del poder del
## joystick, estirar más solo apunta, nunca alarga.
@export var largo: float = 160.0
## Ancho del rectángulo (px), repartido a los dos lados de la dirección.
@export var ancho: float = 70.0
## Segundos de parry + de "corta ataques enemigos" tras el tajo.
@export var duracion_ventana: float = 0.5

## Leída por duck typing desde HabilidadBase.activar(), Jugador.
## _activar_slot() y UIHabilidad — ver el punto 3 de la cabecera.
var ignora_bloqueos := true

const MASCARA_OBJETIVOS := 0xFFFFFFFF

## Segundos que le quedan a la ventana activa, y hacia dónde se cortó —
## mientras corre, _process() vuelve a barrer ataques enemigos CADA
## fotograma (ver ese método). Bug real reportado: "estoy dándole a parar
## proyectiles de enemigos y no los detiene" — antes el barrido era una
## foto de un solo instante (el del lanzamiento), así que un proyectil que
## entraba al rectángulo medio segundo después pasaba de largo.
var _ventana_restante: float = 0.0
var _dir_ventana: Vector2 = Vector2.RIGHT

## Visual del "haz" (ver HabilidadCorte.tscn): un Sprite2D con animación de
## fotogramas propia (AnimationPlayer, no AnimacionComponente — esto es un
## efecto de la HABILIDAD, no una pose del jugador; el usuario fue
## explícito en eso). get_node_or_null porque instancias armadas a mano sin
## pasar por el .tscn (pruebas/prueba_habilidad_corte.gd) no tienen estos
## hijos, mismo criterio que _chorro_visual en HabilidadLanzallamas.
##
## "Ancla" (Node2D) es la mitad que mueve EL SCRIPT (posición/rotación/
## escala por largo-ancho, cada lanzamiento); HazVisual es la mitad que
## anima el USUARIO en el AnimationPlayer (frame/position/scale del propio
## sprite, para el efecto de "viaja y crece"). Están separados a propósito:
## HabilidadCorte es un Node plano (no Node2D, no tiene transform propio),
## así que si HazVisual colgara directo de él, la animación escribiéndole
## "position" pisaría el (0,0) del MUNDO en vez de la posición del
## jugador —el bug real que hizo que el haz "no saliera" al agregar esos
## tracks— porque un Node2D sin ancestro CanvasItem no hereda ningún
## offset. Con Ancla en el medio, el script mueve la ancla y la animación
## mueve/escala el sprite relativo a ella; ninguno de los dos pisa al otro.
@onready var _haz_ancla: Node2D = get_node_or_null("Ancla")
@onready var _haz_visual: Sprite2D = get_node_or_null("Ancla/HazVisual")
@onready var _anim_haz: AnimationPlayer = get_node_or_null("AnimationPlayer")

## Tamaño (px) al que el sprite placeholder de HazVisual.tscn quedaría a
## escala 1:1 con largo/ancho por defecto (160x70) — el usuario puede
## dejarlas así si su spritesheet respeta esa proporción, o ajustarlas acá
## a mano una vez mida el arte real, mismo criterio que _LARGO_SPRITE_BASE
## en HabilidadLanzallamas. Se aplica sobre Ancla, no sobre HazVisual (ver
## comentario de arriba), así que se compone con lo que anime el usuario:
## si Corte escala de nivel (largo/ancho más grandes), la animación de
## "viaja y crece" escala junto con el rectángulo real de daño.
## Convención sugerida para el spritesheet (para que combine con el resto
## de efectos del proyecto): el haz nace en el borde IZQUIERDO del frame
## (x=0, junto al jugador) y se extiende hacia la DERECHA (alcance),
## centrado verticalmente en el eje de ancho.
const _LARGO_SPRITE_BASE_HAZ := 160.0
const _ALTO_SPRITE_BASE_HAZ := 70.0
## Duración (seg) que ya tiene programada la animación "default" en el
## .tscn — si duracion_ventana cambia (en el recurso o al escalar de
## nivel), se reescala la velocidad de reproducción para que el haz nunca
## quede mostrándose más/menos tiempo que la ventana real de corte.
const _DURACION_ANIM_BASE_HAZ := 0.5


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Corte"
	tipo_habilidad   = "corte"
	requiere_direccion = true
	if _anim_haz:
		_anim_haz.animation_finished.connect(_al_terminar_anim_haz)
	# Sale EN EL INSTANTE en que se suelta el joystick — pedido del
	# usuario: "se lanza muy lento, quiero que se lance apenas se suelte".
	# Por defecto toda habilidad espera _MARGEN_CONGELAMIENTO_RED (0.5s)
	# con el dueño congelado antes de disparar de verdad, para que la orden
	# de "párate" llegue al servidor antes de que la posición importe (ver
	# HabilidadBase.activar) — eso está pensado para proyectiles, donde
	# nacer unos píxeles adelantado se nota. Acá es al revés: media
	# décima de segundo de retardo mata la habilidad entera, que existe
	# para reaccionar al ataque de un jefe, y además clavarte en el lugar
	# medio segundo es lo último que querés estando aturdido. El hitbox es
	# un rectángulo cuerpo a cuerpo anclado al jugador, así que unos
	# píxeles de diferencia entre cliente y servidor no cambian nada.
	congela_movimiento_en_red = false


func aplicar_datos(d: DatosHabilidad) -> void:
	super.aplicar_datos(d)
	if d.alcance_metros > 0:
		largo = float(d.alcance_metros) * ESCALA_METROS_PIXEL
	if d.radio_golpe > 0.0:
		ancho = d.radio_golpe


## RANGO escala el largo del tajo (ver EscaladoHabilidad/CampoEscalado) —
## sin esto, subirle el nivel a Corte no podría alargarlo nunca.
func _nombre_campo_escalable(campo: Enums.Habilidad.CampoEscalable) -> String:
	if campo == Enums.Habilidad.CampoEscalable.RANGO:
		return "largo"
	if campo == Enums.Habilidad.CampoEscalable.RADIO:
		return "ancho"
	return super._nombre_campo_escalable(campo)


func _ejecutar(direccion: Vector2, _poder: float) -> void:
	if not is_instance_valid(entidad_dueña):
		return
	var origen := entidad_dueña as Node2D
	if origen == null:
		return
	var dir := direccion.normalized() if direccion.length() > 0.1 else Vector2.RIGHT

	_mostrar_indicador(origen, dir)
	_mostrar_haz(origen, dir)
	_abrir_ventana_parry(dir)
	# Abre la ventana de corte en TODOS los peers — ver _process() para el
	# porqué de que el barrido no sea server-only como el daño.
	_ventana_restante = duracion_ventana
	_dir_ventana = dir

	# El DAÑO sí es autoritativo y va UNA sola vez: en un cliente puro
	# quitar_vida() no aplica nada, y repetirlo cada fotograma de la
	# ventana convertiría un tajo de 30-40 en ~60 golpes por segundo.
	if Utils.en_red() and not multiplayer.is_server():
		return
	var golpeados := _golpear(origen, dir)
	_cortar_ataques(origen, dir, golpeados)


## Mientras la ventana está abierta, vuelve a barrer ataques enemigos cada
## fotograma — así se corta también lo que ENTRA al rectángulo después del
## instante del lanzamiento (pedido del usuario, ver _ventana_restante).
##
## Corre en TODOS los peers, a diferencia del daño: los proyectiles de un
## mob existen como COPIA VISUAL LOCAL en cada cliente (ver HabilidadBase.
## _reproducir_visual_red — el nodo del servidor no se replica, cada peer
## crea el suyo). Si solo cortara el servidor, el cliente vería la flecha
## atravesarlo igual (sin recibir daño, porque eso ya lo resolvió el
## servidor) y parecería que el corte no funciona. Cortar la copia local no
## tiene ningún efecto de juego —el daño nunca se decide en el cliente—,
## solo hace que se VEA lo que de verdad pasó.
func _process(delta: float) -> void:
	super._process(delta)
	if _ventana_restante <= 0.0:
		return
	_ventana_restante = maxf(0.0, _ventana_restante - delta)
	if not is_instance_valid(entidad_dueña):
		return
	var origen := entidad_dueña as Node2D
	if origen:
		_cortar_ataques(origen, _dir_ventana, [])


## Cuatro esquinas del rectángulo, en coordenadas LOCALES del jugador y ya
## rotadas hacia "dir" — mismo truco que HabilidadLanzallamas._construir_
## forma_cono(): Combate/las queries usan el global_transform del
## CharacterBody2D, que NO tiene rotación propia, así que un
## RectangleShape2D saldría siempre alineado a los ejes. Con un polígono
## armado a mano el tajo apunta de verdad hacia donde apuntaste.
func _puntos_rectangulo(dir: Vector2) -> PackedVector2Array:
	var lado := dir.orthogonal() * (ancho * 0.5)
	var punta := dir * largo
	return PackedVector2Array([-lado, lado, punta + lado, punta - lado])


## Hijo del PROPIO jugador (no de la escena, como hacen las demás
## habilidades que usan IndicadorZonaEfecto): la zona real de corte se
## recalcula desde su posición actual cada fotograma mientras la ventana
## está abierta (ver _process), y Corte ya no lo clava en el lugar al
## lanzar — si el indicador se quedara donde lo lanzaste, mostraría la
## guardia en un lugar y cortaría en otro. Como el cuerpo del jugador no
## rota, el polígono en coordenadas locales ya sale bien orientado.
func _mostrar_indicador(origen: Node2D, dir: Vector2) -> void:
	var indicador := IndicadorZonaEfecto.new()
	indicador.poligono = _puntos_rectangulo(dir)
	# Blanco frío, distinto del naranja de los golpes normales y del azul
	# de los de control: esto no es "daño" ni "control", es un tajo.
	indicador.color_relleno = Color(0.85, 0.95, 1.0, 0.35)
	indicador.color_borde = Color(1.0, 1.0, 1.0, 0.95)
	indicador.duracion = duracion_ventana
	origen.add_child(indicador)
	indicador.position = Vector2.ZERO


## Prende el sprite del haz, lo orienta hacia "dir" y arranca su animación
## de fotogramas UNA sola vez (no en loop, a diferencia de ChorroVisual en
## lanzallamas: eso es un chorro continuo, esto es un tajo instantáneo). Se
## llama antes del chequeo de servidor en _ejecutar(), así que corre en
## TODOS los peers (dueño, servidor y espectadores vía _reproducir_visual_
## red) — mismo criterio que _mostrar_indicador.
func _mostrar_haz(origen: Node2D, dir: Vector2) -> void:
	if not _haz_ancla or not _haz_visual or DisplayServer.get_name() == "headless":
		return
	_haz_ancla.global_position = origen.global_position
	_haz_ancla.rotation = dir.angle()
	_haz_ancla.scale = Vector2(largo / _LARGO_SPRITE_BASE_HAZ, ancho / _ALTO_SPRITE_BASE_HAZ)
	_haz_visual.visible = true
	if _anim_haz:
		_anim_haz.speed_scale = _DURACION_ANIM_BASE_HAZ / duracion_ventana if duracion_ventana > 0.0 else 1.0
		_anim_haz.stop()
		_anim_haz.play("default")


func _al_terminar_anim_haz(_nombre_anim: StringName) -> void:
	if _haz_visual:
		_haz_visual.visible = false


func _abrir_ventana_parry(dir: Vector2) -> void:
	var parry := _componente_parry()
	if parry:
		parry.activar(duracion_ventana, dir)


## Se crea al vuelo si el jugador no lo trae — mismo criterio que
## HabilidadPurga con InmunidadDebuffsComponente y HabilidadEscudo con
## EscudoComponente: la habilidad se puede equipar en cualquier entidad sin
## tener que tocar su .tscn. El NOMBRE del nodo es lo que importa:
## VidaComponente.quitar_vida() lo busca por nombre, no por tipo.
func _componente_parry() -> Node:
	if not is_instance_valid(entidad_dueña):
		return null
	var parry := entidad_dueña.get_node_or_null("ParryComponente")
	if parry == null:
		parry = ParryComponente.new()
		parry.name = "ParryComponente"
		entidad_dueña.add_child(parry)
	return parry


## Daño verdadero a todo enemigo dentro del rectángulo. Devuelve a quiénes
## golpeó, para que _cortar_ataques no vuelva a procesarlos.
func _golpear(origen: Node2D, dir: Vector2) -> Array:
	var golpeados: Array = []
	var forma := ConvexPolygonShape2D.new()
	forma.points = _puntos_rectangulo(dir)
	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = forma
	consulta.transform = origen.global_transform
	consulta.collision_mask = MASCARA_OBJETIVOS
	consulta.collide_with_areas = true
	consulta.collide_with_bodies = true

	# 30 = el mínimo del rango que pidió el usuario (30-40), usado solo si
	# esta habilidad se armó sin DatosHabilidad (una prueba, por ejemplo).
	var dano := float(_calcular_dano(30))
	for resultado in origen.get_world_2d().direct_space_state.intersect_shape(consulta, 32):
		var col = resultado.get("collider")
		if not (col is Node):
			continue
		var vida: Node
		var objetivo: Node
		if col is VidaComponente:
			vida = col
			objetivo = (col as VidaComponente).get_parent()
		elif (col as Node).has_method("quitar_vida"):
			vida = col
			objetivo = col
		else:
			continue
		if objetivo == entidad_dueña or objetivo in golpeados:
			continue
		if Combate.mismo_equipo(entidad_dueña, objetivo):
			continue
		golpeados.append(objetivo)
		# ignora_defensa=true: el punto entero de esta habilidad (ver la
		# cabecera). El lado ofensivo (potencia/crítico propios) sí cuenta.
		var dano_final := AtributosComponente.calcular_pipeline(
			entidad_dueña, objetivo, dano, tipo_dano, true)
		var fue_critico := AtributosComponente.ultimo_pipeline_critico
		if vida is VidaComponente:
			(vida as VidaComponente).quitar_vida(dano_final, entidad_dueña, tipo_dano, fue_critico)
		else:
			vida.quitar_vida(dano_final, entidad_dueña, tipo_dano, fue_critico)
		if Utils.debe_mostrar_dano_local():
			BusEventos.daño_aplicado.emit(objetivo, dano_final, entidad_dueña, tipo_dano, fue_critico)
		BusEventos.habilidad_impacto.emit("corte", objetivo)
	return golpeados


## Destruye los ATAQUES enemigos que quedaron dentro del tajo — la otra
## mitad del counter ("permite atacar cualquier tipo de habilidad de los
## enemigos, sea un proyectil, un ataque en área, un muro, un golpe
## básico"). Cada familia se reconoce por tipo, no por capa física: los
## proyectiles y los efectos de área no tienen quitar_vida(), así que
## Combate.golpear_area() los ignora por diseño y hay que barrerlos acá.
##   - Proyectil        → vuelve a su piscina (deja de volar y de dañar).
##   - EfectoAreaBase   → destruir() (charcos de fuego, telarañas). El Muro
##                        también es uno, pero ya cayó en _golpear() por
##                        tener quitar_vida(), y por eso llega en "ya_
##                        golpeados": romperlo dos veces sería un error.
##   - Golpes básicos/arañazos NO se cortan: su daño se aplica en el mismo
##     fotograma en que nacen (ver GolpeBasico.configurar), el nodo que
##     queda 0.15s es solo el visual. Contra esos, lo que protege es el
##     parry, no el tajo.
func _cortar_ataques(origen: Node2D, dir: Vector2, ya_golpeados: Array) -> void:
	# El rectángulo en coordenadas GLOBALES — hace falta para el chequeo
	# punto-en-polígono de los proyectiles (ver abajo), que no pasa por la
	# física y por lo tanto no puede usar el transform de la consulta.
	var poligono := PackedVector2Array()
	for punto in _puntos_rectangulo(dir):
		poligono.append(origen.global_transform * punto)

	# --- Proyectiles: por la lista de la piscina, NO por física ---
	# Proyectil.tscn es monitorable=false (nadie lo detecta a él, solo él
	# detecta a los demás), así que jamás aparece en un intersect_shape.
	# GestorPiscinas.activos() sí tiene todos los que están en vuelo.
	for nodo in GestorPiscinas.activos():
		if not (nodo is Proyectil) or not is_instance_valid(nodo):
			continue
		# Nunca cortar el propio disparo — el jugador podría estar lanzando
		# Corte con un proyectil suyo todavía en vuelo.
		if (nodo as Proyectil).entidad_fuente == entidad_dueña:
			continue
		if Geometry2D.is_point_in_polygon((nodo as Node2D).global_position, poligono):
			GestorPiscinas.liberar(nodo)

	# --- Efectos de área: esos SÍ por física (son monitorable) ---
	var forma := ConvexPolygonShape2D.new()
	forma.points = _puntos_rectangulo(dir)
	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = forma
	consulta.transform = origen.global_transform
	consulta.collision_mask = MASCARA_OBJETIVOS
	consulta.collide_with_areas = true
	consulta.collide_with_bodies = false

	for resultado in origen.get_world_2d().direct_space_state.intersect_shape(consulta, 32):
		var col = resultado.get("collider")
		if not (col is EfectoAreaBase) or col in ya_golpeados:
			continue
		# Un efecto de área no está en los grupos "jugadores"/"enemigos"
		# (no es un combatiente), así que Combate.mismo_equipo() no sirve
		# acá: daría false SIEMPRE y el jugador se cortaría sus propios
		# muros. A quién APUNTA el efecto sí lo dice bien — grupo_objetivo
		# "jugadores" = nos lo tiraron a nosotros.
		if not entidad_dueña.is_in_group((col as EfectoAreaBase).grupo_objetivo):
			continue
		(col as EfectoAreaBase).destruir()
