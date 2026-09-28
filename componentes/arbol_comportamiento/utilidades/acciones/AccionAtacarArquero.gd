class_name AccionAtacarArquero
extends AccionAtacar
## Variante de AccionAtacar para mobs a distancia (por ahora, el Esqueleto
## Arquero): sobreescribe SOLO el punto de reposicionamiento en recuperación.
##
## AccionAtacar._elegir_destino_reposicionamiento() orbita a la distancia
## ACTUAL al objetivo: bien para un mob cuerpo a cuerpo, pero si el jugador se
## acercó durante el disparo (la pose de HabilidadFlechaArquero lo hace más
## probable), cada ciclo confirmaría una distancia cada vez menor y el arquero
## quedaría pegado al jugador.
##
## Acá apunta cerca del RANGO MÁXIMO de disparo (90%, no el 100%: justo en el
## borde, cualquier movimiento del jugador lo saca de rango). El ángulo
## aleatorio es el mismo de la clase base.
func _elegir_destino_reposicionamiento(agente: Node2D, objetivo: Node2D) -> void:
	var vector_actual := agente.global_position - objetivo.global_position
	if vector_actual.length() < 1.0:
		vector_actual = Vector2.RIGHT
	var distancia_destino := _distancia_maxima() * 0.9
	var dispersion := deg_to_rad(dispersion_angulo_reposicionamiento_grados)
	var magnitud := randf_range(dispersion * 0.5, dispersion)
	if randf() < 0.5:
		magnitud = -magnitud
	var angulo := vector_actual.angle() + magnitud
	_destino_reposicionamiento = objetivo.global_position + Vector2.from_angle(angulo) * distancia_destino
	_tiene_destino_reposicionamiento = true
