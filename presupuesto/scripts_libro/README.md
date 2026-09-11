# Scripts de mantenimiento del libro `urbanismo maipore.xlsx` (2026-09-07/08)

Herramientas PowerShell usadas para construir/reparar el libro vigente de
SharePoint. Todas abren el libro por COM con `AutoSaveOn=false` y **exigen
el libro CERRADO en Excel**. Correr con `& ruta\script.ps1` (no `-File`).
Antes de cualquier corrida sobre el vigente: **backup a
`...\PROYECTO_URBANISMO_GENERAL\BACKUPS\`** (los de precios ya lo hacen solos).

> **OJO LOCALIZACIÓN (lección 2026-09-08)**: este Excel es es-CO y
> interpreta las cadenas de `NumberFormat` **en español** (`,` = decimal,
> `.` = miles), tanto en `Range` como en `PivotField`. Usar `"0,00%"`,
> `"$ #.##0"`, `"#.##0,00###"`. Con cadenas gringas (`"0.00%"`) el 3,5%
> sale como `004%` y el dinero pierde los separadores de miles.
> `arreglar_formatos.ps1` detecta la convención sola con una celda de
> prueba: copiar ese patrón si se vuelve a formatear algo.

| Script | Qué hace |
|---|---|
| `reescribir_pe42.ps1` | Reescribe la hoja POR EJECUTAR completa (42 columnas, GEN en AM) desde `pe_nuevo3.tsv`: datos, numeración autónoma, anclas, CANT/VU/VT, preliminares (subetapas=base, VU=3,5%), subtotales de capítulo, formato L1, agrupadores, PE_RANGO=A2:AP5000. Verifica antes de guardar. |
| `pe_nuevo3.tsv` | Fuente de la hoja (1.540 filas, estado v4.71.1). Igual copia en `diagnosticos\pe_nuevo3_20260907.tsv`. |
| `transformar_pe2.ps1` / `transformar_pe3.ps1` | Historia de la transformación pe_nuevo → pe_nuevo2 (pluvial desagregado, MT reordenado) → pe_nuevo3 (depuración: −37 filas). Solo referencia. |
| `bd_fix.ps1` | Reinstala la query BD_PE ROBUSTA (UnpivotOtherColumns, sin lista fija de subetapas) y refresca BD_CONSOL + dinámica. Correr si el "Actualizar todo" vuelve a fallar por columnas. |
| `bd_pivot3.ps1` | **SUPERADO por `dinamica_formatos.ps1`** (usaba `PivotSelect '[All]'`, que selecciona TODAS las celdas del campo y dejaba invisible también el nivel 5). Se conserva como referencia. |
| `ajustar_porcentajes.ps1` | **(2026-09-08)** Capítulos por porcentaje: pone el **VU VIVO** (`SUMPRODUCT` = subtotal real de la etapa) en preliminares/PGU/CAR/PMT/ADMIN/INTERVENTORÍA/ESTUDIOS — antes era un `SUMIF` a un número CONGELADO en PRECIOS_UNITARIOS — y explota "Obras preliminares generales" en 10 filas (ETAPA 01..09 + GENERAL) con el 3,5% en la columna de su etapa. Verifica que el total del grupo 2 y el de preliminares no cambien. **Re-correr después de cualquier reescritura completa de la hoja.** |
| `dinamica_formatos.ps1` | **(2026-09-08)** Dinámica: refresca la BD, expande todos los niveles, deja CANTIDAD y V.UNITARIO **visibles solo en nivel 5** (en capítulos y total general solo se ve VALOR_TOTAL) y pinta color por nivel (N1 gris, N2 amarillo, N3 azul, **N4 durazno** — antes el estilo repetía el color del N2), con formato % en las actividades cuya UM es %. **Re-correr si se rearma el layout de la pivot.** |
| `arreglar_formatos.ps1` | **(2026-09-08)** Detecta la convención de `NumberFormat` (ES/EN) y aplica los formatos correctos a las filas de porcentaje y a los campos de valor de la dinámica. |
| `calcular_bases.ps1` | Calcula el subtotal VIVO por etapa del grupo 2 y lo compara contra los VU congelados (fue el diagnóstico que destapó el problema). Necesita `pe_0908.tsv` extraído con `xlsx2csv.ps1`. |
| `agregar_etapa06_general.ps1` | **PENDIENTE DE DECISIÓN — no se ha corrido.** Agrega las filas que faltan por cobertura: ETAPA 06 en los 6 capítulos y GENERAL en PGU/PMT (+783.253.493 en total). Ver el handoff. |
| `verificar_0908.ps1` / `verif_final_0908.ps1` | Lecturas de control (cierran sin guardar): bloque de preliminares, fórmulas de VU, totales de nivel 1, y niveles/colores/formatos de la dinámica. |
| `precios_pluvial.ps1` / `precios_ronda3.ps1` | Altas/correcciones de PRECIOS_UNITARIOS (idempotentes: no duplican). Justificación en `diagnosticos\precios_pluvial_20260907.tsv` y `precios_ronda3_20260907.tsv`. |
| `censo_vu.ps1` | Censo de control: actividades nivel 5 sin precio, filas en cero por capítulo y memorias ACU de zanja. Necesita extraer antes `pe42_live.tsv`/`pu_live.tsv` con `xlsx2csv.ps1`. |
| `ejecutado5_armar.ps1` / `ejecutado5_escribir.ps1` | **(2026-09-11)** Hoja EJECUTADO en 5 niveles (1 EJECUTADO / categoría / capítulo / ACTA / CONTRATISTA). Base = pagos del archivo de actas (hoja `Consolidado Jul 2026`): **EJECUTADO** = su VALOR (total 158.872.558.615 = hoja Resumen de actas); **DESEMBOLSADO** = `VR TOTAL EJEC Coinver y PYC` de la BD de Lugel (su dinámica lo llama `VR DESEM. FOVIS`), 0 si el pago aún no está en la BD. *Armar* necesita `bd.tsv` (hoja BD de `251126_Ppto Urb ext Maipore.xlsm`) y `actas_cons.tsv` (hoja `Consolidado Jul 2026`) extraídos con `xlsx2csv.ps1`. *Escribir* reemplaza `EJECUTADO_Tabla`, reinstala la query `BD_EJEC` (EJECUTADO→VALOR_TOTAL, DESEMBOLSADO→VR_DESEM_FOVIS), refresca BD_CONSOL, agrega el campo `VR DESEM. FOVIS` a la dinámica, verifica totales antes de guardar y colorea por nivel. Correr con `-espEjec`/`-espDes` = totales esperados. |
| `xlsx2csv.ps1` | Extrae una hoja a TSV sin abrir Excel. OJO: antepone el nº de fila como col 0 y el texto sale doble-codificado (UTF-8 leído como 1252) — `censo_vu.ps1` muestra cómo repararlo al leer. |

Rutas quemadas al libro vigente de este PC (`C:\Users\juanbusper\colsubsidio.com\...`);
en otro PC ajustar la variable `$libro` al montaje local de SharePoint.
