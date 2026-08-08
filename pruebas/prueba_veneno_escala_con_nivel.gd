# =============================================================================
# El DoT de Veneno (EfectoVeneno.dano_por_tick) tiene que escalar IGUAL que
# el golpe inicial cuando la habilidad sube de nivel de mejora — antes
# quedaba fijo en el valor de fábrica de EfectoVenenoFlecha.tres sin
# importar cuánto se hubiera invertido en la habilidad (reportado: "no se
# ve afectado por la subida de nivel", "que surja efecto en el cálculo").
# Ver Proyectil.dano_para_efecto_tick / HabilidadProyectil._ejecutar().
#
# Cubre:
#   1. Con el daño REAL configurado en recursos/habilidades/veneno.tres
#      (dano_base_min/max + escalado) y un nivel de mejora comprado, el
#      EfectoVeneno que deja el impacto usa el daño YA ESCALADO como
#      dano_por_tick — no el fijo de fábrica de la escena del efecto.
#   2. Una habilidad SIN daño configurado (_dano_min == _dano_max == 0,
#      caso de las armadas a mano como las de jefe, que nunca pasan por
#      aplicar_datos) deja el dano_por_tick de fábrica del efecto intacto
#      — el escalado no debe pisarlo.
#   godot --headless --path . --script res://pruebas/prueba_veneno_escala_con_nivel.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _atacante
var _mob
var _habilidad_con_escalado
var _atacante2
var _mob2
var _habilidad_sin_dano

var _tick_escala_con_nivel_ok := false
var _sin_dano_configurado_no_pisa_tick_ok := false


## Tope generoso de fotogramas en vez de un frame fijo de chequeo — bajo
## contención (otro proceso de Godot corriendo en paralelo, ver
## correr_todas.sh) el viaje del proyectil puede tardar más fotogramas de
## PROCESO de los que tomaría en un entorno despejado; lo que importa es
## que EVENTUALMENTE impacte, no en qué fotograma exacto lo hace.
const TOPE_FOTOGRAMAS := 300

func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		6:
			_habilidad_con_escalado.activar(Vector2.RIGHT, 1.0)
			_habilidad_sin_dano.activar(Vector2.RIGHT, 1.0)
	if _fotogramas > 6:
		var ambos_impactaron := _buscar_efecto_veneno(_mob) != null and _buscar_efecto_veneno(_mob2) != null
		if ambos_impactaron or _fotogramas >= TOPE_FOTOGRAMAS:
			_verificar()
			return _informar()
	return false


func _buscar_efecto_veneno(mob: Node):
	for hijo in mob.get_children():
		if "dano_por_tick" in hijo and "id_debuff" in hijo:
			return hijo
	return null


## Objetivo mínimo SIN inteligencia artificial (mismo patrón que
## prueba_gancho.gd) — un EnemigoRaton.tscn real deambula por su cuenta, y
## ese movimiento autónomo podía sacarlo de la línea recta del disparo
## antes del impacto (fallo intermitente observado con dos mobs a la vez).
## Quieto en su lugar, el impacto es 100% determinístico.
static func _script_objetivo() -> GDScript:
	var guion := GDScript.new()
	guion.source_code = """
extends CharacterBody2D
func quitar_vida(_cantidad: float, _fuente: Node = null, _tipo: int = 2, _critico: bool = false) -> void:
	pass
"""
	guion.reload()
	return guion


func _crear_objetivo(posicion: Vector2) -> CharacterBody2D:
	var objetivo := CharacterBody2D.new()
	objetivo.set_script(_script_objetivo())
	objetivo.add_to_group("enemigos")
	objetivo.collision_layer = 2
	objetivo.global_position = posicion
	root.add_child(objetivo)
	var forma := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 12.0
	forma.shape = circ
	objetivo.add_child(forma)
	return objetivo


func _montar() -> void:
	# Escenario 1: CON daño configurado — veneno.tres real (ya trae su
	# propio escalado de daño, cargado tal cual desde disco).
	_atacante = Node2D.new()
	_atacante.add_to_group("jugadores")
	root.add_child(_atacante)
	current_scene = _atacante
	_atacante.global_position = Vector2(0, 0)

	var datos_veneno := load("res://recursos/habilidades/veneno.tres") as DatosHabilidad

	var guion := load("res://escenas/habilidades/proyectil/HabilidadProyectil.gd") as GDScript
	_habilidad_con_escalado = guion.new()
	_habilidad_con_escalado.entidad_dueña = _atacante
	_atacante.add_child(_habilidad_con_escalado)
	_habilidad_con_escalado.escena_proyectil = load("res://escenas/habilidades/veneno/ProyectilVeneno.tscn")
	_habilidad_con_escalado.aplicar_datos(datos_veneno)
	_habilidad_con_escalado.preparar_escalado(datos_veneno.escalado)
	_habilidad_con_escalado.aplicar_nivel_mejora(3)  # 2 niveles comprados

	_mob = _crear_objetivo(Vector2(60, 0))

	# Escenario 2: SIN daño configurado — nunca pasa por aplicar_datos(),
	# _dano_min/_dano_max quedan en su default 0 (como una habilidad de
	# jefe armada a mano en su propia escena).
	_atacante2 = Node2D.new()
	root.add_child(_atacante2)
	_atacante2.global_position = Vector2(0, 200)

	_habilidad_sin_dano = guion.new()
	_habilidad_sin_dano.entidad_dueña = _atacante2
	_atacante2.add_child(_habilidad_sin_dano)
	_habilidad_sin_dano.escena_proyectil = load("res://escenas/habilidades/veneno/ProyectilVeneno.tscn")

	_mob2 = _crear_objetivo(Vector2(60, 200))


func _verificar() -> void:
	# nivel_mejora=3 -> tabla índice 2 -> dano_min=12.0, dano_max=14.0 (ver
	# recursos/habilidades/veneno.tres).
	var efecto1: Node = _buscar_efecto_veneno(_mob)
	var tick1: float = efecto1.dano_por_tick if efecto1 else -1.0
	print("Efecto de veneno encontrado en el mob 1 (esperado true): %s" % (efecto1 != null))
	print("dano_por_tick escalado por el nivel (esperado 12-14): %.1f" % tick1)
	_tick_escala_con_nivel_ok = efecto1 != null and tick1 >= 12.0 and tick1 <= 14.0

	var efecto2: Node = _buscar_efecto_veneno(_mob2)
	var tick2: float = efecto2.dano_por_tick if efecto2 else -1.0
	print("dano_por_tick SIN daño configurado, sin pisar (esperado 8.0 de fábrica): %.1f" % tick2)
	_sin_dano_configurado_no_pisa_tick_ok = efecto2 != null and is_equal_approx(tick2, 8.0)


func _informar() -> bool:
	var exito := _tick_escala_con_nivel_ok and _sin_dano_configurado_no_pisa_tick_ok
	print("  dano por tick escala con el nivel de mejora: %s" % _tick_escala_con_nivel_ok)
	print("  sin daño configurado no pisa el tick de fábrica: %s" % _sin_dano_configurado_no_pisa_tick_ok)
	print("PRUEBA VENENO ESCALA CON NIVEL %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
