# Decoradores Avanzados — Árbol de Comportamiento Godot 4.5
# Enfriamiento · Retardo · Temporizador · Probabilidad · Guardia

---

## Resumen rápido

| Decorador      | Pregunta que responde                                  | Retorna durante espera |
|----------------|--------------------------------------------------------|------------------------|
| `Enfriamiento` | ¿Puedo ejecutar esto de nuevo?                         | FALLIDO                |
| `Retardo`      | ¿Ya pasó el tiempo de preparación?                     | EN_EJECUCION           |
| `Temporizador` | ¿El hijo lleva demasiado tiempo sin terminar?          | EN_EJECUCION / FALLIDO |
| `Probabilidad` | ¿El dado lo permite?                                   | FALLIDO (directo)      |
| `Guardia`      | ¿La memoria autoriza el paso?                          | FALLIDO (directo)      |

---

## Enfriamiento — limitar la frecuencia de una acción

Tras ejecutarse, bloquea al hijo durante N segundos.
Durante ese tiempo retorna FALLIDO sin ni siquiera llamar al hijo.

### Ejemplo: el enemigo solo puede atacar cada 2 segundos

```
Secuencia  [Atacar]
  ├─ CondicionMemoria  "jugador_muy_cerca"
  └─ Enfriamiento
      nombre_nodo         →  "Cooldown_Ataque"
      tiempo_enfriamiento →  2.0
      solo_al_exitoso     →  true    ← solo cuenta el tiempo si el ataque tuvo éxito
      └─ AccionAtacar
```

Con `solo_al_exitoso = true`: si el ataque falla (animación interrumpida, etc.),
el cooldown no se activa y puede intentarlo de nuevo de inmediato.

Con `solo_al_exitoso = false`: el cooldown corre siempre, haya éxito o no.

### Ejemplo: emitir una alerta de voz máximo una vez cada 5 segundos

```
Enfriamiento
  tiempo_enfriamiento  →  5.0
  solo_al_exitoso      →  false
  └─ AccionGritarAlerta
```

---

## Retardo — esperar antes de actuar

Retiene la ejecución N segundos (devolviendo EN_EJECUCION) y después
pasa el control al hijo. El hijo se ejecuta normalmente a partir de entonces.

### Ejemplo: el enemigo duda 0.8s antes de perseguir (tiempo de reacción)

```
Secuencia  [Reaccionar y perseguir]
  ├─ CondicionMemoria  "jugador_detectado"
  └─ Retardo
      nombre_nodo      →  "Retardo_Reaccion"
      tiempo_espera    →  0.8
      reiniciar_al_entrar → true   ← cada vez que entra de nuevo, vuelve a esperar
      └─ AccionPerseguir
```

Con `reiniciar_al_entrar = true`: si pierde al jugador y lo vuelve a ver,
espera los 0.8s otra vez. Simula que el enemigo se sobresalta cada vez.

Con `reiniciar_al_entrar = false`: la primera vez espera, las siguientes entra directo.

### Ejemplo: mostrar un signo de exclamación 1s antes de atacar

```
Secuencia  [Señal + Ataque]
  ├─ AccionMostrarExclamacion     ← activa el sprite, retorna EXITOSO
  └─ Retardo
      tiempo_espera  →  1.0
      └─ AccionAtacar
```

---

## Temporizador — cancelar si tarda demasiado

Permite que el hijo se ejecute, pero si lleva más de N segundos
devolviendo EN_EJECUCION, lo interrumpe y retorna el estado configurado.

### Ejemplo: abandonar la persecución si no alcanza al jugador en 4 segundos

```
Temporizador
  nombre_nodo      →  "Timeout_Persecucion"
  tiempo_limite    →  4.0
  estado_al_agotar →  FALLIDO
  └─ AccionPerseguir
```

Cuando el tiempo se agota, el Temporizador llama a `reiniciar()` en el hijo
y retorna FALLIDO. El Selector padre probará la siguiente rama (patrullar, etc.).

### Ejemplo: tiempo límite para completar una animación de apertura de puerta

```
Temporizador
  tiempo_limite    →  2.5
  estado_al_agotar →  EXITOSO   ← si no termina, lo damos por bueno y seguimos
  └─ AccionAbrirPuerta
```

### Composición Temporizador + Enfriamiento

```
Enfriamiento                          ← no puede intentar habilidad especial tan seguido
  tiempo_enfriamiento  →  8.0
  └─ Temporizador                     ← si tarda más de 3s ejecutándose, cancela
      tiempo_limite    →  3.0
      └─ AccionHabilidadEspecial
```

---

## Probabilidad — comportamiento no determinista

Hace una tirada al azar al entrar al nodo. Si supera el umbral, ejecuta al hijo.
Si no, retorna FALLIDO directamente. La tirada se conserva mientras el hijo
devuelva EN_EJECUCION (no se re-tira cada tick).

