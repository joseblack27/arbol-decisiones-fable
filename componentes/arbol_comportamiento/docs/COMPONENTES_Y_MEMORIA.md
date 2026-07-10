# Sección: Arquitectura por Componentes + MemoriaBT
# Patrón: Componente → Señal → Enemigo → MemoriaBT → Árbol reacciona

---

## El problema

Los componentes (VidaComponente, VisionComponente, MovimientoComponente)
no exponen sus datos directamente al árbol. El árbol solo conoce la MemoriaBT.
Necesitamos un puente: el propio Enemigo conecta las señales de sus componentes
y escribe los valores en la memoria.

```
VidaComponente  ──[señal cambio_valor_vida]──┐
VisionComponente ─[señal objetivo_detectado]─┤──► Enemigo ──► MemoriaBT ──► Árbol
MovimientoComponente ─────────────────────────┘   (hub)
```

El Enemigo actúa como coordinador: no contiene lógica de juego,
solo recibe señales y las traduce a entradas de la memoria.

---

## Enemigo.gd completo con el patrón

```gdscript
# Enemigo.gd
extends CharacterBody2D

@export var componente_vida: VidaComponente
@export var componente_maquina_de_estados: MaquinaDeEstadosComponente
@export var componente_movimiento: MovimientoComponente
@export var componente_vision: VisionComponente
@export var componente_decision: DecisionComponente
@export var memoria: MemoriaBT

@export var velocidad_base: float = 150.0
var direccion: Vector2 = Vector2.ZERO


func _ready() -> void:
    # ── 1. Escribir referencias propias en la memoria ──────────────────────────
    # Los nodos del árbol acceden a los componentes así:
    # var mov = _memoria.obtener("movimiento")
    memoria.establecer("agente",      self)
    memoria.establecer("movimiento",  componente_movimiento)
    memoria.establecer("vision",      componente_vision)

    # ── 2. Vida inicial ────────────────────────────────────────────────────────
    if componente_vida:
        memoria.establecer("vida",         componente_vida.obtener_vida())
        memoria.establecer("vida_maxima",  componente_vida.obtener_vida_maxima())
        memoria.establecer("vida_baja",    false)
        memoria.establecer("vida_cero",    false)

        # Señal emitida por VidaComponente cada vez que cambia la salud.
        componente_vida.cambio_valor_vida.connect(_on_vida_cambiada)
        # Señal emitida por VidaComponente cuando la salud llega a 0.
        componente_vida.muerte.connect(_on_muerte)

    # ── 3. Visión ──────────────────────────────────────────────────────────────
    if componente_vision:
        memoria.establecer("objetivo",           null)
        memoria.establecer("jugador_detectado",  false)

        componente_vision.objetivo_detectado.connect(_on_objetivo_detectado)
        componente_vision.objetivo_perdido.connect(_on_objetivo_perdido)

    # ── 4. Arrancar la máquina de estados ─────────────────────────────────────
    if componente_maquina_de_estados:
        componente_maquina_de_estados.cambiar_estado("IdleState")

    # ── 5. Escuchar cambios en la memoria (flags derivadas) ────────────────────
    memoria.variable_cambiada.connect(_on_memoria_variable_cambiada)


func _physics_process(delta: float) -> void:
    if componente_maquina_de_estados:
        componente_maquina_de_estados.procesar_estado(delta)


# =============================================================================
# PUENTE: Señales de componentes → MemoriaBT
# Cada método recibe la señal del componente y escribe en la memoria.
# El árbol reacciona automáticamente en el próximo tick.
# =============================================================================

func _on_vida_cambiada(nuevo_valor: float) -> void:
    # VidaComponente emite cambio_valor_vida(valor: float)
    memoria.establecer("vida", nuevo_valor)
    # Las flags derivadas se calculan en _on_memoria_variable_cambiada.


func _on_muerte(_valor: float) -> void:
    # VidaComponente emite muerte(0.0) cuando la salud llega a 0.
    memoria.establecer("vida_cero", true)
    memoria.establecer("vida",      0.0)


func _on_objetivo_detectado(area: Area2D) -> void:
    # VisionComponente emite objetivo_detectado(area) al entrar un VidaComponente.
    # area.owner es el nodo raíz del personaje detectado (el Jugador, otro Enemigo, etc.)
    memoria.establecer("objetivo",          area.owner)
    memoria.establecer("jugador_detectado", true)


func _on_objetivo_perdido(_area: Area2D) -> void:
    # VisionComponente emite objetivo_perdido(area) cuando no quedan áreas detectadas.
    memoria.establecer("objetivo",          null)
    memoria.establecer("jugador_detectado", false)


func _on_memoria_variable_cambiada(nombre: String, _anterior: Variant, _nuevo: Variant) -> void:
    # Aquí se calculan flags DERIVADAS de otras variables.
    # Solo se recalculan cuando cambia "vida" para no desperdiciar ciclos.
    if nombre == "vida":
        var v: float = memoria.obtener("vida", 100.0)
        memoria.establecer("vida_baja", v > 0.0 and v < 30.0)
        # vida_cero ya la maneja _on_muerte directamente.
```

