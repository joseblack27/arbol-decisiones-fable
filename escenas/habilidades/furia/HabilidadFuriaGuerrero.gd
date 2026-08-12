class_name HabilidadFuriaGuerrero
extends HabilidadBase
## Auto-buff del Esqueleto Caballero: mientras esté activa, se vuelve más
## agresivo — más rápido (multiplicador_velocidad sobre MovimientoComponente
## .velocidad_base), pega más fuerte (bono_dano sumado al daño del Arañazo)
## y recarga TODAS sus otras habilidades más rápido (multiplicador_recarga
## en cada HabilidadBase hermana bajo Habilidades/, mismo mecanismo que ya
## usa EnemigoArañaReina._activar_furia_final y HabilidadFervor del jugador
## — la diferencia acá es que esta Furia es TEMPORAL, se revierte sola al
## terminar, no permanente).
##
## Pedido explícito del usuario, con las reglas de activación EXACTAS:
## 10% de probabilidad, evaluada cada 10s mientras tenga un objetivo, dura
## 15s, NO se evalúa la probabilidad mientras la furia esté activa, y
## recién se vuelve a evaluar 10s después de que la furia termine. Esa
## lógica de "cuándo tirar la moneda" vive en EnemigoCaballeroEsqueleto
## (dueño de la decisión de IA, igual que la cadencia rápida del arquero),
## no acá — esta clase solo sabe aplicar/revertir el efecto y avisar
## cuándo termina (furia_terminada) para que el que decide pueda reiniciar
## su propia ventana de 10s en el momento justo.
##
## Activada vía activar() (no _ejecutar() directo) para que el aviso
## llegue replicado a todos los clientes por el mismo canal que cualquier
## otra habilidad (ver HabilidadBase._disparar/_reproducir_visual_red) —
## el ícono y el efecto visual tienen que verse igual en todas las
## pantallas, no solo en la del servidor.

@export var duracion: float = 15.0
@export var multiplicador_velocidad: float = 1.3
@export var bono_dano: float = 20.0
## "Reduce el cooldown de lanzar habilidades un 50%" = recarga al DOBLE de
## velocidad (multiplicador_recarga en HabilidadBase divide el tiempo de
## recarga restante, no lo multiplica — ver HabilidadBase._process).
@export var multiplicador_recarga_habilidades: float = 2.0
## Asignado en la escena (ver EnemigoCaballeroEsqueleto.tscn): recorte de
## iconos habilidades.png, el mismo que ya usa Purga (región Rect2(160, 0,
## 32, 32) — pedido explícito del usuario, reusar ese ícono acá también).
@export var icono_buff: Texture2D = null

## Referencia inyectada (ver EnemigoCaballeroEsqueleto.tscn) — no se
## autorresuelve por get_node para no depender del orden de _ready() entre
## ramas hermanas del árbol.
@export var componente_movimiento: MovimientoComponente

## ataque_arañazo NO usa el mismo mecanismo de @export + NodePath que
## componente_movimiento: confirmado en pruebas que, para este nodo en
## particular, esa referencia queda sin resolver (null) — mientras que
## componente_movimiento sí resuelve bien con el mismo patrón. La
## diferencia parece ser que HabilidadArañazo es la raíz de una escena
## INSTANCIADA (instance=...) dentro de EnemigoCaballeroEsqueleto.tscn y
## MovimientoComponente no; no hizo falta llegar al fondo del porqué exacto
## de Godot — se resuelve a mano en _ready() (probado, funciona) en vez de
## perseguir el mecanismo de @export para este caso puntual. Esta
## habilidad es exclusiva del Caballero Esqueleto de todos modos, así que
## no pierde nada de flexibilidad real.
var ataque_arañazo: HabilidadArañazo = null

## Avisa el instante exacto en que la furia termina (por tiempo, nunca a
## mano) — quien decide cuándo volver a tirar la moneda (EnemigoCaballero
## Esqueleto) lo necesita para reiniciar su propia ventana de 10s justo
## ahí, ni un fotograma antes.
signal furia_terminada()

