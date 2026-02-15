# Slime Kingdom MVP (Godot 4.x)

## Estructura de archivos
- `project.godot`
- `Scenes/Main.tscn`
- `Scenes/Castle.tscn`
- `Scenes/Factory.tscn`
- `Scenes/Shop.tscn`
- `Scenes/Customer.tscn`
- `Scripts/GameState.gd` (autoload global único)
- `Scripts/Main.gd`
- `Scripts/Castle.gd`
- `Scripts/Factory.gd`
- `Scripts/Shop.gd`
- `Scripts/Customer.gd`

## Cómo ejecutar
1. Abrir Godot 4.x.
2. **Importar** la carpeta del proyecto (`/workspace/Prueba`).
3. Verificar en `Project > Project Settings > Autoload` que existe:
   - `GameState` -> `res://Scripts/GameState.gd`
4. Ejecutar con **F5** (escena principal `res://Scenes/Main.tscn`).

## Flujo del MVP
- Desde `Castle` puedes contratar workers y navegar a `Factory` o `Shop`.
- En `Factory` colocas estaciones en grilla 3x3 y usas producción manual.
- La automatización corre con tick central de 1s en `GameState`.
- En `Shop` se ven clientes moviéndose entre Spawn/Queue/Counter/Exit y pedidos.
