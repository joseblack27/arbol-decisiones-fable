# =============================================================================
# Prueba de la descripción del buff de Aura (BuffsComponente) — dos bugs
# reportados por el usuario:
#   1. "tengo intervalo tick en 0,5 y allá sale 1s": %.0f redondeaba el
#      intervalo a un entero. Ahora debe mostrar "0.5s" tal cual, y seguir
#      mostrando "1s" (sin decimal) para el valor redondo de fábrica.
#   2. "no sale el daño, colócale el daño en la lista de buff también a
#      aura": la descripción debe incluir el rango de daño YA escalado por
#      multiplicador_dano_tick — el mismo que muestra "Daño Calculado" en
#      el detalle de la habilidad (aura.tres: dano_base_min/max=6/8).
#   3. "el daño que se muestra... no es el calculado para el aura": la
#      primera versión de (2) se saltaba los atributos del jugador (bono
#      plano de daño + potencia) — con un jugador con +4 de daño plano, el
#      rango real pasa a ser (6+4)*0.5=5 a (8+4)*0.5=6, no 3-4.
#   godot --headless --path . --script res://pruebas/prueba_aura_descripcion_buff.gd
# =============================================================================
extends SceneTree

var _jugador
var _habilidad
var _buffs
var _fotogramas := 0

var _muestra_intervalo_fraccionario := false
var _muestra_intervalo_redondo_sin_decimal := false
var _muestra_rango_de_dano_calculado := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		3:
			_probar_intervalo_fraccionario()
		5:
			_probar_intervalo_redondo()
		7:
			_probar_rango_de_dano()
			return _informar()
	return false


func _montar() -> void:
	_jugador = CharacterBody2D.new()
	_jugador.add_to_group("jugadores")
	root.add_child(_jugador)

	# Con bono de daño plano (sin AtributosComponente, la primera versión
	# del fix daba el mismo resultado con o sin atributos, así que un
	# jugador "en blanco" no habría detectado el bug reportado).
	var atrib_comp = (load("res://componentes/AtributosComponente.gd") as GDScript).new()
	atrib_comp.name = "AtributosComponente"
	var base := AtributosBase.new()
	base.danos = 4.0
	atrib_comp.base = base
	_jugador.add_child(atrib_comp)

	var contenedor := Marker2D.new()
	contenedor.name = "HabilidadesPrueba"
	_jugador.add_child(contenedor)

	var escena := load("res://escenas/habilidades/aura/HabilidadAura.tscn") as PackedScene
	_habilidad = escena.instantiate()
	_habilidad.slot_index = 0
	contenedor.add_child(_habilidad)
	_habilidad.entidad_dueña = _jugador
	_habilidad.icono_buff = load("res://icon.svg")
	_habilidad.costo_energia = 0.0


func _ultima_descripcion() -> String:
	_buffs = _jugador.get_node_or_null("BuffsComponente")
	if _buffs == null:
		return ""
	var buff = _buffs.obtener("aura_dano")
	return buff.descripcion if buff else ""


func _probar_intervalo_fraccionario() -> void:
	_habilidad.intervalo_tick = 0.5
	_habilidad._ejecutar(Vector2.ZERO, 1.0)
	var descripcion := _ultima_descripcion()
	_muestra_intervalo_fraccionario = descripcion.contains("0.5s")
	print("Intervalo 0.5 se muestra como '0.5s' (esperado true): %s (\"%s\")" % [
		_muestra_intervalo_fraccionario, descripcion])


func _probar_intervalo_redondo() -> void:
	_habilidad.intervalo_tick = 1.0
	_habilidad._ejecutar(Vector2.ZERO, 1.0)
	var descripcion := _ultima_descripcion()
	_muestra_intervalo_redondo_sin_decimal = descripcion.contains("1s") and not descripcion.contains("1.0s")
	print("Intervalo 1.0 se muestra como '1s' sin decimal (esperado true): %s (\"%s\")" % [
		_muestra_intervalo_redondo_sin_decimal, descripcion])


func _probar_rango_de_dano() -> void:
	var datos := load("res://recursos/habilidades/aura.tres") as DatosHabilidad
	_habilidad.aplicar_datos(datos)
	_habilidad.multiplicador_dano_tick = 0.5
	_habilidad._ejecutar(Vector2.ZERO, 1.0)
	var descripcion := _ultima_descripcion()
	# aura.tres: dano_base_min/max = 6/8, +4 de bono plano del jugador ->
	# (6+4)*0.5=5 a (8+4)*0.5=6.
	_muestra_rango_de_dano_calculado = descripcion.contains("5-6")
	print("Muestra el rango de daño calculado, con atributos, '5-6' (esperado true): %s (\"%s\")" % [
		_muestra_rango_de_dano_calculado, descripcion])


func _informar() -> bool:
	var exito := _muestra_intervalo_fraccionario and _muestra_intervalo_redondo_sin_decimal \
		and _muestra_rango_de_dano_calculado
	print("PRUEBA AURA DESCRIPCION BUFF %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