### Ejemplo: el enemigo lanza un proyectil solo el 40% de las veces

```
Probabilidad
  nombre_nodo   →  "Prob_Proyectil"
  probabilidad  →  0.4      ← 40% de posibilidad
  semilla       →  -1       ← -1 = aleatoria real
  └─ AccionLanzarProyectil
```

### Ejemplo: variar el punto de patrulla aleatoriamente (70% ir al punto A, 30% al B)

```
Selector  [Elegir patrulla]
  ├─ Probabilidad
  │   probabilidad  →  0.7
  │   └─ AccionPatrullarPuntoA
  └─ AccionPatrullarPuntoB      ← fallback si la probabilidad no pasa
```

### Composición Probabilidad + Enfriamiento + Retardo

```
Enfriamiento                          ← máximo una vez cada 6 segundos
  tiempo_enfriamiento  →  6.0
  └─ Probabilidad                     ← y solo si el dado lo permite (60%)
      probabilidad     →  0.6
      └─ Retardo                      ← con 0.5s de preparación antes de ejecutar
          tiempo_espera  →  0.5
          └─ AccionAtaqueEspecial
```

---

## Guardia — portero de la memoria

Evalúa una variable de la MemoriaBT antes de dejar pasar al hijo.
Más legible que `Secuencia(CondicionMemoria + Subárbol)` cuando
la condición es simple y el subárbol es complejo.

### Ejemplo: solo ejecutar la rama de combate si el enemigo tiene arma

```
Guardia
  nombre_nodo      →  "Guard_TieneArma"
  nombre_variable  →  "tiene_arma"
  tipo_guardia     →  ES_VERDADERO
  └─ Selector  [Combate complejo]
      ├─ Secuencia [Atacar cuerpo a cuerpo]
      │   └─ ...
      └─ Secuencia [Disparar]
          └─ ...
```

Si `tiene_arma` es false en la memoria, toda la rama de combate se salta
sin evaluar ninguno de sus hijos. El Selector padre busca la siguiente opción.

### Ejemplo: solo huir si la vida es menor que 25

```
Guardia
  nombre_variable  →  "vida"
  tipo_guardia     →  MENOR_QUE
  umbral           →  25.0
  └─ AccionHuir
```

Equivalente más explícito a poner una `CondicionMemoria` en una `Secuencia`,
pero con un solo nodo en lugar de dos.

### Ejemplo: proteger toda una fase del jefe con una flag

```
Guardia
  nombre_variable  →  "fase_dos_activa"
  tipo_guardia     →  ES_VERDADERO
  └─ Selector  [Comportamiento Fase 2]
      ├─ AccionInvocarMinions
      ├─ AccionAtaqueLaser
      └─ AccionTeletransportar
```

---

## Combinación de todos en un árbol de enemigo real

```
ArbolComportamiento
└─ Selector  [Raíz]
    │
    ├─ Guardia  "vida_cero"=ES_VERDADERO          ← si vida = 0, morir
    │   └─ AccionMorir
    │
    ├─ Guardia  "vida_baja"=ES_VERDADERO           ← si vida < 30, huir
    │   └─ Temporizador (8s)                       ← pero no huir para siempre
    │       └─ AccionHuir
    │
    ├─ Guardia  "jugador_muy_cerca"=ES_VERDADERO   ← si está muy cerca, atacar
    │   └─ Enfriamiento (2s)                       ← máximo un ataque cada 2s
    │       └─ Retardo (0.4s)                      ← pequeña pausa antes del golpe
    │           └─ Probabilidad (0.8)              ← 80% de éxito en el intento
    │               └─ AccionAtacar
    │
    ├─ Guardia  "jugador_detectado"=ES_VERDADERO   ← si lo ve, perseguir
    │   └─ Retardo (0.6s)                          ← tiempo de reacción
    │       └─ Temporizador (5s)                   ← si no alcanza en 5s, rendirse
    │           └─ AccionPerseguir
    │
    └─ AccionPatrullar                             ← fallback siempre disponible
```

---

## Diferencia entre Guardia y CondicionMemoria en Secuencia

Ambos patrones son equivalentes en resultado, pero tienen intenciones distintas:

```gdscript
# Patrón A — Secuencia + CondicionMemoria
# Intención: "haz X y luego Y"
Secuencia
  CondicionMemoria  "jugador_cerca"
  AccionPerseguir

# Patrón B — Guardia
# Intención: "solo deja pasar si se cumple esta condición"
Guardia  "jugador_cerca"=ES_VERDADERO
  AccionPerseguir
```

Usa **Secuencia** cuando encadenas múltiples pasos.
Usa **Guardia** cuando proteges un subárbol con una sola condición de entrada.

