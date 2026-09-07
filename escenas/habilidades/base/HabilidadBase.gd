class_name HabilidadBase
extends Node

## Píxeles por metro — factor de conversión para alcance_metros → píxeles.
const ESCALA_METROS_PIXEL := 40.0
## Clase base abstracta para todas las habilidades.
## Gestiona el ciclo de vida de la recarga y provee una interfaz de activación uniforme.
## Para añadir una nueva habilidad: extender esta clase y sobreescribir _ejecutar().
##
## entidad_dueña es asignada externamente por SlotHabilidades antes de add_child.

## Emitida al activar la habilidad.
signal habilidad_activada(habilidad: HabilidadBase)
## Emitida al terminar la recarga.
signal recarga_terminada(habilidad: HabilidadBase)

@export var nombre_habilidad: String = "Habilidad"
## Identificador usado en BusEventos para distinguir habilidades.
@export var tipo_habilidad: String = "base"
@export var duracion_recarga: float = 1.0
## Energía consumida al activar. 0 = gratis.
@export var costo_energia: float = 0.0
## Si true, el control UI se adapta a modo joystick (direccional).
## Si false, se usa como botón tap.
@export var requiere_direccion: bool = false
## Tipo de daño que inflige esta habilidad. Afecta las resistencias del defensor.
@export var tipo_dano: Enums.Habilidad.TipoDano = Enums.Habilidad.TipoDano.FISICO
## Datos opcionales para habilidades de MOBS: el jugador aplica su
## DatosHabilidad al equipar (ver SlotHabilidades.gd), pero las habilidades
## de un mob son nodos fijos en su escena, sin ningún SlotHabilidades de
## por medio — antes de esto, su única forma de configurarse era un
## override de instancia en el .tscn, que solo funciona en campos @export
## (ver el bug de HabilidadGolpeBasico.daño, una var plana que un
## daño = 47.0 en el .tscn nunca aplicaba). Se aplica una sola vez acá, en
## _ready(), ANTES de que el _ready() de la subclase corra — así cualquier
## nombre_habilidad/tipo_habilidad hardcodeado ahí (ej. "Arañazo") sigue
## ganando por sobre lo cosmético que traiga el recurso.
@export var datos: DatosHabilidad = null
## Sonido opcional reproducido UNA vez por _ejecutar() (posicional, en
## entidad_dueña) — null = silencio, sin cambio de comportamiento para
## ninguna instancia existente. Las subclases que lo soporten llaman
## _reproducir_sonido() desde su propio _ejecutar(); como corre ahí (no en
## activar()), replica igual que el resto del efecto visual — ver
## _reproducir_visual_red().
@export var sonido: AudioStream = null
## Apagar SOLO en habilidades cuyo propósito ES moverse (dash, parpadeo):
## para esas, congelar al activar no tiene sentido (el desplazamiento es la
## habilidad misma) y ya tienen su propio manejo de posición. El resto
## (proyectiles, áreas, ráfaga...) se congela por defecto — ver activar().
@export var congela_movimiento_en_red := true
## Ida y vuelta de red que se le da al dueño para congelarse ANTES de que
## el servidor procese _activar_red — ver activar(). Si el ping real supera
## esto, la mitigación no alcanza a cubrir todo el hueco (mejor que nada,
## pero no es una garantía dura — la solución completa sería lag
## compensation del lado del servidor).
## Confirmado en juego real (probado con 1.0s a propósito, bien
## perceptible: el disparo SÍ esperaba el congelamiento completo antes de
## salir — el mecanismo funciona) que el atravesar/no-hacer-daño reportado
## sigue pasando incluso con el congelamiento funcionando, así que no era
## (solo) un problema de timing del freeze. Se deja en 0.5s — más margen
## que el 0.25 original, sin el costo de sentirse "pegado" al disparar.
const _MARGEN_CONGELAMIENTO_RED := 0.5

