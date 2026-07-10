# Guía Práctica — Árbol de Comportamiento Godot 4.5
# Caso de uso: Enemigo con vida, patrulla, persecución y huida

En esta guía se construye paso a paso un enemigo completo que:
- Patrulla cuando no ve al jugador
- Persigue al jugador si está cerca
- Ataca si está muy cerca
- Huye si su vida baja de 30
- Muere si la vida llega a 0

Se muestra un ejemplo práctico de CADA elemento del sistema.

---

## 1. El nodo Enemigo — propiedades que la memoria monitorizará

```gdscript
# Enemigo.gd
extends CharacterBody2D

var vida: float = 100.0
var velocidad: float = 80.0
var jugador: Node2D = null

func recibir_daño(cantidad: float) -> void:
    vida = maxf(vida - cantidad, 0.0)
```

La propiedad `vida` vive en el nodo Enemigo.
El árbol no la leerá directamente; la MemoriaBT la mirará por nosotros.

---

## 2. Estructura de la escena

```
Enemigo  (CharacterBody2D — Enemigo.gd)
└─ ArbolComportamiento
    ├─ MemoriaBT
    └─ Selector  [Raíz]
        ├─ Secuencia  [Morir si vida = 0]
        │   ├─ CondicionMemoria        "vida_cero"
        │   └─ AccionMorir
        │
        ├─ Secuencia  [Huir si vida baja]
        │   ├─ CondicionMemoria        "vida_baja"
        │   └─ AccionHuir
        │
        ├─ Secuencia  [Atacar si está muy cerca]
        │   ├─ CondicionMemoria        "jugador_muy_cerca"
        │   └─ AccionAtacar
        │
        ├─ Secuencia  [Perseguir si está cerca]
        │   ├─ CondicionMemoria        "jugador_cerca"
        │   └─ AccionPerseguir
        │
        └─ AccionPatrullar             [fallback siempre activo]
```

---

## 3. MemoriaBT — configurar desde el Inspector

### 3a. Variables iniciales
En el Inspector del nodo **MemoriaBT**, en la sección **Variables Iniciales**,
agrega estas entradas al Dictionary:

```
"jugador"            → null      (se asignará desde Enemigo.gd en _ready)
"jugador_cerca"      → false
"jugador_muy_cerca"  → false
"vida_baja"          → false
"vida_cero"          → false
```

### 3b. Monitorizar la vida automáticamente con MonitorVariable

En el Inspector de **MemoriaBT**, sección **Monitores → monitores_exportados**:
Haz clic en el array y añade un nuevo elemento de tipo `MonitorVariable`.

Configura ese MonitorVariable así:
```
nombre_variable  →  "vida"
ruta_nodo        →  ..          (el nodo Enemigo, padre de ArbolComportamiento)
propiedad        →  "vida"
```

Ahora cada frame la MemoriaBT leerá `Enemigo.vida` y lo guardará
bajo la clave `"vida"`. Todos los nodos del árbol pueden llamar:

```gdscript
var vida_actual = _memoria.obtener("vida")   # → 100.0, 73.5, 0.0...
```

### 3c. Asignar el jugador y otras flags desde código

```gdscript
# Enemigo.gd
func _ready() -> void:
    var memoria = $ArbolComportamiento/MemoriaBT
    memoria.establecer("jugador", get_tree().get_first_node_in_group("jugador"))

    # Cada vez que la vida cambia, actualizamos las flags derivadas
    memoria.variable_cambiada.connect(_on_memoria_variable_cambiada)

func _on_memoria_variable_cambiada(nombre: String, _anterior, _nuevo) -> void:
    if nombre == "vida":
        var memoria = $ArbolComportamiento/MemoriaBT
        var vida_actual: float = memoria.obtener("vida", 100.0)
        memoria.establecer("vida_baja",  vida_actual > 0.0 and vida_actual < 30.0)
        memoria.establecer("vida_cero",  vida_actual <= 0.0)
```

Con esto, en cuanto el monitoreo detecta un cambio en `vida`,
las flags `vida_baja` y `vida_cero` se actualizan solas.

---

## 4. ArbolComportamiento — configurar desde el Inspector

Selecciona el nodo **ArbolComportamiento**:

```
nombre_nodo          →  "ArbolEnemigo"
activo               →  true
agente               →  ..          (ruta al nodo Enemigo)
ruta_memoria         →  MemoriaBT   (o dejar vacío; se detecta automáticamente)
debug_activo         →  true        (actívalo para ver los ticks en consola)
debug_imprimir_memoria → false      (ponlo true solo cuando depures la memoria)
```