---

## Cómo acceder a los componentes desde las Acciones del árbol

Los componentes quedan guardados en la memoria, así que cualquier
`Accion` o `Condicion` puede obtenerlos sin referencias externas:

```gdscript
# AccionMover.gd
extends Accion

@export var velocidad: float = 120.0

func _on_ejecutar() -> Estado:
    var mov: MovimientoComponente = _memoria.obtener("movimiento")
    var objetivo: Node2D          = _memoria.obtener("objetivo")
    var agente: CharacterBody2D   = _memoria.obtener("agente")

    if not mov or not objetivo or not agente:
        return Estado.FALLIDO

    var dir = (objetivo.global_position - agente.global_position).normalized()
    mov.physics_process(get_physics_process_delta_time(), dir)

    if agente.global_position.distance_to(objetivo.global_position) < 40.0:
        return Estado.EXITOSO

    return Estado.EN_EJECUCION
```

```gdscript
# AccionHuir.gd
extends Accion

@export var velocidad: float = 180.0

func _on_ejecutar() -> Estado:
    var mov: MovimientoComponente = _memoria.obtener("movimiento")
    var objetivo: Node2D          = _memoria.obtener("objetivo")
    var agente: CharacterBody2D   = _memoria.obtener("agente")

    if not mov or not agente:
        return Estado.FALLIDO

    # Si perdimos al objetivo simplemente nos detenemos.
    if not objetivo:
        mov.physics_process(get_physics_process_delta_time(), Vector2.ZERO)
        return Estado.EXITOSO

    # Dirección contraria al objetivo.
    var dir = (agente.global_position - objetivo.global_position).normalized()
    mov.physics_process(get_physics_process_delta_time(), dir)
    return Estado.EN_EJECUCION
```

```gdscript
# CondicionObjetivoVisible.gd
extends Condicion

func _on_ejecutar() -> Estado:
    # Verifica directamente el componente; sin acoplar al nodo Enemigo.
    var vision: VisionComponente = _memoria.obtener("vision")
    if not vision:
        return Estado.FALLIDO
    return Estado.EXITOSO if vision.areas_detectadas.size() > 0 else Estado.FALLIDO
```

---

## Por qué NO usar MonitorVariable aquí

`MonitorVariable` sirve para propiedades simples leídas pasivamente cada frame
(ej: `position.x`, `rotation`). En cambio, `salud_actual` en VidaComponente
ya dispara la señal `cambio_valor_vida` en el momento exacto del cambio.
Conectar la señal es más eficiente y reactivo que leer cada frame.

| Situación                              | Usar                          |
|----------------------------------------|-------------------------------|
| Propiedad pública, sin señal propia    | `MonitorVariable` en inspector|
| Componente que emite señal al cambiar  | Conectar señal en `_ready()`  |
| Valor calculado / flag derivada        | `_on_memoria_variable_cambiada` |

---

## Resumen del flujo completo para la vida

```
[Jugador golpea al Enemigo]
        │
        ▼
VidaComponente.quitar_vida(20)
        │
        ├─► salud_actual = 80.0
        └─► emit cambio_valor_vida(80.0)
                    │
                    ▼
        Enemigo._on_vida_cambiada(80.0)
                    │
                    └─► memoria.establecer("vida", 80.0)
                                    │
                                    ▼
                    MemoriaBT emite variable_cambiada("vida", 100, 80)
                                    │
                                    ▼
                    Enemigo._on_memoria_variable_cambiada("vida", ...)
                                    │
                                    ├─► memoria.establecer("vida_baja", false)
                                    └─► (vida_cero ya es false, no cambia)
                                                    │
                                                    ▼
                                    [Próximo tick del árbol]
                                    CondicionMemoria("vida_baja") → FALLIDO
                                    CondicionMemoria("jugador_detectado") → EXITOSO
                                    AccionPerseguir → EN_EJECUCION  ✓
```

---

## Resumen del flujo completo para la visión

```
[Jugador entra en el área de VisionComponente]
        │
        ▼
VisionComponente._on_area_entered(area)
        │
        ├─► registrar_area_detectada(area)
        └─► emit objetivo_detectado(area)
                    │
                    ▼
        Enemigo._on_objetivo_detectado(area)
                    │
                    ├─► memoria.establecer("objetivo", area.owner)  ← Jugador
                    └─► memoria.establecer("jugador_detectado", true)
                                    │
                                    ▼
                    [Próximo tick del árbol]
                    CondicionMemoria("jugador_detectado") → EXITOSO
                    AccionPerseguir se activa  ✓
```

