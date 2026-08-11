class_name AccionAtacarArquero
extends AccionAtacar
## Variante de AccionAtacar para mobs a distancia (por ahora, el Esqueleto
## Arquero): sobreescribe SOLO el punto de reposicionamiento en
## recuperación.
##
## AccionAtacar._elegir_destino_reposicionamiento() orbita a la distancia
## ACTUAL del agente al objetivo — tiene sentido para un mob cuerpo a
## cuerpo (mantiene la cercanía que ya tenía), pero para un mob a distancia
## termina siendo un problema: si el jugador se acercó durante el disparo
## (más probable ahora que dura más, ver HabilidadFlechaArquero: pose +
## cooldown en vez de disparo instantáneo), "la distancia actual" ya viene
## reducida, y cada ciclo de reposicionamiento la confirma un poco más
## cerca en vez de volver a alejarse hacia su rango — reportado por el
## usuario: "quedan muy cerca del jugador".
##
## Acá en cambio apunta cerca del RANGO MÁXIMO de disparo (90%, no el 100%
## exacto: un margen para no quedar justo en el borde, que con el mínimo
## movimiento del jugador ya lo saca de rango y fuerza un reacercarse de
## más). Mismo criterio de ángulo aleatorio que la clase base — no se toca
## esa parte.
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
