# Roadmap del proyecto (Factory/Castle/Shop)

Este roadmap propone una ruta de desarrollo incremental para convertir el prototipo actual en un juego más sólido, con bucle de producción claro, progresión y mejor UX.

## Objetivos de producto

1. **Unificar la simulación**: evitar sistemas duplicados de producción y definir una sola fuente de verdad.
2. **Profundizar la estrategia**: que la logística visual tenga impacto real en rendimiento.
3. **Mejorar la claridad para jugador**: feedback inmediato de cuellos de botella, costes y ganancias.
4. **Asegurar estabilidad**: cubrir economía y progresión con pruebas repetibles.

---

## Fase 1 (Semana 1): estabilización de base

### 1.1 Unificación de lógica de fábrica
- Elegir un único modelo de producción (recomendado: celdas/estaciones) y deprecación del flujo legacy por roles.
- Documentar reglas de inputs/outputs por estación (slime→pulp→smoothie, agua→sal→unguento, etc.).
- Eliminar estados huérfanos y ramas no usadas para reducir regresiones.

### 1.2 Señales y refresco UI
- Definir cuándo emitir `state_changed` y cuándo no, para no renderizar de más.
- Separar “estado simulación” de “estado visual” (workers/animación) para facilitar depuración.

### 1.3 Persistencia mínima robusta
- Revisar save/load para cubrir todos los campos críticos de progresión.
- Añadir versión de save (`save_version`) para futuras migraciones.

**Entregables fase 1**
- Simulación estable y consistente.
- Saves compatibles y fáciles de migrar.
- Menos refrescos innecesarios y menor riesgo de desincronización visual.

---

## Fase 2 (Semana 2): logística con impacto real

### 2.1 Inventarios por celda (buffers)
- Añadir buffers de entrada/salida por estación.
- Consumir y producir desde buffers, no directamente desde stock global.

### 2.2 Transporte real de workers
- Hacer que cada viaje traslade unidades reales.
- Introducir tiempos de carga/descarga y límites por viaje.

### 2.3 Cuellos de botella visibles
- Indicadores visuales por celda:
  - “Sin input”
  - “Output bloqueado”
  - “Sin workers”
- Métricas de throughput por estación.

**Entregables fase 2**
- El layout sí afecta la eficiencia real.
- El jugador puede detectar por qué una línea no produce.

---

## Fase 3 (Semana 3): progresión y metajuego

### 3.1 Economía y reputación
- Revisar curvas de coste/beneficio (hiring, upgrades, precios).
- Añadir objetivos por estrella o hitos de reputación.

### 3.2 Contenido desbloqueable
- Nuevas estaciones o recetas avanzadas por milestones.
- Pedidos especiales (alto valor, ventana corta).

### 3.3 Eventos de tienda
- Horas punta con más clientes.
- Modificadores temporales (ofertas, penalizaciones por espera).

**Entregables fase 3**
- Loop motivador de medio plazo.
- Decisiones con trade-off económico claro.

---

## Fase 4 (Semana 4): UX de gestión y calidad

### 4.1 Herramientas de gestión
- Presets de layout (guardar/cargar diseños de fábrica).
- Acciones masivas de asignación/desasignación de workers.

### 4.2 Telemetría interna de balance
- Panel debug opcional con:
  - producción/min
  - ventas/min
  - pérdida de clientes
  - tiempo medio de espera

### 4.3 QA automático
- Añadir pruebas de lógica en `GameState` para:
  - conversiones de recursos,
  - costes de contratación/upgrades,
  - fulfillment de pedidos,
  - save/load.

**Entregables fase 4**
- Gestión más cómoda.
- Menos bugs al iterar balance y features.

---

## Backlog priorizado (Top 10)

1. Unificar producción (retirar duplicidad legacy vs celdas).
2. Añadir `save_version` y migración básica de datos.
3. Buffers por celda y consumo/producción local.
4. Transporte real de workers con carga/descarga.
5. Estados visuales de bloqueo por estación.
6. Dashboard simple de métricas de fábrica.
7. Ajuste de curva de costes de contratación y upgrades.
8. Pedidos especiales con temporizador.
9. Presets de layout de fábrica.
10. Suite inicial de pruebas automáticas de economía/simulación.

---

## Criterios de éxito (KPIs)

- **Estabilidad**: 0 regresiones críticas en save/load y en producción básica.
- **Legibilidad**: jugador identifica el cuello de botella principal en < 10 segundos.
- **Rendimiento**: refresco UI estable sin recreación innecesaria de nodos.
- **Engagement**: más decisiones significativas por minuto (layout, staffing, upgrades).

---

## Riesgos y mitigación

- **Riesgo**: mezclar lógica visual y lógica de negocio.
  - **Mitigación**: capa de simulación pura + capa de render separada.
- **Riesgo**: romper balance al introducir buffers.
  - **Mitigación**: pruebas de regresión y tuning con telemetría.
- **Riesgo**: sobrecargar al jugador con complejidad.
  - **Mitigación**: desbloqueo progresivo y tooltips contextuales.
