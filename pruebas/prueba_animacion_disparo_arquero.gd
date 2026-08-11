# =============================================================================
# Prueba de la animación de disparo del Esqueleto Arquero: HabilidadFlecha
# Arquero._ejecutar() debe:
#   1. Entrar al estado ATACAR del AnimationTree (condiciones "debeAtacar"/
#      "debeIdle", ver EnemigoEsqueletoArquero.tscn) y avisar a la memoria
#      del BT ("ataque_en_curso") para que el cuerpo se quede quieto —
#      AccionAtacar corta su reposicionamiento mientras esa clave sea true
#      (mismo mecanismo que ya usa HabilidadCarga para la mordida del Lobo).
#   2. NO spawnear la flecha todavía.
#   3. Recién tras duracion_pose_ataque segundos: spawnear la flecha de
#      verdad, liberar "ataque_en_curso" y volver a debeIdle — a partir de
#      ahí es cuando AccionAtacar vuelve a reposicionarse/reintentar.
#
# Pedido explícito del usuario: "que se quede quieto hasta que termine la
# animación, y después de terminar es cuando sale la flecha, entra en el
# cooldown y pasa al siguiente estado" — versión anterior de esta prueba
# disparaba la flecha instantáneo y solo sostenía la pose en paralelo.
#
# Llama _ejecutar() directo (no activar()): prueba justo el punto donde
# vive el cambio (el hook cross-peer-seguro, ver HabilidadBase._reproducir_
# visual_red) sin depender de cooldown/energía, ajeno a lo que se prueba acá.
#   godot --headless --path . --script res://pruebas/prueba_animacion_disparo_arquero.gd
# =============================================================================
extends SceneTree

var _jugador
var _mob
var _habilidad
var _tree: AnimationTree
var _gestor_piscinas: Node
var _ruta_proyectil: String
var _fase := 0
var _contador := 0
var _proyectiles_antes := 0

var _ok_al_disparar := false
var _ok_sin_flecha_todavia := false
var _ok_sostiene_pose_y_quieto := false
var _ok_dispara_y_libera_tras_pose := false
## Reportado por el usuario: el arquero parpadeaba entre IDLE y ATACAR
## mientras se preparaba — causa: Enemigo._aplicar_presentacion() corre
## TODOS los fotogramas y pisaba debeIdle a true (el mob está quieto)
## encima del debeIdle=false que HabilidadFlechaArquero acababa de poner.
## A diferencia de _ok_sostiene_pose_y_quieto (una sola foto a los ~1.0s),
## esto chequea CADA fotograma de la ventana: una foto suelta podía pasar
## por casualidad aunque estuviera parpadeando.
var _ok_sin_parpadeo_debeidle := true


func _process(_delta: float) -> bool:
	match _fase:
		0:
			_montar()
			_fase = 1
		1:
			_probar_disparo_inicial()
			_fase = 2
		2:
			if _avanzar_sostiene_pose():
				_fase = 3
		3:
			if _avanzar_dispara_tras_pose():
				return _informar()
	return false


func _montar() -> void:
	_jugador = (load("res://escenas/jugador/Jugador.tscn") as PackedScene).instantiate()
	root.add_child(_jugador)
	_jugador.global_position = Vector2.ZERO

	_mob = (load("res://escenas/enemigos/EnemigoEsqueletoArquero.tscn") as PackedScene).instantiate()
	root.add_child(_mob)
	_mob.global_position = Vector2(300, 0)

	_habilidad = _mob.get_node("Habilidades/HabilidadFlecha")
	_tree = _mob.get_node("AnimacionComponente/AnimationTree")
	_ruta_proyectil = _habilidad.escena_proyectil.resource_path
	# get_node("/root/...") en vez del identificador global GestorPiscinas:
	# referenciarlo directo en el texto de un --script NUEVO falla la
	# compilación ("Identifier not found") porque en ese modo el autoload
	# no está resuelto todavía en el momento en que se compila ESTE script
	# (ver memoria del proyecto) — el truco de cargar Jugador.tscn primero
	# solo ayuda a las ESCENAS que se cargan después, no al propio texto de
	# este archivo.
	_gestor_piscinas = root.get_node("/root/GestorPiscinas")


func _contar_proyectiles_activos() -> int:
	var total := 0
	for nodo in _gestor_piscinas._activos:
		if nodo.scene_file_path == _ruta_proyectil:
			total += 1
	return total


func _probar_disparo_inicial() -> void:
	_proyectiles_antes = _contar_proyectiles_activos()
	_habilidad._ejecutar(Vector2.DOWN, 1.0)
	_ok_al_disparar = _tree.get("parameters/conditions/debeAtacar") == true \
		and _tree.get("parameters/conditions/debeIdle") == false \
		and _mob.memoria.obtener("ataque_en_curso", false) == true
	_ok_sin_flecha_todavia = _contar_proyectiles_activos() == _proyectiles_antes
	print("Al disparar: entra a ATACAR + ataque_en_curso=true (esperado true): %s" % _ok_al_disparar)
	print("Al disparar: la flecha NO salió todavía (esperado true): %s" % _ok_sin_flecha_todavia)
	_contador = 0


func _avanzar_sostiene_pose() -> bool:
	_contador += 1
	if _tree.get("parameters/conditions/debeIdle") == true:
		_ok_sin_parpadeo_debeidle = false
	if _contador < 60:  # ~1.0s de 1.2s de duracion_pose_ataque: todavía sostenida.
		return false
	_ok_sostiene_pose_y_quieto = _tree.get("parameters/conditions/debeAtacar") == true \
		and _mob.memoria.obtener("ataque_en_curso", false) == true \
		and _contar_proyectiles_activos() == _proyectiles_antes
	print("A ~1.0s: sigue en pose, quieto y sin flecha todavía (esperado true): %s" % _ok_sostiene_pose_y_quieto)
	_contador = 0
	return true


func _avanzar_dispara_tras_pose() -> bool:
	_contador += 1
	if _contador < 30:  # +0.5s más (~1.5s totales desde el disparo): ya pasó 1.2s.
		return false
	_ok_dispara_y_libera_tras_pose = _tree.get("parameters/conditions/debeAtacar") == false \
		and _tree.get("parameters/conditions/debeIdle") == true \
		and _mob.memoria.obtener("ataque_en_curso", false) == false \
		and _contar_proyectiles_activos() == _proyectiles_antes + 1
	print("Pasado 1.2s: vuelve a idle, se libera el movimiento y SALE la flecha (esperado true): %s" % _ok_dispara_y_libera_tras_pose)
	return true


func _informar() -> bool:
	print("Sin parpadeo de debeIdle durante toda la pose (esperado true): %s" % _ok_sin_parpadeo_debeidle)
	var exito := _ok_al_disparar and _ok_sin_flecha_todavia and _ok_sostiene_pose_y_quieto \
		and _ok_dispara_y_libera_tras_pose and _ok_sin_parpadeo_debeidle
	print("PRUEBA ANIMACIÓN DISPARO ARQUERO %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
