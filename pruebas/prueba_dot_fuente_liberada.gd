# =============================================================================
# Prueba de la regresión reportada: una araña muere (queue_free) mientras su
# telaraña (EfectoDoT) sigue activa sobre un objetivo. El siguiente tick del
# DoT usaba "fuente" (la araña) ya liberada sin comprobarlo — is_instance_valid
# lo arregla tanto en EfectoDoT como en AtributosComponente.calcular_pipeline.
#   godot --headless --path . --script res://pruebas/prueba_dot_fuente_liberada.gd
# =============================================================================
extends SceneTree

var _fotogramas := 0
var _fuente: Node2D
var _objetivo: CharacterBody2D
var _vida_objetivo: VidaComponente
# Sin tipar como EfectoDoT: ese script ahora referencia BusEventos, y
# tiparlo estáticamente aquí forzaría compilarlo antes de que los
# autoloads existan (mismo artefacto de --script de siempre).
var _efecto: Node
var _vida_antes := 0.0
var _numeros_activos_antes := 0
var _bus: Node
var _contenedor_piscina: Node


func _process(_delta: float) -> bool:
	_fotogramas += 1
	match _fotogramas:
		1:
			_montar()
		3:
			# La araña muere y se libera mientras la telaraña sigue activa.
			_fuente.queue_free()
		5:
			_vida_antes = _vida_objetivo.obtener_vida()
			_numeros_activos_antes = _numeros_activos()
			# Tick manual del DoT: aquí es donde antes reventaba por acceder
			# a "fuente" ya liberada.
			_efecto.call("_aplicar_tick")
		7:
			return _informar()
	return false


func _numeros_activos() -> int:
	var cuenta := 0
	for hijo in _contenedor_piscina.get_children():
		if hijo is NumeroDaño and hijo.visible:
			cuenta += 1
	return cuenta


func _montar() -> void:
	_bus = root.get_node("/root/BusEventos")
	_contenedor_piscina = root.get_node("/root/GestorPiscinas/InstanciasPiscina")
	_fuente = Node2D.new()
	root.add_child(_fuente)

	_objetivo = CharacterBody2D.new()
	_objetivo.add_to_group(&"jugadores")
	root.add_child(_objetivo)
	_vida_objetivo = (load("res://componentes/VidaComponente.gd") as GDScript).new() as VidaComponente
	_vida_objetivo.name = "VidaComponente"
	_objetivo.add_child(_vida_objetivo)

	_efecto = (load("res://escenas/efectos/EfectoDoT.tscn") as PackedScene).instantiate()
	root.add_child(_efecto)
	_efecto.set("fuente", _fuente)
	_efecto.set("dano_por_tick", 7.0)
	# Se registra el objetivo directamente (sin depender del solape físico
	# real) para que la prueba sea determinista y rápida.
	var objetivos: Array = _efecto.get("_objetivos_actuales")
	objetivos.append(_objetivo)


func _informar() -> bool:
	var vida_despues := _vida_objetivo.obtener_vida()
	var aplico_dano := is_equal_approx(_vida_antes - vida_despues, 7.0)
	var aparecio_numero := _numeros_activos() > _numeros_activos_antes
	print("Vida antes/después del tick con fuente liberada: %.0f -> %.0f" % [_vida_antes, vida_despues])
	print("Aplicó el daño sin reventar: %s" % aplico_dano)
	print("Mostró número flotante aunque la fuente ya no exista: %s" % aparecio_numero)
	var exito := aplico_dano and aparecio_numero
	print("PRUEBA DOT FUENTE LIBERADA %s" % ("OK" if exito else "FALLIDA"))
	quit(0 if exito else 1)
	return true
