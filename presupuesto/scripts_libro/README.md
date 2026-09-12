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
| `pe_subetapas.ps1` | **(2026-09-11)** POR EJECUTAR: agrega el capítulo **2.13 IMPREVISTOS** (5 % sobre el subtotal de actividades por ejecutar, 7.168.660.463) y convierte de ETAPA a **SUBETAPA** todos los capítulos que se calculan por % (PGU 0,2 %, CAR 0,75 %, PMT 0,5 %, ADMIN 5 %, INTERVENTORÍA 3,5 %, ESTUDIOS 1 %). Verifica que el total de cada capítulo no cambie antes de guardar. Las 7 filas de IMPREVISTOS viejas quedan donde están (decisión del usuario). |
| `dinamica_a3.ps1` | **(2026-09-11)** DINÁMICA: tabla resumen nueva en `A3` (ETAPA → SUBETAPA → ejecutado/por ejecutar, con VT total) desde la tabla BD, y formato **a prueba de actualizaciones** — el color por nivel y el ocultar CANTIDAD/V.UNITARIO fuera del nivel 5 se hacen con `FormatConditions` (`.NumberFormat=";;;"`), que es lo único que sobrevive a refrescar la pivot. |
| `fix_dinamica.ps1` | **(2026-09-12)** BD_PE: la ETAPA sale del primer dígito de la SUBETAPA (antes un `if d <= 2 then d + 1` corría la etapa 1 a la 2 y la 2 a la 3) y la subetapa `GEN` pasa a llamarse `GENERAL`, para que ETAPA GENERAL tenga una sola subetapa. |
| `estilo_niveles.ps1` | **(2026-09-12)** Crea el estilo de tabla dinámica `URB_NIVELES` (duplicado del que tenía, para no perder bordes) y pinta `SubtotalRow1/2/3` + `RowSubheading1/2/3` con los colores de nivel. Es lo ÚNICO que pinta la fila completa y sobrevive a actualizar: un formato condicional que pise el área de valores de una pivot lo recorta Excel a la columna del rótulo. |
| `cant_nivel5.ps1` | **(2026-09-12)** Saca CANTIDAD y V. UNITARIO del área de valores de la dinámica y las deja como columnas J y K con fórmula (SUMIF/AVERAGEIF contra la tabla BD), que solo se llenan cuando el rótulo es un nivel 5. Así los subtotales de esas dos columnas no existen y no hay nada que se desbarajuste al actualizar. |
| `cf_rotulos.ps1` | **(2026-09-12)** Inyecta en el XML del libro el formato condicional de color por nivel de la columna del rótulo (4 niveles distintos). Se hace por XML porque `FormatConditions.Add` por COM **no acepta fórmulas que miren otra hoja** (`BD!...`), ni por nombre definido. |
| `censo_nombres.ps1` | **(2026-09-12)** Censo de actividades de nivel 5 con nombre repetido o parecido y precio distinto. Salida en `diagnosticos/censo_nombres_precios_20260912.tsv`. |
| `unificar_nombres.ps1` | **(2026-09-12)** Aplica SOLO las unificaciones de nombre que no mueven plata (mismo precio, distinta escritura). |
| `verificar_final.ps1` | **(2026-09-12)** Control de la hoja DINAMICA: abre, actualiza N veces y reporta colores por nivel, si CANTIDAD/V.UNITARIO salen solo en nivel 5 y que no queden columnas auxiliares ocultas. |
| `xlsx2csv.ps1` | Extrae una hoja a TSV sin abrir Excel. OJO: antepone el nº de fila como col 0 y el texto sale doble-codificado (UTF-8 leído como 1252) — `censo_vu.ps1` muestra cómo repararlo al leer. |

Rutas quemadas al libro vigente de este PC (`C:\Users\juanbusper\colsubsidio.com\...`);
en otro PC ajustar la variable `$libro` al montaje local de SharePoint.

## Tanda 2026-09-12 (tarde)

| Script | Qué hace |
|---|---|
| `pivot_formats.ps1` | **Lo importante de esta tanda.** Inyecta en `xl/pivotTables/*.xml` los `<formats>` con `<pivotArea>` que pintan el color por nivel en **toda la fila** y ocultan CANTIDAD/V.UNITARIO fuera del nivel 5. Es el ÚNICO mecanismo que sobrevive a actualizar: un formato condicional de la hoja lo recorta Excel donde pisa el área de valores de la pivot. Hacen falta **dos entradas por nivel** (con `defaultSubtotal` solo se pinta el rótulo; las celdas de valor van con `type="data" collapsedLevelsAreSubtotals="1"`), y hay que poner `applyPatternFormats="1"` y `applyNumberFormats="1"` en la definición de la pivot. |
| `estilo_sin_color.ps1` | Deja el estilo `URB_NIVELES` sin relleno en `SubtotalRow1/2/3` y `RowSubheading1/2/3`: con relleno le gana al formato de área y el nivel 4 salía del color del 2 (un estilo solo expone 3 niveles de subtotal). |
| `restaurar_columnas.ps1` | Devuelve CANTIDAD y V. UNITARIO al área de valores de la dinámica, en su orden de siempre, y limpia las columnas de fórmula que se habían usado como alternativa. |
| `chequeo2.ps1` | Control: abre, actualiza, y reporta los colores de las 5 columnas por nivel y si CANTIDAD sale solo en el nivel 5. |
| `hoja_externos.ps1` | Arma la hoja **`PPTOS EXTERNOS`**: por cada tercero, una banda con el capítulo del libro que alimenta y el archivo fuente, y debajo su presupuesto y sus memorias pegados como valores. Re-correr cuando aparezca el xlsx del colector. |
| `columna_origen.ps1` | Escribe la columna **`ORIGEN`** en POR EJECUTAR (columna **AQ**, fuera de `PE_RANGO`, así BD_PE no la ve): AUTOCAD / EXTERNO: … / PORCENTAJE / MANUAL, cruzando contra la tabla de memorias del DWG. **Regla: los scripts que escriben cantidades desde las memorias solo pueden tocar las filas con `ORIGEN = AUTOCAD`.** |
| `barrido_idu.ps1` / `idu_ok_detalle.ps1` | Barrido de nombres y precios contra el catálogo IDU 2026-I. Salidas en `diagnosticos\barrido_precios_idu_20260912.tsv` y `diagnosticos\idu_match_confiable_20260912.tsv`. |
| `sacar_colector2.ps1` | Saca el xlsx adjunto del correo del colector por Outlook. **Hoy se queda colgado**: guardar el adjunto a mano. |

> **Límites de Excel topados aquí, para no repetirlos**: `FormatConditions.Add`
> por COM rechaza cualquier fórmula que mire otra hoja (`BD!...`), incluso a
> través de un nombre definido. `PivotSelect` no sabe aislar filas de subtotal
> (`'N1'[All;Total]` lo rechaza; solo acepta `'N1'[All]`). Asignar un arreglo
> 2D a `Range.Value2` desde PowerShell falla con *InvalidCastException*: hay
> que usar `Copy()` + `PasteSpecial(-4163/-4122)`. Y `$xl.CutCopyMode = 0` no
> lo acepta el interop tipado (envolver en try/catch).
