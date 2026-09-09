# Evidencia 4.80.0

Codex / BOG085CD119BDQN / 2026-09-08 20:50 America/Bogota.

- `focal_result.txt`: 10 OK, 0 fallos, motor instalado, Core Console 2023,
  18.2 segundos; sin emulacion COM en esta prueba de funciones puras/carga.
- `verify_result.txt`: 71 OK, 0 fallos; suite prioridades4740, incluye
  adaptador COM. No valida operaciones ActiveX reales.
- `geometry.lsp`: caso rotado, hueco, guia/toperol, Z100 contra Z0,
  insercion posterior, longitud de prefab. **No ejecutado con resultado**:
  Civil 3D 2023 PID 9712 no produjo archivo y se cerro solo ese PID a 90.5s.
  No considerar sus asserts como evidencia aprobada.
- El primer focal escribio en el laboratorio persistido por AutoCAD
  `claude_20260908_suite`; se recupero el resultado sin repetir la prueba.
  SCR ahora fija laboratorio explicitamente. Este ajuste del harness no
  cambia el motor validado; no se repitio el arranque por tiempo.
- SHA256 del LSP probado e instalado:
  `637274EEBA3A7D5AE0F128631FF11B1420119A33A989AEEAABA373C87019C76F`.

Pendiente: booleanos/resultado visual real, prefabs curvos y cortes parciales
que no cruzan la referencia longitudinal. No se modificaron originales.
Para probar manualmente: reiniciar Civil 3D, crear anden corto con guia y
toperol; insertar contenedor sobre un costado y comprobar acabado vacio y
prefab dividido. No reparar el maestro automaticamente.
