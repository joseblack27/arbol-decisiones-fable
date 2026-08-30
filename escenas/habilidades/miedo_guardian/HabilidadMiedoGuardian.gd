class_name HabilidadMiedoGuardian
extends HabilidadBase
## Grito de miedo: empuja y aturde brevemente a quien esté cerca — fase
## "Quiebre". Combina dos piezas YA existentes y probadas, sin inventar
## ningún mecanismo nuevo:
##   - MovimientoComponente.aplicar_empuje() (knockback, API pública ya usada
##     por otras habilidades).
##   - EfectoAturdir (mismo patrón que HabilidadSacudida.gd: instanciado vía
##     load(...).new(), no tiene escena .tscn propia).
##
## Pedido del diseño: sirve para confirmar EN LA PRÁCTICA que Corte se
## puede lanzar igual estando aturdido/empujado — HabilidadCorte.
## ignora_bloqueos ya lo garantiza sin tocar nada más acá.

@export_group("Miedo")
## OJO: HabilidadBT.rango_maximo en MiedoGuardian.tres tiene que quedar <=
## este radio (mismo criterio documentado en HabilidadComboGuardian
## .alcance_golpe) — es una consulta centrada en el propio jefe, no
## proyectada hacia adelante como los golpes cuerpo a cuerpo.
@export var radio: float = 100.0
@export var fuerza_empuje: float = 260.0
@export var duracion_aturdimiento: float = 0.5
## Mismo criterio que HabilidadSacudida: el ícono del debuff debería ser el
## de la propia habilidad, pisado por aplicar_datos() si se equipa con un
## DatosHabilidad real.
@export var icono_debuff: Texture2D = null

@export_group("Combo")
## Segundos tras el empujón/aturdimiento antes de encadenar el Combo real
## — pedido explícito del usuario: "un combo de habilidades que congenien
## unas con otras". Se dispara DIRECTO sobre el nodo hermano (mismo patrón
## que EnemigoGuardianQuebrado._golpear_transicion: bypassea el selector,
## llama activar() a mano), no por el árbol de comportamiento — no hace
## falta: mientras esto corre, Atacar ya está en su propia ventana de
## "recuperación" (duracion_recuperacion=0.8s en el .tscn del jefe, más
## larga que esta espera) y no intenta elegir otra habilidad por su
## cuenta, así que no hay riesgo de pisarse con un segundo ataque. Elegido
## para que caiga DENTRO de duracion_aturdimiento (0.5s): el objetivo
## sigue sin poder moverse ni actuar (salvo Corte, que ignora bloqueos a
## propósito, ver la nota de la clase) cuando el combo lo alcanza.
@export var duracion_espera_combo: float = 0.3

const MASCARA_OBJETIVOS := 0xFFFFFFFF
const _ESCENA_EFECTO := "res://escenas/efectos/EfectoAturdir.gd"


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Miedo"
	tipo_habilidad   = "miedo_guardian"
	requiere_direccion = false


func aplicar_datos(d: DatosHabilidad) -> void:
	super.aplicar_datos(d)
	if d.icono:
		icono_debuff = d.icono


func _ejecutar(_direccion: Vector2, _poder: float) -> void:
	if not is_instance_valid(entidad_dueña):
		return
	var origen := entidad_dueña as Node2D
	if origen == null:
		return

	var indicador := IndicadorZonaEfecto.new()
	indicador.radio = radio
	indicador.color_relleno = Color(0.6, 0.3, 0.8, 0.35)
	indicador.color_borde = Color(0.7, 0.4, 0.9, 0.9)
	origen.get_tree().current_scene.add_child(indicador)
	indicador.global_position = origen.global_position

	var espacio := origen.get_world_2d().direct_space_state
	var forma := CircleShape2D.new()
	forma.radius = radio
	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = forma
	consulta.transform = Transform2D(0.0, origen.global_position)
	consulta.collision_mask = MASCARA_OBJETIVOS
	consulta.collide_with_areas = false
	consulta.collide_with_bodies = true

	var objetivo_real = entidad_dueña.get("memoria").obtener("objetivo") \
		if "memoria" in entidad_dueña and entidad_dueña.get("memoria") else null

	for resultado in espacio.intersect_shape(consulta, 32):
		var cuerpo = resultado.get("collider")
		if not (cuerpo is Node) or cuerpo == entidad_dueña:
			continue
		if Combate.mismo_equipo(entidad_dueña, cuerpo):
			continue
		if (cuerpo as Node).get_node_or_null("VidaComponente") == null:
			continue
		_asustar(cuerpo as Node2D, origen)
		# El combo de seguimiento solo se dispara contra el objetivo REAL
		# que persigue la IA (nunca contra un aliado invocado que también
		# haya caído en el radio, si algún día lo hubiera) — ver el export
		# duracion_espera_combo más arriba para el porqué del timing.
		if cuerpo == objetivo_real:
			_programar_combo_de_seguimiento(cuerpo as Node2D)


func _asustar(objetivo: Node2D, origen: Node2D) -> void:
	var mov := objetivo.get_node_or_null("MovimientoComponente") as MovimientoComponente
	if mov:
		var direccion := (objetivo.global_position - origen.global_position)
		direccion = direccion.normalized() if direccion.length() > 0.1 else Vector2.RIGHT
		mov.aplicar_empuje(direccion, fuerza_empuje, 0.25)

	var efecto = (load(_ESCENA_EFECTO) as GDScript).new()
	efecto.objetivo = objetivo
	efecto.duracion = duracion_aturdimiento
	efecto.icono_debuff = icono_debuff
	objetivo.add_child(efecto)


## Dispara HabilidadComboGuardian directo (sin pasar por el selector) tras
## la espera — mismo criterio que _golpear_transicion(). Recalcula la
## dirección en el momento del combo (no la del instante de Miedo): el
## empujón ya movió al objetivo para entonces.
func _programar_combo_de_seguimiento(objetivo: Node2D) -> void:
	if not is_instance_valid(entidad_dueña):
		return
	var combo := entidad_dueña.get_node_or_null("Habilidades/HabilidadComboGuardian")
	if combo == null or not combo.has_method("activar"):
		return
	get_tree().create_timer(duracion_espera_combo).timeout.connect(
		_disparar_combo_de_seguimiento.bind(combo, objetivo))


## Distancia a la que el jefe se reposiciona ANTES del combo si el
## empujón dejó al objetivo más lejos que esto — bien por debajo del
## alcance real de Combo (alcance_golpe+radio_golpe ~116px, ver
## HabilidadComboGuardian), para que el combo conecte siempre, sea cual
## sea la fuerza de empuje configurada. Sin esto, fuerza_empuje (pensado
## para SEPARAR al objetivo) terminaba sacándolo del alcance del propio
## combo que se suponía debía conectar después — el mismo problema de
## "queda fuera del área del golpe" que pidió resolver el usuario, ahora
## auto-infligido por Miedo.
const _DISTANCIA_SEGURA_COMBO := 70.0

func _disparar_combo_de_seguimiento(combo: Node, objetivo: Node2D) -> void:
	if not is_instance_valid(entidad_dueña) or not is_instance_valid(objetivo) or not is_instance_valid(combo):
		return
	var jefe := entidad_dueña as Node2D
	var dir := objetivo.global_position - jefe.global_position
	if dir.length() > _DISTANCIA_SEGURA_COMBO:
		dir = dir.normalized()
		jefe.global_position = objetivo.global_position - dir * _DISTANCIA_SEGURA_COMBO
	else:
		dir = dir.normalized() if dir.length() > 0.1 else Vector2.RIGHT
	combo.activar(dir, 1.0)