var _velocidad_normal: float = -1.0
var _dano_normal: float = -1.0
var _fin_efecto: float = -INF
var _estaba_activa: bool = false


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Furia"
	tipo_habilidad = "furia"
	ataque_arañazo = get_node_or_null("../HabilidadArañazo") as HabilidadArañazo
	# NO capturar _velocidad_normal acá: Enemigo._ready() (el padre) recién
	# aplica datos.velocidad_base (el valor real por tipo de enemigo, 80
	# para el Caballero) a componente_movimiento DESPUÉS de que corra este
	# _ready() — los hijos se inicializan antes que el padre en Godot.
	# Capturar acá agarraría el default del script (300), y al terminar la
	# furia la velocidad quedaría pegada en 300 para siempre en vez de
	# volver a 80. Se captura perezoso (ver _capturar_valores_normales_si_
	# hace_falta), la primera vez que hace falta, con todo el árbol ya listo.
	if ataque_arañazo:
		_dano_normal = ataque_arañazo.daño


func esta_activa() -> bool:
	return Time.get_ticks_msec() / 1000.0 < _fin_efecto


func _capturar_valores_normales_si_hace_falta() -> void:
	if _velocidad_normal < 0.0 and componente_movimiento:
		_velocidad_normal = componente_movimiento.velocidad_base


func _process(delta: float) -> void:
	super._process(delta)
	_capturar_valores_normales_si_hace_falta()
	var activa := esta_activa()

	if componente_movimiento and _velocidad_normal >= 0.0:
		var objetivo_vel := (_velocidad_normal * multiplicador_velocidad) if activa else _velocidad_normal
		if componente_movimiento.velocidad_base != objetivo_vel:
			componente_movimiento.velocidad_base = objetivo_vel

	if ataque_arañazo and _dano_normal >= 0.0:
		var objetivo_dano := (_dano_normal + bono_dano) if activa else _dano_normal
		if ataque_arañazo.daño != objetivo_dano:
			ataque_arañazo.daño = objetivo_dano

	if is_instance_valid(entidad_dueña):
		var habilidades := entidad_dueña.get_node_or_null("Habilidades")
		if habilidades:
			var objetivo_recarga := multiplicador_recarga_habilidades if activa else 1.0
			for hijo in habilidades.get_children():
				if hijo is HabilidadBase and hijo != self and hijo.multiplicador_recarga != objetivo_recarga:
					hijo.multiplicador_recarga = objetivo_recarga

	if _estaba_activa and not activa:
		_quitar_icono()
		furia_terminada.emit()
	_estaba_activa = activa


func _ejecutar(_direccion: Vector2, _poder: float) -> void:
	# Por si activar() llegara a correr antes del primer _process() (ej.
	# desde _physics_process, que corre en su propio reloj) — sin esto,
	# esta_activa()/_process() capturarían recién un fotograma tarde, pero
	# mejor no depender de esa suerte de orden.
	_capturar_valores_normales_si_hace_falta()
	_fin_efecto = Time.get_ticks_msec() / 1000.0 + duracion
	_agregar_icono()


func _agregar_icono() -> void:
	if icono_buff == null or not is_instance_valid(entidad_dueña):
		return
	var buffs := entidad_dueña.get_node_or_null("BuffsComponente") as BuffsComponente
	if buffs == null:
		buffs = BuffsComponente.new()
		buffs.name = "BuffsComponente"
		entidad_dueña.add_child(buffs)
	buffs.agregar("furia", icono_buff, duracion, false,
		nombre_habilidad, "Más rápido, pega más fuerte y recarga habilidades más rápido")


func _quitar_icono() -> void:
	if not is_instance_valid(entidad_dueña):
		return
	var buffs := entidad_dueña.get_node_or_null("BuffsComponente") as BuffsComponente
	if buffs:
		buffs.quitar("furia")
