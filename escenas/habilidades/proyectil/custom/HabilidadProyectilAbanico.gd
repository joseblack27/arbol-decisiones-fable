class_name HabilidadProyectilAbanico
extends HabilidadProyectil
## Dispara varios proyectiles a la vez, repartidos en abanico alrededor de
## la dirección apuntada. PLANTILLA genérica: cambiar cantidad_proyectiles/
## angulo_total_grados en el Inspector (o en una escena .tscn derivada, ver
## HabilidadProyectilAbanico.tscn) alcanza para cualquier variante — 3 balas
## cerradas, 7 en semicírculo, etc. — sin tocar código.
##
## Reutiliza TODA la config heredada de HabilidadProyectil (escena_proyectil,
## alcance, daño, tipo_dano...); solo cambia CUÁNTAS direcciones dispara.

## Cuántos proyectiles salen por activación.
@export_range(2, 20, 1) var cantidad_proyectiles: int = 3
## Ángulo total (grados) que abarca el abanico, centrado en la dirección
## apuntada. Ej.: 60° con 3 proyectiles = disparos a -30°/0°/+30°.
@export_range(0.0, 360.0, 1.0) var angulo_total_grados: float = 30.0

func _ready() -> void:
	super._ready()
	nombre_habilidad = "Proyectil en abanico"
	tipo_habilidad   = "proyectil_abanico"

func _ejecutar(direccion: Vector2, poder: float) -> void:
	if cantidad_proyectiles <= 1:
		super._ejecutar(direccion, poder)
		return
	var angulo_total := deg_to_rad(angulo_total_grados)
	var paso := angulo_total / (cantidad_proyectiles - 1)
	var angulo_inicial := -angulo_total / 2.0
	for i in cantidad_proyectiles:
		# Cada disparo pasa por el _ejecutar() de HabilidadProyectil tal
		# cual (mismo pool de proyectiles, mismo cálculo de daño con su
		# propio roll aleatorio) — solo cambia la dirección rotada.
		super._ejecutar(direccion.rotated(angulo_inicial + paso * i), poder)