## Entidad a la que pertenece esta habilidad (asignada automáticamente en _ready).
var entidad_dueña: Node = null
## Índice del slot donde está equipada. -1 si no está en ningún slot (ej: enemigos).
var slot_index: int = -1

var _recarga_restante: float = 0.0
## Rango de daño cargado desde DatosHabilidad. 0,0 = usar valor por defecto de la subclase.
var _dano_min: int = 0
var _dano_max: int = 0

## Velocidad de la RECARGA — 1.0 = normal, 2.0 = la mitad de tiempo. Lo toca
## HabilidadFervor mientras dura su buff (afecta a las OTRAS habilidades del
## dueño, nunca a sí misma) — nadie más debería escribir esto a mano.
var multiplicador_recarga: float = 1.0

## Puntos de mejora invertidos en ESTA habilidad (ver MejorasComponente) —
## 1 = base, sin invertir nada. QUÉ escala y CÓMO (fórmula porcentual o
## tabla de valores exactos) lo define datos.escalado, no esta clase — ver
## EscaladoHabilidad/CampoEscalado y preparar_escalado()/aplicar_nivel_
## mejora() más abajo. null = esta habilidad no es mejorable todavía.
var nivel_mejora: int = 1
var _escalado: EscaladoHabilidad = null
## Valores de FÁBRICA (antes de cualquier nivel de mejora) de los campos
## que datos.escalado configuró para ESTA habilidad, indexados por su
## nombre REAL de propiedad — capturados en preparar_escalado(). Sin esto,
## comprar un segundo nivel compondría el escalado sobre un valor ya
## escalado en vez de recalcular desde cero (mismo criterio que
## AtributosComponente._base_sin_equipo).
var _valores_base_campos: Dictionary = {}

func _ready() -> void:
	# Fallback para habilidades que no pasan por SlotHabilidades (ej: enemigos).
	# SlotHabilidades asigna entidad_dueña antes de add_child, así que aquí
	# solo entra cuando aún está en null (jerarquía clásica: hab → contenedor → entidad).
	if entidad_dueña == null and get_parent() != null:
		entidad_dueña = get_parent().get_parent()
	if datos:
		aplicar_datos(datos)

func _process(delta: float) -> void:
	if _recarga_restante > 0.0:
		_recarga_restante -= delta * multiplicador_recarga
		if _recarga_restante <= 0.0:
			_recarga_restante = 0.0
			recarga_terminada.emit(self)
			BusEventos.recarga_terminada.emit(entidad_dueña, slot_index)

# ── API Pública ───────────────────────────────────────────────────────────────

## Devuelve true si la habilidad no está en recarga.
func puede_usarse() -> bool:
	return _recarga_restante <= 0.0


## ¿Esta habilidad se puede lanzar aunque el dueño esté con el control
## bloqueado (aturdido, congelado por el margen de red de otra habilidad,
## arrastrado por un gancho)? false salvo que la subclase declare la
## propiedad "ignora_bloqueos" en true — ver el comentario en activar().
## Lo consultan también Jugador._activar_slot() y UIHabilidad, que cortan
## el toque antes de que la activación llegue hasta acá.
func ignora_bloqueos_de_control() -> bool:
	return _ignora_bloqueos()


func _ignora_bloqueos() -> bool:
	return ("ignora_bloqueos" in self) and self.get("ignora_bloqueos")

## Devuelve la proporción de recarga restante (0.0 = lista, 1.0 = recién usada).
func obtener_ratio_recarga() -> float:
	if duracion_recarga <= 0.0:
		return 0.0
	return clampf(_recarga_restante / duracion_recarga, 0.0, 1.0)

## Devuelve los segundos restantes de recarga.
func obtener_recarga_restante() -> float:
	return maxf(0.0, _recarga_restante)

