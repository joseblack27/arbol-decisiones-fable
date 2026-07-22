# =============================================================================
# Prueba de HabilidadMuroJugador / Muro:
#   1. Al lanzarla aparece un Muro con la cantidad de pilares configurada,
#      centrado a "poder * alcance_maximo" en la dirección indicada (igual
#      que HabilidadAreaEfecto).
#   2. El daño es UNO POR SEGUNDO y siempre el mismo valor mientras dure
#      (se calcula una sola vez al invocar, no se vuelve a tirar por tick).
#   3. Su vida es (defensa + tenacidad) del jugador; al agotarla, se
#      destruye (el daño entra sin reducir: el muro no tiene AtributosComponente
#      propio que lo amortigüe).
#   4. bloquea_enemigos activa/desactiva la capa física de choque (Bloqueo).
#   godot --headless --path . --script res://pruebas/prueba_muro.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _contenedor: Node2D
var _jugador: CharacterBody2D
var _enemigo: CharacterBody2D
var _habilidad: Node
var _muro: Node
var _dano_entrada := 0.0
var _dano_tick_1 := 0.0
var _dano_tick_2 := 0.0
var _vida_enemigo_antes := 0.0
var _capa_bloqueo := 0
var _vida_muro_maxima := 0.0
var _defensa_muro_real := 0.0
var _contar_pilares_final := 0
var _aplico_datos_bien := false
var _proyectil_dano_muro := false
var _muro_debil: Node
var _muro_fuerte: Node
var _debil_sobrevive := false
var _debil_gasto_proyectil := false
var _fuerte_proyectil_sigue := false
var _bloqueo_mismo_equipo_ok := false


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		3:
			_muro = _buscar_muro()
			print("¿Apareció el muro?: %s" % (_muro != null))
			_contar_pilares_final = _contar_pilares(_muro)
			print("Pilares generados (esperado 3): %d" % _contar_pilares_final)
			var bloqueo: Node = _muro.get_node("Bloqueo")
			_capa_bloqueo = int(bloqueo.get("collision_layer"))
			print("Capa de bloqueo activa (esperado 4, bloquea_enemigos=true): %d" % _capa_bloqueo)
			_vida_muro_maxima = _muro.call("obtener_vida_maxima")
			print("Vida del muro = defensa+tenacidad (esperado 30): %.1f" % _vida_muro_maxima)
			_defensa_muro_real = _muro.get("_defensa")
			print("Defensa del muro = 0.5*defensa+tenacidad (esperado 20): %.1f" % _defensa_muro_real)
			# Simular la entrada real del enemigo (mismo handler que dispara la
			# física de verdad, sin depender de su timing) para probar el daño
			# AL ENTRAR — antes de que corra ni un solo tick del timer.
			_vida_enemigo_antes = _obtener_vida(_enemigo)
			_muro.call("_on_cuerpo_entro", _enemigo)
			_dano_entrada = _vida_enemigo_antes - _obtener_vida(_enemigo)
			print("Daño al entrar, antes de cualquier tick (esperado 10): %.1f" % _dano_entrada)

			_proyectil_dano_muro = _probar_proyectil_contra_muro()
		4:
			# Tick manual (en vez de esperar el Timer real), dos veces seguidas.
			_vida_enemigo_antes = _obtener_vida(_enemigo)
			_muro.call("_aplicar_tick")
		5:
			_dano_tick_1 = _vida_enemigo_antes - _obtener_vida(_enemigo)
			_vida_enemigo_antes = _obtener_vida(_enemigo)
			_muro.call("_aplicar_tick")
		6:
			_dano_tick_2 = _vida_enemigo_antes - _obtener_vida(_enemigo)
			_probar_destruccion_por_vida()
			return false
		20:
			return _informar()
	return false


func _buscar_muro() -> Node:
	# Desde que Muro se reutiliza vía GestorPiscinas (pooling), la instancia
	# real cuelga de su contenedor global, no del de esta prueba — mismo
	# criterio que ya usa _numeros_activos() más abajo para NumeroDaño.
	var contenedor_piscina := root.get_node("/root/GestorPiscinas/InstanciasPiscina")
	for hijo in contenedor_piscina.get_children():
		if hijo.name.begins_with("Muro"):
			return hijo
	return null


func _contar_pilares(muro: Node) -> int:
	if muro == null:
		return 0
	var cuenta := 0
	for hijo in muro.get_children():
		if hijo is Pilar:
			cuenta += 1
	return cuenta