El `agente` queda disponible en la memoria como `_memoria.obtener("agente")`.

---

## 5. Composites

### Selector — OR lógico (nodo raíz del árbol)

```
Selector  [Raíz]
  nombre_nodo  →  "Selector_Principal"
  debug_activo →  false
```

Prueba cada rama de arriba hacia abajo. La primera que retorne EXITOSO
detiene la evaluación. En nuestro caso: morir > huir > atacar > perseguir > patrullar.

**Regla:** si un hijo retorna FALLIDO, prueba el siguiente.
Si uno retorna EXITOSO, el Selector retorna EXITOSO y para.

---

### Secuencia — AND lógico (rama "Atacar")

```
Secuencia  [Atacar si muy cerca]
  nombre_nodo  →  "Sec_Atacar"
  debug_activo →  true
  hijos:
    CondicionMemoria  "jugador_muy_cerca"
    AccionAtacar
```

Solo ejecuta AccionAtacar si la condición pasa primero.
Si CondicionMemoria retorna FALLIDO, la Secuencia entera retorna FALLIDO
y el Selector prueba la siguiente rama.

**Regla:** si un hijo retorna FALLIDO, la secuencia falla entera y para.
Si todos retornan EXITOSO, la Secuencia retorna EXITOSO.

---

### Paralelo — ejecución simultánea

Útil si quieres que el enemigo detecte al jugador Y actualice una animación
al mismo tiempo, sin que una bloquee a la otra:

```
Paralelo  [Detectar + Animar]
  nombre_nodo      →  "Par_DetectarYAnimar"
  politica_exito   →  TODOS
  politica_fallo   →  UNO
  hijos:
    AccionDetectarJugador    (actualiza "jugador_cerca" en la memoria)
    AccionActualizarAnimacion
```

Con `politica_exito = TODOS`: retorna EXITOSO cuando ambos hijos terminan.
Con `politica_fallo = UNO`: si cualquiera falla, el Paralelo falla.

---

## 6. CondicionMemoria — listo para usar sin código

Configura cada **CondicionMemoria** en el Inspector:

### "¿Jugador está cerca?" (distancia calculada en una Acción aparte)
```
nombre_nodo       →  "Cond_JugadorCerca"
debug_activo      →  true
nombre_variable   →  "jugador_cerca"
tipo_comparacion  →  ES_VERDADERO
```

### "¿Jugador está muy cerca?"
```
nombre_variable   →  "jugador_muy_cerca"
tipo_comparacion  →  ES_VERDADERO
```

### "¿Vida baja (< 30)?"
```
nombre_variable   →  "vida_baja"
tipo_comparacion  →  ES_VERDADERO
```

### "¿Vida exactamente a 0?"
```
nombre_variable   →  "vida"
tipo_comparacion  →  MENOR_IGUAL
valor_numerico    →  0.0
```

### "¿Vida mayor que 50?" (ejemplo numérico directo)
```
nombre_variable   →  "vida"
tipo_comparacion  →  MAYOR_QUE
valor_numerico    →  50.0
```

---

## 7. AccionEstablecerMemoria — listo para usar sin código

Colócalo como hijo en cualquier punto del árbol para escribir un flag.

### Ejemplo: marcar que el enemigo entró en combate
```
AccionEstablecerMemoria
  nombre_nodo      →  "Accion_MarcarCombate"
  nombre_variable  →  "en_combate"
  tipo_valor       →  BOOLEANO
  valor_booleano   →  true
```

### Ejemplo: resetear un contador
```
AccionEstablecerMemoria
  nombre_variable  →  "intentos_ataque"
  tipo_valor       →  NUMERO
  valor_numerico   →  0.0
```

---

## 8. Decoradores

### Inversor — negar el resultado de una condición

Si necesitas "patrullar cuando NO haya jugador cerca":

```
Secuencia  [Patrullar sin jugador]
  ├─ Inversor
  │   └─ CondicionMemoria  "jugador_cerca"  (ES_VERDADERO)
  └─ AccionPatrullar
```

El Inversor convierte el EXITOSO de la condición en FALLIDO,
y el FALLIDO en EXITOSO. La secuencia solo avanza si el jugador NO está cerca.

### Repetidor — repetir N veces o infinitamente

```
Repetidor  [Patrullar en bucle]
  nombre_nodo       →  "Rep_Patrulla"
  repeticiones      →  -1       (-1 = infinito)
  repetir_si_falla  →  false
  └─ AccionPatrullar
```