## Activa la habilidad en la dirección dada con la potencia indicada.
## direccion — vector normalizado (joystick o dirección del agente).
## poder     — valor 0..1 para escalar distancia/alcance.
func activar(direccion: Vector2 = Vector2.ZERO, poder: float = 1.0) -> void:
	if not puede_usarse():
		return
	# "Bloquear control" ya significa "no puede hacer nada", no solo "no
	# se mueve" — sin este chequeo, mientras una habilidad tiene al dueño
	# bloqueado (el margen de congelamiento de red de CUALQUIER otra, o el
	# gancho arrastrando/siendo arrastrado, ver HabilidadGancho) igual se
	# podía activar una habilidad distinta desde otro slot. Corre en
	# activar() (no en cada _activar_slot de la UI) para proteger también
	# la copia autoritativa del servidor, que llega acá directo por
	# _activar_red() sin pasar por la UI.
	# ignora_bloqueos: escotilla de escape para una habilidad que DEBE poder
	# lanzarse aunque el dueño esté aturdido/congelado (hoy solo
	# HabilidadCorte, pedido del usuario: "este ataque siempre debe estar
	# disponible para lanzarse, sin importar si el jugador está en algún
	# estado alterado"). Duck typing, mismo criterio que "es_canal_continuo"
	# de HabilidadLanzallamas — nadie tiene que conocer la clase.
	# La MUERTE no entra acá a propósito: un muerto no lanza nada, y eso lo
	# corta esta_bloqueado()/_muerto aguas arriba y en _activar_red().
	if not _ignora_bloqueos() and is_instance_valid(entidad_dueña) \
			and ("_bloqueos_control" in entidad_dueña) \
			and entidad_dueña._bloqueos_control > 0:
		return
	if costo_energia > 0.0:
		var energia := entidad_dueña.get_node_or_null("EnergiaComponente") as EnergiaComponente
		if energia and not energia.consumir(costo_energia):
			return  # Sin energía suficiente
	# Recarga y avisos van ACÁ, en el instante en que se presiona — no tiene
	# sentido que el cooldown visual espere al margen de abajo, el jugador
	# ya "gastó" la habilidad en cuanto la tocó.
	_iniciar_recarga()
	habilidad_activada.emit(self)
	BusEventos.habilidad_usada.emit(entidad_dueña, tipo_habilidad)

	# Girar al dueño hacia donde apunta — necesario ACÁ (no solo en
	# Jugador._activar_slot) porque el SERVIDOR nunca pasa por ese método:
	# recibe la activación directo por _activar_red() y llama activar() acá
	# mismo. Sin esto, el giro solo se veía en la pantalla de quien lanzaba
	# (reportado: "la dirección solo cambia en el local, no en los demás
	# jugadores") — el servidor (la copia autoritativa que se replica a
	# todos) nunca se enteraba. Acotado a jugadores (grupo "jugadores"): los
	# mobs ya manejan su propio direccion_mirada desde su IA/acciones de
	# combate, con más criterio (p. ej. mantenerlo mientras dura el ataque).
	if requiere_direccion and direccion.length() > 0.1 and is_instance_valid(entidad_dueña) \
			and entidad_dueña.is_in_group("jugadores") and "direccion_mirada" in entidad_dueña:
		entidad_dueña.direccion_mirada = direccion.normalized()

	if _debe_pedirle_al_servidor() and congela_movimiento_en_red \
			and entidad_dueña and entidad_dueña.has_method("bloquear_control"):
		# Congelar YA (bloquear_control ya manda su propio aviso de "parate"
		# al servidor por un canal reliable — ver Jugador.bloquear_control),
		# pero el DISPARO en sí (RPC + _ejecutar, lo que de verdad importa
		# para dónde nace un proyectil) se pospone _MARGEN_CONGELAMIENTO_RED
		# — antes salía en el mismo instante que el freeze, así que si el
		# jugador venía en movimiento, el "párate" y el disparo viajaban
		# juntos: el servidor podía procesar el disparo ANTES de que el
		# "párate" surtiera efecto, y el proyectil real nacía unos píxeles
		# más adelante de donde el cliente ya lo mostraba quieto — más
		# notorio disparando justo al borde de un objetivo en movimiento
		# ("a veces traspasa haciendo daño, o choca y no hace daño",
		# reportado). Esperar el mismo margen que ya se usaba para
		# descongelar (no uno nuevo) le da tiempo real a la orden de
		# frenado de llegar y aplicarse ANTES de que la posición importe.
		entidad_dueña.bloquear_control()
		var dueño_congelado := entidad_dueña
		get_tree().create_timer(_MARGEN_CONGELAMIENTO_RED).timeout.connect(func():
			if is_instance_valid(dueño_congelado) and dueño_congelado.has_method("desbloquear_control"):
				dueño_congelado.desbloquear_control()
			_disparar(direccion, poder)
		)
	else:
		_disparar(direccion, poder)


