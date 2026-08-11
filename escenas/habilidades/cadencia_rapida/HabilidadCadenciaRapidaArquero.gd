class_name HabilidadCadenciaRapidaArquero
extends HabilidadBase
## Auto-buff del Esqueleto Arquero: mientras esté activo, dispara más
## seguido — divide entre multiplicador_cadencia TANTO la duracion_
## recuperacion de su AccionAtacar COMO la duracion_pose_ataque de su
## HabilidadFlecha (ver ambas más abajo). Hace falta tocar las dos: desde
## que HabilidadFlechaArquero pasó a tener su propia pose telegrafiada
## (quieto durante duracion_pose_ataque antes de que salga la flecha, ver
## esa clase), esa pose pasó a ser la porción más larga y más VISIBLE de
## cada ciclo de disparo — apurar solo la recuperación (como hacía la
## versión original, de antes de la pose) dejaba el efecto casi
## imperceptible: "siento que no se le nota el disparo más rápido"
## (reportado por el usuario, justo por esto).
##
## Pedido explícito del usuario: que la cadencia rápida sea una habilidad
## de verdad (no una mutación directa de un campo, como antes) y que
## muestre su propio ícono sobre el mob mientras dure — mismo mecanismo
## que ya usan las habilidades de auto-buff del jugador (ver HabilidadFervor:
## reevaluación continua contra un timestamp de fin, así reactivarla ANTES
## de que venza extiende la ventana en vez de que un temporizador viejo la
## corte) y el mismo BuffsComponente que ya usan los debuffs (veneno,
## lentitud...) y el escudo de EnemigoArañaReina para el ícono flotante —
## Enemigo.gd ya escucha BuffsComponente.buff_agregado/quitado solo, no
## hace falta tocar nada ahí.
##
## Activada DIRECTO desde la IA del arquero (ver EnemigoEsqueletoArquero.
## _decidir_reaccion), no por SelectorHabilidades: es una reacción propia
## del mob (como la retirada), no una habilidad elegida por rango/
## prioridad entre varias. Aun así se dispara vía activar() (no _ejecutar()
## directo) para que el aviso llegue replicado a todos los clientes por el
## mismo canal que ya usa cualquier otra habilidad (ver HabilidadBase.
## _disparar/_reproducir_visual_red) — el ícono tiene que verse igual en
## todas las pantallas, no solo en la del servidor.

@export var duracion: float = 5.0
@export var multiplicador_cadencia: float = 1.5
## Por defecto usa icono_correr_final_32x32.png (ver EnemigoEsqueletoArquero
## .tscn) — no había ícono dedicado de "cadencia/velocidad" en el proyecto,
## así que se reusa el mismo que ya usa la Carga del jugador (misma idea de
## "más rápido"). Cambiar acá en el Inspector si aparece uno mejor. Sin
## asignar (null) el efecto igual funciona, simplemente no aparece ningún
## ícono.
@export var icono_buff: Texture2D = null

## Referencias inyectadas (ver EnemigoEsqueletoArquero.tscn): los dos
## nodos que de verdad controlan el ritmo de disparo — la recuperación
## entre ataques y la pose antes de que salga la flecha. No se
## autorresuelven por get_node para no depender del orden de _ready()
## entre ramas hermanas del árbol.
@export var accion_atacar: AccionAtacar
@export var habilidad_flecha: HabilidadFlechaArquero

## duracion_recarga (heredado de HabilidadBase) tiene que quedar en 0.0 en
## la instancia de la escena — el único gate real de "cada cuánto se puede
## reactivar" es el intervalo de decisión de la IA (_INTERVALO_DECISION =
## 5.0s en EnemigoEsqueletoArquero), bien por encima del default de
## HabilidadBase (1.0s). Dejarlo en 1.0s no rompe nada en juego real (5s >>
## 1s, nunca llega a chocar), pero SÍ bloquea en silencio una reactivación
## que llegue más rápido que eso por cualquier otro motivo (reportado por
## una prueba que reactivaba la habilidad dos veces en menos de un
## segundo: activar() no hacía nada la segunda vez, sin ningún aviso).

var _duracion_recuperacion_normal: float = -1.0
var _duracion_pose_normal: float = -1.0
var _fin_efecto: float = -INF


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Cadencia Rápida"
	tipo_habilidad = "cadencia_rapida"
	if accion_atacar:
		_duracion_recuperacion_normal = accion_atacar.duracion_recuperacion
	if habilidad_flecha:
		_duracion_pose_normal = habilidad_flecha.duracion_pose_ataque


func _process(delta: float) -> void:
	super._process(delta)
	var activo := Time.get_ticks_msec() / 1000.0 < _fin_efecto
	var aplico_algo := false

	if accion_atacar and _duracion_recuperacion_normal >= 0.0:
		var objetivo_recuperacion := (_duracion_recuperacion_normal / multiplicador_cadencia) if activo else _duracion_recuperacion_normal
		if accion_atacar.duracion_recuperacion != objetivo_recuperacion:
			accion_atacar.duracion_recuperacion = objetivo_recuperacion
			aplico_algo = true

	if habilidad_flecha and _duracion_pose_normal >= 0.0:
		var objetivo_pose := (_duracion_pose_normal / multiplicador_cadencia) if activo else _duracion_pose_normal
		if habilidad_flecha.duracion_pose_ataque != objetivo_pose:
			habilidad_flecha.duracion_pose_ataque = objetivo_pose
			aplico_algo = true

	if aplico_algo and not activo:
		_quitar_icono()


func _ejecutar(_direccion: Vector2, _poder: float) -> void:
	if not accion_atacar:
		return
	_fin_efecto = Time.get_ticks_msec() / 1000.0 + duracion
	_agregar_icono()


## Corta el efecto YA, sin esperar a que venza solo — la IA del arquero la
## llama al elegir retirada en vez de cadencia rápida (ver
## EnemigoEsqueletoArquero._decidir_reaccion): cada decisión de 5s es
## independiente de la anterior, no debe quedar la cadencia rápida pegada
## si esta vez tocó retirada.
func desactivar() -> void:
	_fin_efecto = -INF


func _agregar_icono() -> void:
	if icono_buff == null or not is_instance_valid(entidad_dueña):
		return
	var buffs := entidad_dueña.get_node_or_null("BuffsComponente") as BuffsComponente
	if buffs == null:
		buffs = BuffsComponente.new()
		buffs.name = "BuffsComponente"
		entidad_dueña.add_child(buffs)
	buffs.agregar("cadencia_rapida", icono_buff, duracion, false,
		nombre_habilidad, "Dispara más seguido")


func _quitar_icono() -> void:
	if not is_instance_valid(entidad_dueña):
		return
	var buffs := entidad_dueña.get_node_or_null("BuffsComponente") as BuffsComponente
	if buffs:
		buffs.quitar("cadencia_rapida")
