class_name HabilidadAcumulacion
extends HabilidadBase
## "Acumulación": self-buff activable, NO instantáneo. Al usarla, empieza a
## anotar TODO el daño que recibís (sin reducirlo) durante hasta
## duracion_acumulacion segundos. Se corta antes si volvés a usar la misma
## habilidad — en los dos casos estalla, devolviendo porcentaje_detonacion
## de lo acumulado en radio_detonacion alrededor tuyo, y AHÍ (no al
## activarla) arranca la recarga real. Ver AcumulacionDanoComponente.
##
## La recarga normal de HabilidadBase arranca apenas se presiona el botón
## (ver HabilidadBase.activar/_iniciar_recarga) — acá eso se revierte a
## propósito en la primera presión: mientras se está acumulando, el botón
## tiene que seguir disponible para la segunda presión (detonar antes de
## tiempo), y recién detonar pone la recarga de verdad.

@export_group("Acumulación")
@export var duracion_acumulacion: float = 8.0
@export_range(0.0, 2.0) var porcentaje_detonacion: float = 0.3
@export var radio_detonacion: float = 60.0
## Ícono que muestra BarraBuffs mientras está acumulando.
@export var icono_buff: Texture2D = null

var _componente: AcumulacionDanoComponente = null


func _ready() -> void:
	super._ready()
	nombre_habilidad = "Acumulación"
	tipo_habilidad   = "acumulacion"
	requiere_direccion = false


## El ícono del buff tiene que ser el mismo que ves en el botón — pedido
## del usuario, ver la nota igual en HabilidadCamuflaje.
func aplicar_datos(d: DatosHabilidad) -> void:
	super.aplicar_datos(d)
	if d.icono:
		icono_buff = d.icono


## Detonar antes de tiempo (segunda presión) es gratis — se anula el costo
## de energía SOLO para esa presión puntual, restaurando el valor real
## apenas termina, para no afectar la próxima activación normal.
func activar(direccion: Vector2 = Vector2.ZERO, poder: float = 1.0) -> void:
	var costo_real := costo_energia
	if is_instance_valid(entidad_dueña):
		var comp := entidad_dueña.get_node_or_null("AcumulacionDanoComponente") as AcumulacionDanoComponente
		if comp != null and comp.esta_activa():
			costo_energia = 0.0
	super.activar(direccion, poder)
	costo_energia = costo_real


func _ejecutar(_direccion: Vector2, _poder: float) -> void:
	if not is_instance_valid(entidad_dueña):
		return
	_asegurar_componente()

	if _componente.esta_activa():
		_componente.detonar_ahora()
		return

	# HabilidadBase.activar() ya puso la recarga completa (_iniciar_recarga
	# corre ANTES de llegar acá) — se cancela: mientras se acumula, el botón
	# sigue disponible para la segunda presión, y recién _al_detonar() pone
	# la recarga real.
	_recarga_restante = 0.0
	recarga_terminada.emit(self)
	BusEventos.recarga_terminada.emit(entidad_dueña, slot_index)

	_componente.activar(duracion_acumulacion, porcentaje_detonacion, radio_detonacion, int(tipo_dano))

	# El botón cambia de color mientras dura esta segunda etapa — pedido del
	# usuario: sin esto, el botón se veía igual "recién presionado" que
	# "acumulando", y no había forma de saber a simple vista en qué etapa
	# estaba sin fijarse en el ícono de BuffsComponente aparte.
	BusEventos.habilidad_fase_cambiada.emit(entidad_dueña, slot_index, true)

	if icono_buff != null:
		var buffs := entidad_dueña.get_node_or_null("BuffsComponente") as BuffsComponente
		if buffs == null:
			buffs = BuffsComponente.new()
			buffs.name = "BuffsComponente"
			entidad_dueña.add_child(buffs)
		buffs.agregar("acumulacion", icono_buff, duracion_acumulacion, false, "Acumulación",
			"Acumula el %d%% del daño que recibís" % int(porcentaje_detonacion * 100.0))


## Consultado por UIHabilidad (duck-typed, has_method) al mostrar este botón
## de nuevo después de haber mostrado otra cosa (cambiar de página y volver,
## reequipar) — para saber si tiene que pintarse en el color de "segunda
## etapa" YA, sin esperar a que vuelva a llegar la señal
## habilidad_fase_cambiada (que solo se emite en la TRANSICIÓN, no de
## nuevo por cada botón que empiece a representar esta habilidad).
func esta_en_fase_activa() -> bool:
	return _componente != null and _componente.esta_activa()


func _asegurar_componente() -> void:
	if _componente != null:
		return
	_componente = entidad_dueña.get_node_or_null("AcumulacionDanoComponente") as AcumulacionDanoComponente
	if _componente == null:
		_componente = AcumulacionDanoComponente.new()
		_componente.name = "AcumulacionDanoComponente"
		entidad_dueña.add_child(_componente)
	if not _componente.acumulacion_detonada.is_connected(_al_detonar):
		_componente.acumulacion_detonada.connect(_al_detonar)


## Acá arranca la recarga DE VERDAD — recién cuando estalla, sea porque se
## cumplió sola duracion_acumulacion o porque se usó la segunda presión.
func _al_detonar(_dano: float, _alcanzados: int) -> void:
	_recarga_restante = duracion_recarga
	BusEventos.recarga_iniciada.emit(entidad_dueña, slot_index, duracion_recarga)
	BusEventos.habilidad_fase_cambiada.emit(entidad_dueña, slot_index, false)
	if is_instance_valid(entidad_dueña):
		var buffs := entidad_dueña.get_node_or_null("BuffsComponente") as BuffsComponente
		if buffs:
			buffs.quitar("acumulacion")
