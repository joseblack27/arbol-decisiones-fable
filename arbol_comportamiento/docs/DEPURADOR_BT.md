# DepuradorBT — Panel visual en juego

Panel que muestra el árbol de comportamiento y la MemoriaBT en tiempo real,
sin tocar la consola. Se actualiza solo cuando el árbol hace un tick.

---

## Qué muestra

```
[F1] mostrar/ocultar

┌────────────────────────────┐   ┌──────────────────────────┐
│ ◆  Árbol de Comportamiento │   │ ◆  MemoriaBT             │
│─────────────────────────── │   │──────────────────────────│
│ ArbolEnemigo  tick #47     │   │ vida        = 72.00      │
│ └─ ✔ Selector_Principal    │   │ vida_baja   = false      │
│    ├─ ✘ Sec_Morir          │   │ vida_cero   = false      │
│    │  └─ ✘ Cond_VidaCero   │   │ jugador_det.= true       │
│    ├─ ✘ Sec_Huir           │   │ objetivo    = Jugador    │
│    │  └─ ✘ Cond_VidaBaja   │   │ en_combate  = true       │
│    ├─ ✔ Sec_Atacar         │   └──────────────────────────┘
│    │  ├─ ✔ Cond_MuyCerca   │
│    │  └─ ✔ AccionAtacar    │   ✔ verde    = EXITOSO
│    └─ ● AccionPerseguir    │   ✘ rojo     = FALLIDO
└────────────────────────────┘   ● amarillo = EN_EJECUCION
                                   gris     = sin ejecutar aún
```

---

## Cómo añadirlo a la escena

```
Enemigo
└─ ArbolComportamiento
    ├─ MemoriaBT
    ├─ Selector ...
    └─ DepuradorBT          ← añadir aquí (hijo directo de ArbolComportamiento
                               o del Enemigo, donde prefieras)
```

En el Inspector del nodo **DepuradorBT**:

```
arbol              →  ruta al ArbolComportamiento (ej: .)
mostrar_memoria    →  true
tecla_toggle       →  F1
posicion_arbol     →  (10, 10)
posicion_memoria   →  (320, 10)
```

---

## Por qué no usar debug_activo en los nodos

Con `debug_activo = true` en varios nodos y el árbol a 10 ticks/seg:

- Son ~50-100 líneas por segundo en la consola.
- El editor renderiza cada línea en el output panel → overhead visible.
- Es imposible leer el flujo en tiempo real con tanto scroll.

Con el DepuradorBT:
- **Cero prints** durante el juego normal.
- El panel se actualiza en el mismo tick del árbol.
- Puedes ver exactamente qué nodo está activo y qué hay en la memoria
  de un solo vistazo, sin detener el juego.

**Recomendación:** deja `debug_activo = false` en todos los nodos del árbol
cuando el DepuradorBT esté activo. Solo activa `debug_activo` en un nodo
puntual si necesitas ver sus callbacks `_on_entrar` / `_on_salir` en detalle.

---

## Cómo se comporta el panel de MemoriaBT

Los valores se colorean automáticamente según tipo:

| Tipo       | Color    | Ejemplo               |
|------------|----------|-----------------------|
| `bool` true  | Verde  | `en_combate = true`   |
| `bool` false | Rojo   | `vida_baja  = false`  |
| `float/int`  | Cian   | `vida       = 72.00`  |
| `String`     | Naranja| `modo       = "huir"` |
| `Vector2`    | Violeta| `dir        = (1, 0)` |
| `Node`       | Blanco | `objetivo   = Jugador`|
| `null`       | Gris   | `objetivo   = null`   |

El panel de memoria se actualiza también cuando cualquier variable cambia
(via la señal `variable_cambiada` de MemoriaBT), no solo al tick del árbol.
Así si el Enemigo escribe en la memoria fuera del tick (señal de daño, etc.),
el panel lo refleja en el momento.

---

## Exportar solo en debug builds

Si quieres que el DepuradorBT no aparezca en builds de producción:

```gdscript
# DepuradorBT.gd — añadir en _ready()
func _ready() -> void:
    if not OS.is_debug_build():
        queue_free()
        return
    # ... resto del código
```

O simplemente no incluyas el nodo en la escena de producción.

