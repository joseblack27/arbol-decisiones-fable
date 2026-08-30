class_name HabilidadComboGuardian
extends HabilidadBase
## Combo de 2-3 golpes de área en cadena, cuerpo a cuerpo — la apertura más
## simple del Guardián Quebrado (fase "Guardia"). Cada golpe es un
## GolpeBasico pooled normal (área real, parriable con Corte igual que
## cualquier golpe cuerpo a cuerpo del juego, ver Combate.golpear_area()):
## la única pieza propia acá es encadenarlos con una pequeña pausa entre
## cada uno, mismo mecanismo de timer que HabilidadFlechaArquero usa para
## su pose.
##
## Sin .tscn propio a propósito — igual que HabilidadCarga, esta es una
## habilidad de MOB, no equipable por el jugador vía SlotHabilidades: se
## agrega como script node directo dentro de EnemigoGuardianQuebrado.tscn.

@export_group("Combo")
@export var cantidad_golpes: int = 3
@export var dano_por_golpe: float = 14.0
## OJO al tocar esto (o radio_golpe): el alcance FÍSICO real del golpe es
## alcance_golpe + radio_golpe — HabilidadBT.rango_maximo en ComboGuardian
## .tres decide si la IA considera "al alcance" desde más lejos que eso, y
## si queda más generoso que el alcance real el jefe "elige" atacar a
## alguien que después no llega a tocar (bug real reportado: "no le
## atinaba los golpes... solo le daba con una punta y de vaina", con el
## jugador QUIETO — no era de apuntado, era este desajuste). Mantener
## rango_maximo <= alcance_golpe + radio_golpe.
@export var alcance_golpe: float = 60.0
@export var radio_golpe: float = 56.0
@export var duracion_golpe: float = 0.15
@export var intervalo_entre_golpes: float = 0.35
@export var escena_golpe: PackedScene = preload("res://escenas/habilidades/golpe_basico/GolpeBasico.tscn")
## Si true, cada golpe del combo deja un charco de veneno (EfectoDoT) donde
## cayó — se activa al entrar la fase 2 ("Cazador"), mismo criterio que
## HabilidadBarridoGuardian.deja_charco.
@export var deja_charco: bool = false

const _ESCENA_CHARCO := preload("res://escenas/efectos/EfectoCharcoJefe.tscn")

var _id_combo := 0


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Combo"
	tipo_habilidad   = "combo_guardian"


func _ejecutar(direccion: Vector2, _poder: float) -> void:
	if not is_instance_valid(entidad_dueña):
		return
	_id_combo += 1
	var id_este := _id_combo
	var dir := direccion.normalized() if direccion.length() > 0.1 else Vector2.RIGHT
	if "memoria" in entidad_dueña:
		entidad_dueña.get("memoria").establecer("ataque_en_curso", true)
	_golpear(id_este, dir, 0)


func _golpear(id_este: int, dir: Vector2, indice: int) -> void:
	if id_este != _id_combo or not is_instance_valid(entidad_dueña):
		return
	# Reapuntar en CADA golpe del combo, no solo en el primero — bug real
	# reportado: "el jefe no apunta las habilidades encima del jugador,
	# algunas las tira antes y otras después". El combo dura hasta
	# intervalo_entre_golpes*(cantidad_golpes-1) ≈ 0.7s en total; con la
	# dirección del primer golpe reusada sin cambios, el 2º/3º golpe le
	# erraba al jugador si se había movido en el medio. Mismo criterio que
	# HabilidadBarridoGuardian/HabilidadAmagueGuardian, pero acá no hace
	# falta un _process() propio: cada golpe YA es un punto discreto en el
	# tiempo (el timer entre golpes), alcanza con recalcular acá.
	dir = _direccion_hacia_objetivo(dir)
	var animacion: AnimacionComponente = null
	if "componente_animacion" in entidad_dueña:
		animacion = entidad_dueña.componente_animacion
	if animacion:
		# Un solo estado GOLPE reutilizado en cada golpe del combo — el
		# usuario arma en el AnimationTree cuántas variantes quiere; acá
		# solo se garantiza volver a viajar ahí en cada golpe, aunque ya
		# estuviera parado en ese mismo estado (viajar_a_estado fuerza el
		# viaje, ver AnimacionComponente).
		animacion.establecer_condicion("parameters/conditions/debeGolpe", true)
		animacion.establecer_condicion("parameters/conditions/debeIdle", false)
		animacion.viajar_a_estado("GOLPE")

	var golpe := GestorPiscinas.obtener(escena_golpe) as GolpeBasico
	var origen := entidad_dueña as Node2D
	var posicion: Vector2 = origen.global_position + dir * alcance_golpe
	golpe.global_position = posicion
	golpe.configurar(_calcular_dano(int(dano_por_golpe)), radio_golpe, entidad_dueña, duracion_golpe, tipo_dano)
	if deja_charco and origen.get_tree() and origen.get_tree().current_scene:
		var charco := _ESCENA_CHARCO.instantiate()
		origen.get_tree().current_scene.add_child(charco)
		charco.global_position = posicion

	var siguiente := indice + 1
	if siguiente >= cantidad_golpes:
		get_tree().create_timer(duracion_golpe).timeout.connect(
			_al_terminar_combo.bind(id_este, animacion))
		return
	get_tree().create_timer(intervalo_entre_golpes).timeout.connect(
		_golpear.bind(id_este, dir, siguiente))


## Devuelve la dirección real hacia el objetivo actual en memoria; si no hay
## objetivo válido, mantiene "respaldo" (la última dirección conocida) en
## vez de fallar — mismo criterio que HabilidadCarga._obtener_objetivo.
func _direccion_hacia_objetivo(respaldo: Vector2) -> Vector2:
	if not (entidad_dueña and "memoria" in entidad_dueña):
		return respaldo
	var objetivo_raw = entidad_dueña.get("memoria").obtener("objetivo")
	if not is_instance_valid(objetivo_raw) or not (objetivo_raw is Node2D):
		return respaldo
	var hacia: Vector2 = (objetivo_raw as Node2D).global_position - entidad_dueña.global_position
	return hacia.normalized() if hacia.length() > 0.1 else respaldo


func _al_terminar_combo(id_este: int, animacion: AnimacionComponente) -> void:
	if id_este != _id_combo or not is_instance_valid(entidad_dueña):
		return
	if "memoria" in entidad_dueña:
		entidad_dueña.get("memoria").establecer("ataque_en_curso", false)
	if animacion and is_instance_valid(animacion):
		animacion.establecer_condicion("parameters/conditions/debeGolpe", false)
		animacion.establecer_condicion("parameters/conditions/debeIdle", true)
