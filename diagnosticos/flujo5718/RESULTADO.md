# Resultado v5.7.18 — salida de cañuela y eje de andén curvo

Fecha: 2026-09-22. Agente: Codex. Equipo: BOG085CD119BDQN.

## Causa y corrección

- La cañuela estaba rodeada por un `while`: terminar una polilínea registraba
  esa cañuela y abría inmediatamente otra. Además reutilizaba el capturador de
  contornos que interpreta el primer Esc como recuperación. Ahora el comando
  abre un solo PLINE: Enter termina y registra esa única cañuela; Esc cancela,
  elimina cualquier trazo parcial y devuelve el control al menú.
- En andenes curvos el modo segmentado se evaluaba antes del eje explícito y
  por eso podía producir varias orientaciones. El eje guardado
  `URB_ANDEN_AXIS` ahora tiene prioridad y desactiva esa segmentación.
- Los dos puntos que marca el usuario ahora representan directamente el eje
  longitudinal del andén. Las bandas se construyen perpendiculares a él. Enter
  conserva el cálculo automático anterior.

## Verificación

- Core Console 2023: 8 PASS / 0 FAIL, 10.095 s. Comprueba una sola llamada de
  dibujo/registro, prioridad del eje marcado y conversión directa de los dos
  puntos.
- Civil 3D 2023 nativo: 4 PASS / 0 FAIL, 40.258 s. Se creó un contorno curvo
  real con arcos, se generaron 215 hatches de acabado y todos quedaron sobre el
  eje marcado o su ortogonal; desviación máxima 0 rad, sin abanico progresivo.
- Los primeros dos intentos del arnés nativo se descartaron por criterios de
  inspección incompletos (filtro de capas y luego tratamiento de las dos
  familias ortogonales como si fueran una sola). No indicaron un fallo del
  producto; el arnés final inspecciona todos los hatches del acabado.

## Alcance pendiente manual

- El gesto físico de pulsar Esc no se puede inyectar de forma fiable en el
  arnés por script; la ruta de código sí se aisló y la orquestación de una sola
  cañuela quedó cubierta. Confirmar una vez en Civil 3D 2026 tras reiniciar.
- Un andén viejo que ya quedó en abanico conserva datos generados con la versión
  anterior; debe recrearse para adoptar el eje longitudinal nuevo.
- No se modificó ni guardó el archivo maestro ni archivos de presupuesto.