## El disparo de verdad: manda el RPC de activación (si corresponde) y
## corre _ejecutar() — separado de activar() para poder posponerlo sin
## posponer también el cooldown/los avisos (ver activar()).
func _disparar(direccion: Vector2, poder: float) -> void:
	if _debe_pedirle_al_servidor():
		# Fase 3 del plan de multijugador: el servidor es quien de verdad
		# corre _ejecutar() con autoridad (el daño real, vía
		# VidaComponente.quitar_vida, está gateado a "solo servidor") para
		# que dos clientes no calculen resultados de combate distintos por
		# su cuenta. PERO no cortar acá: seguir abajo y llamar _ejecutar()
		# también en este cliente es predicción visual pura — el golpe se
		# ve y se anima al instante en vez de esperar la ida y vuelta de
		# red, sin aplicar daño de verdad (VidaComponente ya lo bloquea).
		rpc_id(1, "_activar_red", direccion, poder)
	_ejecutar(direccion, poder)
	# Avisar a los DEMÁS clientes (espectadores, y toda habilidad de
	# enemigos — _debe_pedirle_al_servidor() siempre da false para mobs,
	# así que esta rama es la única que corre para ellos) para que también
	# vean el efecto. Solo tiene sentido si esto corrió con autoridad real
	# (el servidor, o un solo jugador sin red no necesita avisarle a nadie).
	if Utils.en_red() and multiplayer.is_server():
		# rpc_id + InteresEspacial en vez de rpc() (broadcast a TODOS) —
		# mismo criterio que VidaComponente.quitar_vida: esto se dispara en
		# CADA activación de CUALQUIER habilidad, de cualquier mob o
		# jugador, en cualquier punto del mapa.
		if is_instance_valid(entidad_dueña) and entidad_dueña is Node2D:
			var posicion := (entidad_dueña as Node2D).global_position
			for peer_id in InteresEspacial.peers_cercanos(posicion):
				rpc_id(peer_id, "_reproducir_visual_red", direccion, poder)


## true si esto corre en red, la dueña es un jugador con identidad de peer
## (ver Jugador.peer_id_dueño), y YO NO SOY el servidor. Sin multiplayer
## activo (juego de un jugador, o habilidades de enemigos sin peer_id_dueño)
## siempre da false — cero cambio de comportamiento en esos casos.
func _debe_pedirle_al_servidor() -> bool:
	if not Utils.en_red():
		return false
	if not is_instance_valid(entidad_dueña) or not ("peer_id_dueño" in entidad_dueña):
		return false
	var dueño: int = entidad_dueña.peer_id_dueño
	return dueño >= 0 and not multiplayer.is_server()


