# =============================================================================
# Prueba de integración: subir distancia_minima_acercamiento (20->50) junto
# con rango_maximo de ArañazoLobo (35->70) NO deja al lobo trabado sin
# atacar nunca — el bug real y ya reproducido de esta misma zona del código
# (ver el comentario largo en AccionAtacar.distancia_minima_acercamiento):
# con un margen chico entre esas dos distancias, el mob se congela a mitad
# de camino para siempre por MovimientoComponente.MARGEN_DESTINO (6px).
#
# A diferencia de prueba_lobo_combate.gd (que solo confirma UN uso de
# habilidad), esto deja correr una ventana larga y cuenta CUÁNTOS golpes
# reales conectan (VidaComponente.quitar_vida() de verdad, no solo "eligió
# habilidad una vez") — un mob que ataca una vez y después se traba
# pasaría esa prueba vieja igual.
#
# OJO distancia mínima NO es el criterio (a diferencia de un primer intento
# de esta prueba): el Lobo tiene Carga (embestida, rango_maximo=200,
# Carga.tres), y a la distancia inicial de esta prueba es la ÚNICA
# habilidad en rango — la embestida ATRAVIESA al objetivo de lado a lado a
# toda velocidad (confirmado con un rastro fotograma a fotograma: pasa de
# ~106px a ~0.2px y de vuelta a ~106px en apenas 20 fotogramas), lo cual es
# el comportamiento correcto e intencional de una embestida, no el bug de
# "trabado". El bug real se manifiesta como golpes que DEJAN de llegar para
# siempre, no como una distancia instantánea chica — por eso el criterio acá
# es que sigan conectando golpes tanto en la primera como en la segunda
# mitad de la ventana.
#   godot --headless --path . --script res://pruebas/prueba_lobo_no_se_traba_a_distancia_nueva.gd
# =============================================================================
extends SceneTree

const _CORTE_MITAD := 400

var _fotogramas := 0
var _lobo: Node2D
var _senuelo: CharacterBody2D
var _vida_senuelo: VidaComponente
var _golpes_reales := 0
var _golpes_primera_mitad := 0
var _distancia_minima_vista := INF
var _fotograma_distancia_minima := -1
var _distancia_maxima_vista := 0.0
var _distancia_final := 0.0
var _rastro: Array[String] = []


func _process(_delta: float) -> bool:
	_fotogramas += 1
	if _fotogramas == 1:
		_montar_escena()
		return false
	if _fotogramas < 10:
		return false

	var distancia: float = _lobo.global_position.distance_to(_senuelo.global_position)
	if distancia < _distancia_minima_vista:
		_distancia_minima_vista = distancia
		_fotograma_distancia_minima = _fotogramas
	_distancia_maxima_vista = maxf(_distancia_maxima_vista, distancia)
	if _fotogramas % 20 == 0:
		_rastro.append("f%d=%.1f" % [_fotogramas, distancia])

	if _fotogramas == _CORTE_MITAD:
		_golpes_primera_mitad = _golpes_reales

	# Ventana larga (~13s a 60fps) — de sobra para varios ciclos completos de
	# ataque + recuperación + reposicionamiento (duracion_recuperacion=3s en
	# el lobo), donde un mob trabado se notaría clarísimo: se quedaría a la
	# misma distancia fija el resto de la corrida, sin que _golpes_reales
	# vuelva a subir.
	if _fotogramas > 800:
		_distancia_final = distancia
		var golpes_segunda_mitad := _golpes_reales - _golpes_primera_mitad
		print("Golpes reales que conectaron (esperado >=2): %d (1ra mitad: %d, 2da mitad: %d)" % [_golpes_reales, _golpes_primera_mitad, golpes_segunda_mitad])
		print("Distancia mínima vista (informativo, la embestida cruza al objetivo — no es el criterio): %.1fpx en fotograma %d" % [_distancia_minima_vista, _fotograma_distancia_minima])
		print("Distancia máxima vista durante combate: %.1fpx" % _distancia_maxima_vista)
		print("Distancia final (esperado en la zona de distancia_minima_acercamiento~50 o de reposicionamiento cercano): %.1fpx" % _distancia_final)
		print("Rastro (cada 20 fotogramas): %s" % ", ".join(_rastro))
		# El criterio real: golpes en AMBAS mitades (nunca dejó de atacar por
		# un tramo largo) y una distancia final sensata (no clavado encima
		# del objetivo ni perdido lejos).
		var exito := _golpes_primera_mitad >= 1 and golpes_segunda_mitad >= 1 \
			and _distancia_final < 150.0
		print("PRUEBA LOBO NO SE TRABA A DISTANCIA NUEVA %s" % ("OK" if exito else "FALLIDA"))
		quit(0 if exito else 1)
		return true
	return false


func _on_vida_cambiada(valor: float) -> void:
	if valor < _vida_senuelo.obtener_vida_maxima():
		_golpes_reales += 1


func _montar_escena() -> void:
	current_scene = root

	_lobo = (load("res://escenas/enemigos/EnemigoLobo.tscn") as PackedScene).instantiate()
	root.add_child(_lobo)
	_lobo.global_position = Vector2(300, 300)

	_senuelo = CharacterBody2D.new()
	_senuelo.add_to_group("jugadores")
	_vida_senuelo = VidaComponente.new()
	_vida_senuelo.name = "VidaComponente"
	_vida_senuelo.salud_maxima = 100000.0
	_vida_senuelo.collision_layer = 1
	var colision := CollisionShape2D.new()
	var forma := CircleShape2D.new()
	forma.radius = 20.0
	colision.shape = forma
	_vida_senuelo.add_child(colision)
	_senuelo.add_child(_vida_senuelo)
	root.add_child(_senuelo)
	_vida_senuelo.owner = _senuelo
	_senuelo.global_position = Vector2(460, 300)
	# Cuenta golpes reales sin importar la merma (vida_maxima gigante: no
	# muere ni interfiere con la lógica de combate del lobo a mitad de prueba).
	_vida_senuelo.cambio_valor_vida.connect(_on_vida_cambiada)
	_golpes_reales = 0
