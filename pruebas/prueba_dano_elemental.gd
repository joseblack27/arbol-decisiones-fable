# =============================================================================
# Prueba del daño elemental (Enums.Habilidad.TipoDano + resistencias):
#   1. HabilidadBase.aplicar_datos() copia tipo_dano del DatosHabilidad al
#      nodo — sin esto, toda habilidad equipada pegaba como PHYSIC sin
#      importar el elemento asignado en el .tres (el eslabón que faltaba).
#   2. calcular_dano_entrante() aplica SOLO la resistencia del elemento que
#      llega: con 50% resistencia al fuego, un golpe FIRE se reduce a la
#      mitad pero uno WATER pasa entero.
#   3. Pipeline completo (calcular_pipeline con nodos fuente/defensor):
#      mismo daño base, distinto elemento → distinto daño final según la
#      resistencia del defensor.
#   4. Los .tres elementales del catálogo tienen su tipo_dano asignado
#      (mismo criterio que costo_energia/enfriamiento: el .tres pisa a la
#      escena, así que un elemental sin tipo_dano en el .tres degradaría a
#      PHYSIC en silencio).
#   godot --headless --path . --script res://pruebas/prueba_dano_elemental.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _fuente: Node2D
var _defensor: Node2D


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		2:
			var ok := _prueba_aplicar_datos()
			ok = _prueba_resistencia_correcta() and ok
			ok = _prueba_pipeline_completo() and ok
			ok = _prueba_tres_elementales() and ok
			ok = _prueba_escenas_sin_elemento_propio() and ok
			print("PRUEBA DAÑO ELEMENTAL %s" % ("OK" if ok else "FALLIDA"))
			quit(0 if ok else 1)
			return true
	return false


func _montar() -> void:
	# Fuente sin bonos ofensivos (danos=0, potencia=0, crítico=0): así el
	# daño que entra al lado defensivo es exactamente el base y los números
	# esperados son deterministas.
	_fuente = Node2D.new()
	var atrib_fuente = (load("res://componentes/AtributosComponente.gd") as GDScript).new()
	atrib_fuente.name = "AtributosComponente"
	atrib_fuente.base = AtributosBase.new()
	_fuente.add_child(atrib_fuente)
	root.add_child(_fuente)
	current_scene = _fuente

	# Defensor con 50% de resistencia al fuego y nada más (defensa plana 0,
	# fortaleza 0) — la única mitigación posible es la elemental.
	_defensor = Node2D.new()
	var atrib_def = (load("res://componentes/AtributosComponente.gd") as GDScript).new()
	atrib_def.name = "AtributosComponente"
	var base_def := AtributosBase.new()
	base_def.resistencia_fuego = 50.0
	atrib_def.base = base_def
	_defensor.add_child(atrib_def)
	root.add_child(_defensor)


func _prueba_aplicar_datos() -> bool:
	var hab = (load("res://escenas/habilidades/base/HabilidadBase.gd") as GDScript).new()
	var datos := DatosHabilidad.new()
	datos.nombre = "Prueba"
	datos.tipo_dano = Enums.Habilidad.TipoDano.AGUA
	hab.aplicar_datos(datos)
	var ok: bool = hab.tipo_dano == Enums.Habilidad.TipoDano.AGUA
	print("aplicar_datos copia tipo_dano del .tres (esperado WATER): %s" % ok)
	hab.free()
	return ok


func _prueba_resistencia_correcta() -> bool:
	var atrib = _defensor.get_node("AtributosComponente")
	var dano_fuego: float = atrib.calcular_dano_entrante(100.0, Enums.Habilidad.TipoDano.FUEGO)
	var dano_agua: float = atrib.calcular_dano_entrante(100.0, Enums.Habilidad.TipoDano.AGUA)
	var fuego_ok := is_equal_approx(dano_fuego, 50.0)
	var agua_ok := is_equal_approx(dano_agua, 100.0)
	print("100 de FUEGO contra 50%% resist. fuego (esperado 50): %.1f" % dano_fuego)
	print("100 de AGUA contra 50%% resist. fuego (esperado 100, no lo afecta): %.1f" % dano_agua)
	return fuego_ok and agua_ok


func _prueba_pipeline_completo() -> bool:
	var dano_fuego: float = AtributosComponente.calcular_pipeline(
		_fuente, _defensor, 100.0, Enums.Habilidad.TipoDano.FUEGO)
	var dano_agua: float = AtributosComponente.calcular_pipeline(
		_fuente, _defensor, 100.0, Enums.Habilidad.TipoDano.AGUA)
	var ok := is_equal_approx(dano_fuego, 50.0) and is_equal_approx(dano_agua, 100.0)
	print("Pipeline completo fuente→defensor FIRE/WATER (esperado 50 / 100): %.1f / %.1f" % [
		dano_fuego, dano_agua,
	])
	return ok


func _prueba_tres_elementales() -> bool:
	var esperados := {
		"res://recursos/habilidades/bola_de_fuego.tres":   Enums.Habilidad.TipoDano.FUEGO,
		"res://recursos/habilidades/lanzallamas.tres":     Enums.Habilidad.TipoDano.FUEGO,
		"res://recursos/habilidades/disparo_abanico.tres": Enums.Habilidad.TipoDano.FUEGO,
		"res://recursos/habilidades/rafaga.tres":          Enums.Habilidad.TipoDano.AIRE,
		"res://recursos/habilidades/esquirla_helada.tres": Enums.Habilidad.TipoDano.AGUA,
		"res://recursos/habilidades/picos_rocosos.tres":   Enums.Habilidad.TipoDano.TIERRA,
	}
	var todos_ok := true
	for ruta: String in esperados:
		var datos := load(ruta) as DatosHabilidad
		var ok: bool = datos != null and datos.tipo_dano == esperados[ruta]
		if not ok:
			todos_ok = false
		print("%s -> tipo_dano=%s (esperado %s): %s" % [
			ruta.get_file(), datos.tipo_dano if datos else -1, esperados[ruta], ok,
		])
	return todos_ok


## El .tres es la ÚNICA fuente válida del elemento para las habilidades del
## catálogo del jugador — su .tscn ya NO debe llevar tipo_dano propio (se
## sacaron a propósito, ver aplicar_datos()). Instanciar la escena SOLA (sin
## pasar por aplicar_datos(), como haría un DatosHabilidad al equiparla)
## debe caer siempre al default de HabilidadBase (PHYSIC) — si la escena
## todavía trajera su propio tipo_dano, esto lo detectaría.
func _prueba_escenas_sin_elemento_propio() -> bool:
	var escenas := [
		"res://escenas/habilidades/proyectil/HabilidadProyectil.tscn",
		"res://escenas/habilidades/rafaga/HabilidadRafaga.tscn",
		"res://escenas/habilidades/esquirla/HabilidadEsquirla.tscn",
		"res://escenas/habilidades/lanzallamas/HabilidadLanzallamas.tscn",
		"res://escenas/habilidades/proyectil/custom/HabilidadProyectilAbanico.tscn",
	]
	var todos_ok := true
	for ruta in escenas:
		var hab := (load(ruta) as PackedScene).instantiate()
		var ok: bool = hab.tipo_dano == Enums.Habilidad.TipoDano.FISICO
		if not ok:
			todos_ok = false
		print("%s (sin aplicar_datos) -> tipo_dano=%s (esperado PHYSIC=2, ninguno propio): %s" % [
			ruta.get_file(), hab.tipo_dano, ok,
		])
		hab.free()
	return todos_ok