## El servidor recibe acá la intención de activar del cliente dueño de esta
## habilidad. "any_peer" = cualquiera puede llamarlo, pero se verifica que
## el remitente sea el dueño real antes de aceptarlo (autoridad real, mismo
## criterio que Jugador._pedir_mover_red()).
@rpc("any_peer", "reliable")
func _activar_red(direccion: Vector2, poder: float) -> void:
	if not multiplayer.is_server():
		return
	if not is_instance_valid(entidad_dueña) or not ("peer_id_dueño" in entidad_dueña):
		return
	if multiplayer.get_remote_sender_id() != entidad_dueña.peer_id_dueño:
		return
	# Un muerto —o alguien recién llegado a un nivel nuevo, ver
	# Jugador.bloquear_por_transicion— no lanza habilidades. El cliente ya lo
	# bloquea en su UI (Jugador._activar_slot), pero la autoridad real vive
	# acá: un cliente modificado no puede saltárselo.
	# Una habilidad con ignora_bloqueos (ver activar()) sí puede lanzarse
	# aturdida — pero NUNCA muerta: por eso ahí se chequea solo _muerto en
	# vez de esta_bloqueado() entero.
	if _ignora_bloqueos():
		if ("_muerto" in entidad_dueña) and entidad_dueña.get("_muerto"):
			return
	elif entidad_dueña.has_method(&"esta_bloqueado"):
		if entidad_dueña.call(&"esta_bloqueado"):
			return
	elif ("_muerto" in entidad_dueña) and entidad_dueña.get("_muerto"):
		return
	activar(direccion, poder)


## El servidor le avisa a TODOS los clientes que reproduzcan el efecto
## visual de esta habilidad — el cliente dueño (si lo hay) ya lo mostró
## solo con predicción (ver activar()), así que se salta acá para no
## duplicar el golpe/animación. Nunca aplica daño de verdad: eso lo decide
## únicamente VidaComponente.quitar_vida(), gateado a "solo servidor".
## reliable: es UN paquete por activación (no un flujo continuo como la
## posición) — si se pierde, el jugador recibe el golpe "de la nada", sin
## ninguna animación (reportado con el lobo).
@rpc("authority", "reliable")
func _reproducir_visual_red(direccion: Vector2, poder: float) -> void:
	if is_instance_valid(entidad_dueña) and ("peer_id_dueño" in entidad_dueña) \
			and entidad_dueña.peer_id_dueño == multiplayer.get_unique_id():
		return
	_ejecutar(direccion, poder)

# ── Internos — sobreescribir en subclases ─────────────────────────────────────

## Aplica los valores de un DatosHabilidad a esta instancia.
## Las subclases pueden llamar super.aplicar_datos(d) y añadir sus propios campos.
func aplicar_datos(d: DatosHabilidad) -> void:
	if not d:
		return
	nombre_habilidad = d.nombre
	costo_energia    = float(d.costo_energia)
	duracion_recarga = d.enfriamiento
	# El elemento vive en el .tres (DatosHabilidad.tipo_dano) — sin esta
	# copia, toda habilidad equipada pegaba como PHYSIC sin importar el
	# elemento asignado en el editor, y las resistencias elementales de
	# calcular_dano_entrante() nunca entraban en juego. OJO: igual que con
	# costo_energia/enfriamiento (ver el bug de lanzallamas.tres), el .tres
	# SIEMPRE pisa lo que diga la escena — una habilidad elemental necesita
	# su tipo_dano asignado en el .tres, no solo en el .tscn.
	tipo_dano        = d.tipo_dano
	_dano_min        = d.dano_base_min
	_dano_max        = d.dano_base_max

## Devuelve un daño entero aleatorio entre _dano_min y _dano_max.
## Si no hay rango definido (DatosHabilidad no aplicado), usa el fallback de la subclase.
func _calcular_dano(fallback: int) -> int:
	if _dano_min > 0 or _dano_max > 0:
		return randi_range(_dano_min, _dano_max)
	return fallback


## Traduce un campo CONCEPTUAL (ver Enums.Habilidad.CampoEscalable) al
## nombre REAL de la propiedad de instancia que le corresponde en ESTA
## habilidad — "" si esta habilidad no tiene ese campo. La base cubre lo
## que ya es común a toda habilidad (daño, recarga, costo); las subclases
## sobreescriben (llamando a super() para lo que no reconozcan) para
## agregar las suyas propias — ver HabilidadProyectil (RANGO) o
## HabilidadEscudo (DURACION_EFECTO/PORCENTAJE_EFECTO) como ejemplo.
func _nombre_campo_escalable(campo: Enums.Habilidad.CampoEscalable) -> String:
	match campo:
		Enums.Habilidad.CampoEscalable.DANO_MIN: return "_dano_min"
		Enums.Habilidad.CampoEscalable.DANO_MAX: return "_dano_max"
		Enums.Habilidad.CampoEscalable.RECARGA: return "duracion_recarga"
		Enums.Habilidad.CampoEscalable.COSTO_ENERGIA: return "costo_energia"
		_: return ""