func _obtener_vida(entidad: Node) -> float:
	var vida: Node = entidad.get_node("VidaComponente")
	return vida.call("obtener_vida")


## Verifica el fallback genérico añadido en Proyectil._on_area_entrada:
## un enemigo (Lobo/Araña, vía Proyectil) debe poder dañar al muro aunque
## este no tenga un VidaComponente propio — solo un método quitar_vida().
## Se invoca el handler directamente (en vez de esperar la física real) para
## que la prueba sea determinista, mismo criterio que el resto de la suite.
func _probar_proyectil_contra_muro() -> bool:
	# Sin tipar como Proyectil: ese script referencia GestorPiscinas, y
	# tiparlo estáticamente aquí forzaría compilarlo antes de que los
	# autoloads existan (mismo artefacto de --script de siempre).
	var proyectil: Node = (load("res://escenas/habilidades/proyectil/Proyectil.gd") as GDScript).new()
	_contenedor.add_child(proyectil)
	proyectil.call("configurar", Vector2.RIGHT, 1.0, 8.0, _enemigo, Enums.Habilidad.TipoDano.FISICO)

	var contenedor_piscina := root.get_node("/root/GestorPiscinas/InstanciasPiscina")
	var numeros_antes := _numeros_activos(contenedor_piscina)
	var vida_antes: float = _muro.call("obtener_vida")
	proyectil.call("_on_area_entrada", _muro)
	var vida_despues: float = _muro.call("obtener_vida")
	var numeros_despues := _numeros_activos(contenedor_piscina)
	proyectil.queue_free()

	var dano_aplicado := is_equal_approx(vida_antes - vida_despues, 8.0)
	var sin_numero_flotante := numeros_despues == numeros_antes
	print("Proyectil enemigo dañó al muro sin VidaComponente propio (esperado 8.0): %.1f" % (vida_antes - vida_despues))
	print("Sin número flotante al chocar con el muro (esperado true): %s" % sin_numero_flotante)
	return dano_aplicado and sin_numero_flotante


func _numeros_activos(contenedor_piscina: Node) -> int:
	var cuenta := 0
	for hijo in contenedor_piscina.get_children():
		if hijo is NumeroDaño and hijo.visible:
			cuenta += 1
	return cuenta


func _probar_destruccion_por_vida() -> void:
	# Agotar la vida del MURO (no la del enemigo): la lleva encima, sin
	# VidaComponente aparte.
	_muro.call("quitar_vida", _muro.call("obtener_vida_maxima") + 1.0)


## Verifica Muro.recibir_impacto(): un proyectil con más "impacto"
## (penetración de armadura) que la defensa del muro lo revienta y sigue de
## largo sin gastarse; uno más débil lo absorbe (el muro sobrevive) y el
## proyectil sí se marca como gastado (_ya_impacto), tal como antes.
func _probar_impacto_vs_defensa() -> void:
	var defensa_muro := 20.0

	_muro_debil = _crear_muro_prueba(defensa_muro)
	var proyectil_debil: Node = (load("res://escenas/habilidades/proyectil/Proyectil.gd") as GDScript).new()
	_contenedor.add_child(proyectil_debil)
	proyectil_debil.call("configurar", Vector2.RIGHT, 1.0, 5.0, _enemigo, Enums.Habilidad.TipoDano.FISICO)
	proyectil_debil.call("_on_area_entrada", _muro_debil)
	_debil_gasto_proyectil = proyectil_debil.get("_ya_impacto")
	proyectil_debil.queue_free()

	# Atacante con impacto (penetración) MAYOR que la defensa del muro.
	var atacante_fuerte := CharacterBody2D.new()
	atacante_fuerte.add_to_group("enemigos")
	_contenedor.add_child(atacante_fuerte)
	var atributos_fuerte := AtributosComponente.new()
	atributos_fuerte.name = "AtributosComponente"
	var base_fuerte := AtributosBase.new()
	base_fuerte.impacto = defensa_muro + 10.0
	atributos_fuerte.base = base_fuerte
	atacante_fuerte.add_child(atributos_fuerte)

	_muro_fuerte = _crear_muro_prueba(defensa_muro)
	var proyectil_fuerte: Node = (load("res://escenas/habilidades/proyectil/Proyectil.gd") as GDScript).new()
	_contenedor.add_child(proyectil_fuerte)
	proyectil_fuerte.call("configurar", Vector2.RIGHT, 1.0, 5.0, atacante_fuerte, Enums.Habilidad.TipoDano.FISICO)
	proyectil_fuerte.call("_on_area_entrada", _muro_fuerte)
	_fuerte_proyectil_sigue = not proyectil_fuerte.get("_ya_impacto")
	proyectil_fuerte.queue_free()


