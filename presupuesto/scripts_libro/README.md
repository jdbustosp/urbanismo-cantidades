# Scripts de mantenimiento del libro `urbanismo maipore.xlsx` (2026-09-07)

Herramientas PowerShell usadas para construir/reparar el libro vigente de
SharePoint. Todas abren el libro por COM con `AutoSaveOn=false` y **exigen
el libro CERRADO en Excel**. Correr con `& ruta\script.ps1` (no `-File`).
Antes de cualquier corrida sobre el vigente: **backup a
`...\PROYECTO_URBANISMO_GENERAL\BACKUPS\`** (los de precios ya lo hacen solos).

| Script | Qué hace |
|---|---|
| `reescribir_pe42.ps1` | Reescribe la hoja POR EJECUTAR completa (42 columnas, GEN en AM) desde `pe_nuevo3.tsv`: datos, numeración autónoma, anclas, CANT/VU/VT, preliminares (subetapas=base, VU=3,5%), subtotales de capítulo, formato L1, agrupadores, PE_RANGO=A2:AP5000. Verifica antes de guardar. |
| `pe_nuevo3.tsv` | Fuente de la hoja (1.540 filas, estado v4.71.1). Igual copia en `diagnosticos\pe_nuevo3_20260907.tsv`. |
| `transformar_pe2.ps1` / `transformar_pe3.ps1` | Historia de la transformación pe_nuevo → pe_nuevo2 (pluvial desagregado, MT reordenado) → pe_nuevo3 (depuración: −37 filas). Solo referencia. |
| `bd_fix.ps1` | Reinstala la query BD_PE ROBUSTA (UnpivotOtherColumns, sin lista fija de subetapas) y refresca BD_CONSOL + dinámica. Correr si el "Actualizar todo" vuelve a fallar por columnas. |
| `bd_pivot3.ps1` | Subtotales de la dinámica: activa N1..N4 (arriba) y oculta los subtotales de CANTIDAD y V.UNITARIO (formato `;;;` vía PivotSelect) — solo se ve el de VALOR_TOTAL. **Re-correr si se rearma el layout de la pivot.** |
| `precios_pluvial.ps1` / `precios_ronda3.ps1` | Altas/correcciones de PRECIOS_UNITARIOS (idempotentes: no duplican). Justificación en `diagnosticos\precios_pluvial_20260907.tsv` y `precios_ronda3_20260907.tsv`. |
| `censo_vu.ps1` | Censo de control: actividades nivel 5 sin precio, filas en cero por capítulo y memorias ACU de zanja. Necesita extraer antes `pe42_live.tsv`/`pu_live.tsv` con `xlsx2csv.ps1`. |
| `xlsx2csv.ps1` | Extrae una hoja a TSV sin abrir Excel. OJO: antepone el nº de fila como col 0 y el texto sale doble-codificado (UTF-8 leído como 1252) — `censo_vu.ps1` muestra cómo repararlo al leer. |

Rutas quemadas al libro vigente de este PC (`C:\Users\juanbusper\colsubsidio.com\...`);
en otro PC ajustar la variable `$libro` al montaje local de SharePoint.
