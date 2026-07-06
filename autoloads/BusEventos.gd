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

# ── JUEGO ─────────────────────────────────────────────────────────────────────
signal juego_pausado()
signal juego_reanudado()
## Emitida para solicitar un cambio de escena (ruta_escena).
signal cambio_escena_solicitado(ruta_escena: String)