## El pedido original del usuario: "solo las habilidades de los enemigos
## pueden destruir los muros del jugador y viceversa" — un proyectil
## disparado por el MISMO jugador que invocó el muro (o cualquier otro
## jugador: mismo equipo) no debe hacerle NADA de daño, ni siquiera con
## impacto (penetración) muy por encima de su defensa.
func _probar_bloqueo_mismo_equipo() -> bool:
	var muro := _crear_muro_prueba(20.0)
	var vida_antes: float = muro.call("obtener_vida")

	var proyectil: Node = (load("res://escenas/habilidades/proyectil/Proyectil.gd") as GDScript).new()
	_contenedor.add_child(proyectil)
	# Impacto altísimo (muy por encima de la defensa=20): si el chequeo de
	# equipo no bloqueara, esto rompería el muro de un solo golpe.
	var atributos_jugador := _jugador.get_node("AtributosComponente") as AtributosComponente
	atributos_jugador.base.impacto = 999.0
	proyectil.call("configurar", Vector2.RIGHT, 1.0, 5.0, _jugador, Enums.Habilidad.TipoDano.FISICO)
	var impacto_bloqueado: bool = not muro.call("recibir_impacto", 999.0, _jugador)
	proyectil.call("_on_area_entrada", muro)
	var vida_despues: float = muro.call("obtener_vida")
	atributos_jugador.base.impacto = 0.0
	proyectil.queue_free()

	var sin_dano := is_equal_approx(vida_antes, vida_despues)
	print("Muro del jugador SIN daño por su propio proyectil (esperado true): %s" % sin_dano)
	print("recibir_impacto() también bloqueado por mismo equipo (esperado true): %s" % impacto_bloqueado)
	return sin_dano and impacto_bloqueado


## Muro mínimo para el caso anterior: sin daño propio ni bloqueo, solo con
## la defensa que interesa comprobar.
func _crear_muro_prueba(defensa: float) -> Node:
	var muro := (load("res://escenas/habilidades/muro/muro.tscn") as PackedScene).instantiate()
	_contenedor.add_child(muro)
	muro.global_position = Vector2(300, 0)
	muro.call(
		"configurar", _jugador, Vector2.RIGHT, 999.0, defensa, 0.0, 100.0, false,
		1, 16.0, 8.0, load("res://escenas/habilidades/muro/pilar.tscn"), Enums.Habilidad.TipoDano.FISICO,
	)
	return muro


## Verifica que muro.tres (el DatosHabilidad real usado para equiparla desde
## el menú, vía SlotHabilidades.equipar) aplica correctamente sus valores —
## igual que haría el juego real, no solo los valores por defecto del script.
## dano_base_min/max es ahora el ÚNICO rango de daño (ya no existe un
## "dano_calculado" aparte): HabilidadBase._calcular_dano tira un entero al
## azar entre ambos.
func _probar_aplicar_datos() -> bool:
	var otra_habilidad := (load("res://escenas/habilidades/muro/HabilidadMuroJugador.tscn") as PackedScene).instantiate()
	var datos := load("res://recursos/habilidades/muro.tres") as DatosHabilidad
	otra_habilidad.call("aplicar_datos", datos)
	var costo_ok := is_equal_approx(otra_habilidad.get("costo_energia"), 35.0)
	var recarga_ok := is_equal_approx(otra_habilidad.get("duracion_recarga"), 1.0)
	var dano_min: int = otra_habilidad.get("_dano_min")
	var dano_max: int = otra_habilidad.get("_dano_max")
	var rango_ok := dano_min == 3 and dano_max == 6
	var alcance_ok := is_equal_approx(otra_habilidad.get("alcance_maximo"), 160.0)
	print("aplicar_datos(muro.tres) -> costo=%s recarga=%s rangoDaño[%d,%d]=%s alcance=%s" % [
		costo_ok, recarga_ok, dano_min, dano_max, rango_ok, alcance_ok,
	])
	otra_habilidad.free()
	return costo_ok and recarga_ok and rango_ok and alcance_ok


