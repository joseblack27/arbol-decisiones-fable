extends Node
## BusEventos.gd — Hub central de señales para comunicación entre sistemas.
## Todos los sistemas del juego se comunican aquí para mantenerse desacoplados.
## Uso: BusEventos.nombre_señal.emit(argumentos)
##
## CONFIGURACIÓN: Añadir como Autoload en Proyecto > Ajustes del Proyecto > Autoloads
## Nombre del autoload: BusEventos
## Ruta: res://autoloads/BusEventos.gd

# ── JUGADOR ──────────────────────────────────────────────────────────────────
## Emitida cuando la vida del jugador cambia (vida_actual, vida_maxima).
signal salud_jugador_cambiada(vida_actual: float, vida_maxima: float)
## Emitida cuando el jugador muere.
signal jugador_murio()
## Emitida cuando el jugador reaparece en una posición.
signal jugador_reaparecio(posicion: Vector2)

# ── COMBATE ──────────────────────────────────────────────────────────────────
## Emitida cuando una entidad aplica daño a otra (objetivo, cantidad, fuente).
signal daño_aplicado(objetivo: Node, cantidad: float, fuente: Node)
## Solo en clientes puros: daño real replicado desde el servidor, con el
## nombre del atacante YA resuelto como texto — incluso si el nodo atacante
## no existe en este peer (mob invisible: se deriva de la ruta que mandó el
## servidor y se marca "[invisible]"). El log de Actividad Reciente usa esta
## señal en red; daño_aplicado sigue siendo la señal general (números de
## daño, etc.), pero su "fuente: Node" es null cuando el nodo no está acá.
signal daño_replicado(objetivo: Node, cantidad: float, nombre_fuente: String)
## Emitida cuando una entidad recibe daño (objetivo, cantidad).
signal daño_recibido(objetivo: Node, cantidad: float)
## Emitida cuando cualquier entidad muere.
signal entidad_murio(entidad: Node)

# ── HABILIDADES ──────────────────────────────────────────────────────────────
## Emitida cuando una entidad usa una habilidad (entidad, tipo_habilidad).
signal habilidad_usada(entidad: Node, tipo_habilidad: String)
## Emitida cuando una habilidad impacta a un objetivo (tipo_habilidad, objetivo).
signal habilidad_impacto(tipo_habilidad: String, objetivo: Node)
## Emitida cuando una habilidad entra en recarga (entidad, slot_index, duracion).
## slot_index = -1 para habilidades que no están en un slot (enemigos, etc.).
signal recarga_iniciada(entidad: Node, slot_index: int, duracion: float)
## Emitida cuando la recarga de una habilidad termina (entidad, slot_index).
signal recarga_terminada(entidad: Node, slot_index: int)

# ── ENERGÍA ──────────────────────────────────────────────────────────────────
## Emitida cuando la energía de una entidad cambia (entidad, nueva, maxima).
signal energia_cambiada(entidad: Node, nueva: float, maxima: float)

# ── EQUIPAMIENTO ──────────────────────────────────────────────────────────────
## Emitida cuando una habilidad es equipada en un slot (entidad, slot_index, habilidad).
signal habilidad_equipada(entidad: Node, slot_index: int, habilidad: HabilidadBase)

# ── INVENTARIO ────────────────────────────────────────────────────────────────
## Emitida cuando se añade un ítem al inventario del jugador (ítem, cantidad
## añadida en esa operación — puede ser una entrada nueva o una suma a una pila).
signal item_agregado(item: DatosItem, cantidad: int)
## Emitida cuando cambia el equipo puesto (equipar, quitar o reemplazar
## cualquier pieza) — trae la lista completa de ítems equipados en ese momento.
signal equipo_cambiado(equipados: Array[DatosItem])

# ── EXPERIENCIA ───────────────────────────────────────────────────────────────
## Emitida cuando el jugador gana experiencia (cantidad ganada, xp total
## acumulada).
signal xp_agregada(cantidad: int, xp_total: int)
## Emitida cuando el jugador sube de nivel (ver TablaNiveles/
## ExperienciaComponente). Si una ganancia grande de XP cruza varios
## niveles de una vez, se emite una vez por nivel alcanzado.
signal nivel_subido(nivel_nuevo: int)

# ── JUEGO ─────────────────────────────────────────────────────────────────────
signal juego_pausado()
signal juego_reanudado()
## Emitida para solicitar un cambio de escena (ruta_escena).
signal cambio_escena_solicitado(ruta_escena: String)
