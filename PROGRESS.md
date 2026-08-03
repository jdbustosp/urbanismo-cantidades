# Progress — urbanismo_cantidades.lsp

Bitácora de trabajo con Claude Code sobre este repositorio. Úsala para retomar el hilo en otra máquina o en una sesión nueva.

## Estado del repo

- Repo git inicializado el 2026-08-02 sobre la carpeta `BLOQUES PPTOS` (donde ya vivía el archivo de trabajo). No se movió nada de sitio — AutoCAD/Civil 3D lo sigue cargando desde la misma ruta de siempre.
- Remoto: https://github.com/jdbustosp/urbanismo-cantidades
- `.gitignore` excluye `backups/` y los `urbanismo_cantidades_backup_*.lsp` sueltos — desde ahora el historial de versiones lo lleva git (`git log`), no copias manuales del archivo completo.
- Flujo de trabajo: editar → `git add urbanismo_cantidades.lsp` → `git commit` → `git push`. Ver [`TESTING_CIVIL3D.md`](TESTING_CIVIL3D.md) para cómo se verifica cada cambio antes de subirlo.

## Qué es este archivo

AutoLISP/Visual LISP para AutoCAD + Civil 3D. Cuantifica obras de urbanismo (andenes, prefabricados, zonas verdes, vías con movimiento de tierras, redes de servicios) y exporta a Excel vía ActiveX. ~14,200 líneas, namespaces `urb:` (núcleo) y `mp:` (módulo "Maipore Redes"). Comandos públicos: `URBANISMO` y `EDITAR`.

## Historial de cambios (más reciente primero)

### 2026-08-02 — Movimiento de tierras de redes (commit `f144375`)

Contexto: el usuario ya tiene la superficie de terreno (`SUP_TN`) creada en Civil 3D y quería saber la mejor forma de sacar el movimiento de tierras de las tuberías, además de revisar el ancho de excavación (tabla de Excel) y la cimentación (imagen "Figura 4 / Figura 4.1").

- **Ancho de excavación**: `mp:default-trench-width` ahora usa una tabla literal copiada de la hoja `Anchos Exc. PVC (Ent)` del presupuesto (`250717_URB. El Chanco...xlsm`) — 22 diámetros NOVAFORT/NOVALOC × 10 rangos de profundidad — en vez de la fórmula genérica `max(0.60, diámetro+0.40)`. Solo aplica a alcantarillado (`TRAMO_ARESIDUAL`/`TRAMO_ALLUVIAS`, vía `mp:gravity-tramo-p`); acueducto y ductos eléctricos no cambiaron.
- **Perfil de profundidad muestreado**: `mp:derive-tramo-values` ahora muestrea la superficie en 10 puntos a lo largo del tramo (no solo los 2 pozos) para no subestimar el ancho ni el volumen si el terreno tiene una loma o vaguada intermedia. El volumen de excavación se integra con regla trapezoidal sobre el perfil real; antes era solo `longitud × ancho × profundidad_media` (promedio de 2 puntos).
- **Degradación seguridad**: sin superficie o sin geometría (p1/p2 nulos), cae exactamente en el cálculo anterior — no hay caso donde el cambio pueda dejar un tramo sin cantidades.
- **Pendiente sin resolver**: la cimentación (Figura 4 vs Figura 4.1, `Bc/4` con mínimo/máximo 100/150mm vs un dato de 40cm) — el usuario indicó que depende de la profundidad/cobertura pero no conoce el umbral exacto. Se buscó en ~300 PDFs del proyecto y en el manual público de PAVCO/NOVAFORT/Amanco sin encontrar el criterio (ese manual usa otra numeración de figuras). **No se tocó `ESPESOR_CAMA` ni la lógica de cimentación** — sigue en el valor fijo de 0.10m que ya existía. Falta: que el usuario aporte el documento fuente de esa imagen, o decidir explícitamente usar Figura 4 fija.

### 2026-08-02 — Limpieza: código muerto y funciones duplicadas (commit `037a16f`)

- Eliminada `urb:export-quantities-excel-legacy` (145 líneas sin ninguna llamada en el archivo).
- `urb:write-anden-dcl`, `urb:write-prefab-dcl`, `urb:write-green-dcl` (generación de diálogos `.dcl`, casi idénticas) unificadas sobre un helper genérico `urb:write-dialog-dcl`. Verificado que el `.dcl` generado es idéntico línea por línea al original (ver testing).
- Patrón repetido 4 veces "lanzar `PLINE` interactivo y esperar" extraído a `urb:draw-polyline-interactive`.

### 2026-08-02 — Versión inicial en git (commit `64da6e1`)

Primer commit: snapshot de `urbanismo_cantidades.lsp` v4.17.7 + `MAIPORE_BLOQUES_REDES_ELECT_LISTAS_V13_OPTIMIZADO.lsp`. Antes de esto el versionado era manual (carpeta `backups/` + archivos `_backup_vXXX`).

Un análisis previo (sin commit, solo lectura) identificó como próximas mejoras razonables: `c:EDITAR` es un dispatcher de 361 líneas con acceso posicional (`nth N`) a XDATA — candidato a accesores con nombre si se vuelve a tocar; y dividir el archivo en varios `.lsp` cargados con `(load)` si sigue creciendo.

## Qué falta / próximos pasos sugeridos

1. **Cimentación (Figura 4/4.1)** — bloqueado esperando el documento fuente o una decisión del usuario.
2. Probar en Civil 3D real el cambio de movimiento de tierras con un tramo real (recargar el `.lsp` en la sesión abierta, correr `EDITAR`, revisar `ANCHO_ZANJA` / `EXCAVACION_M3` / `METODO_CANTIDADES`).
3. Nada más quedó pendiente de las dos limpiezas de código (dead code + duplicados) — verificadas en Civil 3D real.