Con `repeticiones = 3` el hijo se ejecuta exactamente 3 veces
antes de que el Repetidor retorne EXITOSO.

### LimitadorEjecuciones — ejecutar solo una vez por ciclo

Útil para avisos, efectos de entrada o acciones que no deben repetirse:

```
LimitadorEjecuciones  [Solo 1 grito de alerta]
  nombre_nodo      →  "Limit_Alerta"
  max_ejecuciones  →  1
  └─ AccionGritarAlerta
```

Después de ejecutarse 1 vez retorna FALLIDO para todo el resto del ciclo.
Se resetea al llamar `reiniciar()` en el árbol.

---

## 9. Acciones personalizadas con _on_entrar / _on_salir

```gdscript
# AccionPerseguir.gd
extends Accion

@export var velocidad: float = 120.0

func _on_entrar() -> void:
    super._on_entrar()
    var agente = _memoria.obtener("agente") as CharacterBody2D
    if agente:
        agente.get_node("AnimationPlayer").play("correr")

func _on_ejecutar() -> Estado:
    var agente  = _memoria.obtener("agente")  as CharacterBody2D
    var jugador = _memoria.obtener("jugador") as Node2D
    if not agente or not jugador:
        return Estado.FALLIDO

    # Actualiza la flag de distancia para que las condiciones reaccionen
    var dist = agente.global_position.distance_to(jugador.global_position)
    _memoria.establecer("jugador_cerca",      dist < 200.0)
    _memoria.establecer("jugador_muy_cerca",  dist < 60.0)

    if dist < 60.0:
        return Estado.EXITOSO   # Ya está lo suficientemente cerca para atacar

    var dir = (jugador.global_position - agente.global_position).normalized()
    agente.velocity = dir * velocidad
    agente.move_and_slide()
    return Estado.EN_EJECUCION  # Sigue persiguiendo el próximo tick

func _on_salir(estado: Estado) -> void:
    super._on_salir(estado)
    var agente = _memoria.obtener("agente") as CharacterBody2D
    if agente:
        agente.get_node("AnimationPlayer").play("idle")
```

---

## 10. Condición personalizada con lectura directa de la memoria

```gdscript
# CondicionTieneObjetivo.gd
extends Condicion

func _on_ejecutar() -> Estado:
    var jugador = _memoria.obtener("jugador")
    # NO_ES_NULO: retorna EXITOSO solo si el jugador está asignado en memoria
    return Estado.EXITOSO if jugador != null else Estado.FALLIDO
```

---

## 11. Coexistencia con la Máquina de Estados

El árbol se activa/desactiva por estado. La memoria se conserva entre estados
salvo que llames a `limpiar()`.

```gdscript
# EstadoCombate.gd  (tu clase de estado de la máquina)
var _arbol: ArbolComportamiento

func entrar(arbol: ArbolComportamiento) -> void:
    _arbol = arbol
    _arbol.escribir_en_memoria("modo", "combate")
    _arbol.reiniciar()
    _arbol.establecer_activo(true)

func salir() -> void:
    _arbol.establecer_activo(false)
    _arbol.reiniciar()
    _arbol.escribir_en_memoria("en_combate", false)

# La máquina de estados puede leer el resultado del árbol así:
func _process(_delta: float) -> void:
    var estado = _arbol.leer_de_memoria("vida")
    if estado != null and float(estado) <= 0.0:
        maquina.cambiar_a("Muerto")
```

---

## 12. Debug en consola

Activa `debug_activo` en el Inspector de los nodos que quieras trazar.
Para inspeccionar la memoria en cualquier momento desde código:

```gdscript
$ArbolComportamiento/MemoriaBT.imprimir_estado()
```

Salida esperada al perseguir al jugador con vida baja:
```
[ArbolBT] ══ Tick: ArbolEnemigo ══
[BT →] Entrando: Selector_Principal
[BT →] Entrando: Sec_Morir
[BT ?] CondicionMemoria vida_cero: vida=28.0 → FALLIDO
[BT ←] Saliendo: Sec_Morir → FALLIDO
[BT →] Entrando: Sec_Huir
[BT ?] CondicionMemoria vida_baja: vida_baja=true → EXITOSO
[BT →] Entrando: AccionHuir
[BT ←] Saliendo: Sec_Huir → EN_EJECUCION
[ArbolBT] ══ Resultado: EN_EJECUCION ══
```