func _montar() -> void:
	_contenedor = Node2D.new()
	root.add_child(_contenedor)
	current_scene = _contenedor

	# Jugador de prueba: solo lo necesario para que la habilidad calcule su
	# vida (AtributosComponente) y para que la habilidad encuentre current_scene.
	_jugador = CharacterBody2D.new()
	_jugador.add_to_group("jugadores")
	_contenedor.add_child(_jugador)
	_jugador.global_position = Vector2.ZERO

	var atributos := AtributosComponente.new()
	atributos.name = "AtributosComponente"
	var base := AtributosBase.new()
	base.defensa   = 20.0
	base.tenacidad = 10.0
	atributos.base = base
	_jugador.add_child(atributos)

	# Habilidad: se asigna entidad_dueña directamente (como haría
	# SlotHabilidades antes de add_child) para no depender de una jerarquía
	# concreta en esta prueba aislada.
	_habilidad = (load("res://escenas/habilidades/muro/HabilidadMuroJugador.tscn") as PackedScene).instantiate()
	_habilidad.set("entidad_dueña", _jugador)
	_habilidad.set("cantidad_pilares", 3)
	_habilidad.set("distancia_entre_pilares", 16.0)
	_habilidad.set("radio_pilar", 8.0)
	_habilidad.set("alcance_maximo", 100.0)
	_habilidad.set("dano", 10.0)
	_habilidad.set("bloquea_enemigos", true)
	_jugador.add_child(_habilidad)

	_aplico_datos_bien = _probar_aplicar_datos()

	# Enemigo de prueba, colocado justo donde aparecerá el centro del muro
	# (dirección derecha, poder 1.0 → a 100px de distancia del jugador).
	_enemigo = CharacterBody2D.new()
	_enemigo.add_to_group("enemigos")
	_contenedor.add_child(_enemigo)
	_enemigo.global_position = Vector2(100, 0)
	var vida_enemigo := VidaComponente.new()
	vida_enemigo.name = "VidaComponente"
	vida_enemigo.salud_maxima = 200.0
	_enemigo.add_child(vida_enemigo)

	_habilidad.call("activar", Vector2.RIGHT, 1.0)

	_probar_impacto_vs_defensa()
	_bloqueo_mismo_equipo_ok = _probar_bloqueo_mismo_equipo()


func _informar() -> bool:
	# Muro real (_muro) sale de la piscina (GestorPiscinas): "destruido" ya
	# no significa is_instance_valid()==false (nunca se libera de verdad),
	# sino que volvió a la piscina — oculto e inactivo, ver Muro._al_terminar().
	# _muro_debil/_muro_fuerte NO pasan por la piscina (_crear_muro_prueba
	# los instancia directo), así que para ellos sigue valiendo is_instance_valid().
	var muro_destruido := is_instance_valid(_muro) and not (_muro as CanvasItem).visible
	_debil_sobrevive = is_instance_valid(_muro_debil)
	# _muro_fuerte se instancia a mano (_crear_muro_prueba), sin pasar por
	# GestorPiscinas.obtener() — Muro._romper() ahora llama a liberar(), que
	# no hace nada con nodos que la piscina nunca "obtuvo" (guarda contra
	# doble liberación), así que ni is_instance_valid() ni "visible" detectan
	# la rotura acá. Ver vida directamente, que sí queda en 0 pase lo que pase.
	var fuerte_rompio := is_instance_valid(_muro_fuerte) \
		and is_equal_approx(_muro_fuerte.call("obtener_vida"), 0.0)
	print("Daño del tick 1 (esperado 10): %.1f" % _dano_tick_1)
	print("Daño del tick 2 — debe ser IGUAL al del tick 1 (esperado 10): %.1f" % _dano_tick_2)
	print("Muro destruido al agotar su vida (esperado true): %s" % muro_destruido)
	print("Impacto débil (<=defensa): muro sobrevive=%s, proyectil se gastó=%s" % [
		_debil_sobrevive, _debil_gasto_proyectil,
	])
	print("Impacto fuerte (>defensa): muro se rompió=%s, proyectil sigue de largo=%s" % [
		fuerte_rompio, _fuerte_proyectil_sigue,
	])

	var exito := _contar_pilares_final == 3 \
		and is_equal_approx(_dano_entrada, 10.0) \
		and is_equal_approx(_dano_tick_1, 10.0) \
		and is_equal_approx(_dano_tick_2, _dano_tick_1) \
		and muro_destruido \
		and _capa_bloqueo == 4 \
		and is_equal_approx(_vida_muro_maxima, 30.0) \
		and is_equal_approx(_defensa_muro_real, 20.0) \
		and _aplico_datos_bien \
		and _proyectil_dano_muro \
		and _debil_sobrevive and _debil_gasto_proyectil \
		and fuerte_rompio and _fuerte_proyectil_sigue \
		and _bloqueo_mismo_equipo_ok
	print("PRUEBA MURO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