## Traduce un CampoEscalado a su nombre de propiedad real, sin importar
## cuál de los dos selectores use (ver CampoEscalado.campo_atributo) — el
## único punto que preparar_escalado()/aplicar_nivel_mejora() consultan.
## campo_atributo tiene prioridad y NO necesita traducción a mano ni
## override por habilidad: el nombre real sale por REFLEXIÓN del propio
## enum (Enums.Atributos.Campo.keys()[valor] -> "POTENCIA" ->
## "bono_potencia"), no de un match a mano — agregar un atributo nuevo de
## AtributosBase el día de mañana solo toca Enums.gd, nunca este archivo.
func _nombre_campo_de(c: CampoEscalado) -> String:
	if c.campo_atributo != Enums.Atributos.Campo.NINGUNO:
		var nombre_enum: String = Enums.Atributos.Campo.keys()[c.campo_atributo]
		return "bono_" + nombre_enum.to_lower()
	return _nombre_campo_escalable(c.campo)


## Captura los valores de FÁBRICA de los campos que [escalado] configuró
## para esta habilidad — llamar DESPUÉS de que aplicar_datos() (base +
## TODA subclase) haya terminado del todo. aplicar_datos() de la base
## corre PRIMERO (vía super(), al principio del override de la subclase),
## así que capturar acá adentro daría un valor viejo/cero para cualquier
## campo que la subclase recién asigna después (rango, duración de
## efecto...) — por eso este es un paso APARTE, llamado por
## SlotHabilidades._instanciar() justo después de aplicar_datos().
func preparar_escalado(escalado: EscaladoHabilidad) -> void:
	_escalado = escalado
	_valores_base_campos.clear()
	if not escalado:
		return
	for c in escalado.campos:
		var nombre := _nombre_campo_de(c)
		if nombre != "":
			_valores_base_campos[nombre] = get(nombre)


## Aplica un nivel de mejora (ver MejorasComponente) — SlotHabilidades lo
## llama al equipar (con lo que el jugador ya tenga comprado) y
## MejorasComponente lo vuelve a llamar si la habilidad está equipada
## ahora mismo cuando se compra un nivel nuevo. SIEMPRE recalcula desde
## _valores_base_campos (capturados en preparar_escalado) para no
## componer el escalado sobre un valor ya escalado.
func aplicar_nivel_mejora(nivel: int) -> void:
	if _escalado == null:
		nivel_mejora = 1
		return
	nivel_mejora = clampi(nivel, 1, _escalado.nivel_maximo)
	for c in _escalado.campos:
		var nombre := _nombre_campo_de(c)
		if nombre == "" or not _valores_base_campos.has(nombre):
			continue
		set(nombre, c.valor_para_nivel(nivel_mejora, _valores_base_campos[nombre]))

## Lógica específica de la habilidad. Sobreescribir en cada subclase.
func _ejecutar(_direccion: Vector2, _poder: float) -> void:
	pass

## Reproduce [sonido] por GestorSonido (bus "SFX", ver
## NotificacionLoot.gd para el mismo patrón) — no-op si sonido es null
## (todas las instancias existentes que no lo configuran).
func _reproducir_sonido() -> void:
	if sonido == null:
		return
	GestorSonido.reproducir(sonido)

func _iniciar_recarga() -> void:
	_recarga_restante = duracion_recarga
	BusEventos.recarga_iniciada.emit(entidad_dueña, slot_index, duracion_recarga)
