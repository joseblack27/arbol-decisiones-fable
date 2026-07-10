# Proyecto: Árbol de Comportamiento para IA de Enemigos

## Contexto Actual
- Sistema de árbol de comportamiento (BT) implementado en Godot 4.5
- Objetivo: Controlar la IA de enemigos con diferentes comportamientos (supervivencia, combate, etc.)

## Problema Identificado
El flujo de combate no se ejecuta correctamente porque:

1. **`AccActuDistanciaObjetivo.gd` retorna `FALLO` siempre**
   - Esta acción está diseñada para actualizar la distancia del objetivo en la pizarra
   - Debería retornar `ÉXITO` después de actualizar la distancia
   - Actualmente bloquea el flujo del árbol

2. **`CondEnemigoCerca.gd` no existe**
   - Se usa en `rama_monitor_distancia_objetivo` pero el archivo no está creado
   - Necesita validar si hay un enemigo cercano (objetivo_cercano != null)

## Estructura del Árbol
```
Selector (raíz)
├── rama_monitor_distancia_objetivo (Secuencia)
│   ├── CondEnemigoCerca
│   └── AccActuDistanciaObjetivo ← Retorna FALLO (PROBLEMA)
├── rama_supervivencia (Secuencia)
│   ├── CondVidaBaja (0.25)
│   ├── AccEscribirConsola
│   └── AccCambiarEstado("DeambularState")
└── rama_combate (Secuencia)
    ├── CondEnemigoCerca
    └── Selector
        ├── AccEscribirConsola
        ├── rama_validar_ataque_distancia
        ├── rama_validar_ataque_melee
        └── AccCambiarEstado("PersigueState")
```

## Soluciones Aplicadas
1. ✓ Cambiar `AccActuDistanciaObjetivo` para retornar `ÉXITO`
2. ✓ Crear `CondEnemigoCerca.gd`

## Próximos Pasos
- Verificar que las condiciones de rango (`CondEnRango`) estén funcionando correctamente
- Probar el flujo completo del árbol