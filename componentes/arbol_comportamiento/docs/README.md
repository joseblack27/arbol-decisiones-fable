# Árbol de Comportamiento para Godot 4.5
# Sistema modular en español — basado en nodos de escena

## Estructura de archivos

```
arbol_comportamiento/
│
├── nucleo/
│   ├── NodoBT.gd            ← Base abstracta de TODOS los nodos (enum Estado aquí)
│   ├── NodoComposite.gd     ← Base abstracta para composites
│   ├── NodoDecorador.gd     ← Base abstracta para decoradores
│   └── NodoHoja.gd          ← Base abstracta para hojas
│
├── composites/
│   ├── Secuencia.gd         ← AND lógico: todos deben pasar
│   ├── Selector.gd          ← OR  lógico: basta con que uno pase
│   └── Paralelo.gd          ← Ejecuta todos a la vez; política configurable
│
├── decoradores/
│   ├── Inversor.gd          ← Invierte EXITOSO ↔ FALLIDO
│   ├── Repetidor.gd         ← Repite N veces o infinitamente
│   └── LimitadorEjecuciones.gd  ← Permite ejecutar el hijo solo N veces
│
├── hojas/
│   ├── Condicion.gd         ← Base para condiciones (extiende para crear las tuyas)
│   └── Accion.gd            ← Base para acciones   (extiende para crear las tuyas)
│
├── utilidades/
│   ├── CondicionMemoria.gd  ← Condición lista: compara una variable de la MemoriaBT
│   └── AccionEstablecerMemoria.gd  ← Acción lista: escribe en la MemoriaBT
│
├── MonitorVariable.gd       ← Resource para monitorizar propiedades de nodos
├── MemoriaBT.gd             ← Pizarrón / Blackboard compartido
└── ArbolComportamiento.gd   ← Raíz del árbol y controlador de ticks
```

---

## Ejemplo de escena mínima

```
Enemigo (CharacterBody2D)
└─ ArbolComportamiento
	├─ MemoriaBT
	└─ Selector                      ← Raíz del árbol
		├─ Secuencia  [Atacar]
		│   ├─ CondicionMemoria      (jugador_cerca = ES_VERDADERO)
		│   └─ Accion_Atacar         (extends Accion)
		└─ Accion_Patrullar          (extends Accion)
```

---

## Estados posibles (NodoBT.Estado)

| Estado         | Significado                                     |
|----------------|-------------------------------------------------|
| `EXITOSO`      | El nodo completó su tarea con éxito.            |
| `FALLIDO`      | El nodo no pudo completar su tarea.             |
| `EN_EJECUCION` | El nodo sigue procesando (múltiples ticks).     |

---

## Crear una Condición propia

```gdscript
# CondicionJugadorCerca.gd
extends Condicion

@export var distancia_maxima: float = 10.0

func _on_ejecutar() -> Estado:
	var agente = _memoria.obtener("agente")
	var jugador = _memoria.obtener("jugador")
	if not agente or not jugador:
		return Estado.FALLIDO
	var dist = agente.global_position.distance_to(jugador.global_position)
	return Estado.EXITOSO if dist <= distancia_maxima else Estado.FALLIDO
```

---

## Crear una Acción propia

```gdscript
# AccionPerseguir.gd
extends Accion

@export var velocidad: float = 100.0

func _on_entrar() -> void:
	super._on_entrar()
	# Iniciar animación, etc.

func _on_ejecutar() -> Estado:
	var agente: CharacterBody2D = _memoria.obtener("agente")
	var jugador: Node2D         = _memoria.obtener("jugador")
	if not agente or not jugador:
		return Estado.FALLIDO
	var dir = (jugador.global_position - agente.global_position).normalized()
	agente.velocity = dir * velocidad
	agente.move_and_slide()
	return Estado.EN_EJECUCION  # Sigue corriendo cada tick

func _on_salir(estado: Estado) -> void:
	super._on_salir(estado)
	# Detener animación, etc.
```

---

## MemoriaBT — Monitorizar propiedades externas

Para que el árbol reaccione a propiedades de otros nodos automáticamente:

1. Selecciona el nodo **MemoriaBT** en el Inspector.
2. En **Monitores → monitores_exportados**, añade un nuevo `MonitorVariable`.
3. Configura:
   - `nombre_variable`: clave con la que se guardará en la memoria (ej: `"vida"`)
   - `ruta_nodo`: ruta al nodo que tiene la propiedad (ej: `../Enemigo`)
   - `propiedad`: nombre exacto de la propiedad (ej: `"health"`)

Desde código también puedes hacerlo en runtime:
```gdscript
$ArbolComportamiento/MemoriaBT.monitorizar("vida", $Enemigo, "health")
```

---

## Coexistencia con Máquina de Estados

```gdscript
# Dentro del estado de la máquina de estados:

func entrar():
	$ArbolComportamiento.escribir_en_memoria("modo", "combate")
	$ArbolComportamiento.reiniciar()
	$ArbolComportamiento.establecer_activo(true)

func salir():
	$ArbolComportamiento.establecer_activo(false)
	$ArbolComportamiento.reiniciar()
```

---

## Debug

Cada nodo tiene `debug_activo: bool` en el Inspector.
El `ArbolComportamiento` tiene además `debug_imprimir_memoria`.

Salida en consola (con colores en el output de Godot):
```
[ArbolBT] ══ Tick: ArbolEnemigo ══
[BT →] Entrando: Selector_Principal
[BT →] Entrando: Secuencia_Atacar
[BT →] Entrando: CondicionJugadorCerca
[BT ←] Saliendo: CondicionJugadorCerca → EXITOSO
[BT →] Entrando: AccionPerseguir
[BT ←] Saliendo: Secuencia_Atacar → EN_EJECUCION
[ArbolBT] ══ Resultado: EN_EJECUCION ══
```

---

## Orden de carga recomendado en project.godot

No se necesita autoload. Godot registrará las `class_name` automáticamente
al añadir los archivos .gd al proyecto. Asegúrate de que todos los archivos
del sistema estén dentro de la carpeta del proyecto.
