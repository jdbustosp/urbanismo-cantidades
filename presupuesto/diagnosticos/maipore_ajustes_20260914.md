# urbanismo maipore.xlsx — los 8 ajustes pedidos

Fecha: 2026-09-14. Agente: Claude. Equipo: BOG085CD119BDQN.
Libro: `colsubsidio.com/.../260915_ACTUALIZACION GENERAL PPTO/urbanismo maipore.xlsx`
Respaldo previo: `Documents/URBANISMO/work/ppto_20260914/backup/urbanismo maipore.ANTES_AJUSTES_20260914.xlsx`

> **Aviso de alcance**: los cambios se aplicaron primero, por error, al `.xlsm`
> `251126_Ppto Urb ext Maipore.xlsm` que el usuario adjuntó como *fuente de datos*
> de las fases PTAR. Ese archivo se restauró **byte a byte** a su estado original;
> la versión con aquellas correcciones quedó aparte en
> `work/ppto_20260914/251126_Ppto_CON_MIS_CORRECCIONES.xlsm` por si se quiere.
> El diagnóstico de ese libro está en `xlsm_ajustes_20260914.md` y sigue siendo
> válido (tenía 20 celdas en `#REF!` por `Memorias!A18`).

## Arquitectura de este libro

- `POR EJECUTAR` (1.723 filas): árbol jerárquico. Columna **A** = nivel (1..5),
  **C** = código autogenerado por fórmula, **D** = actividad, **E** = UM,
  **F..AM** = cantidad por subetapa (constantes; ahí escribe el plugin),
  **AN** = `SUM($F:$AM)`, **AO** = `SUMIF(PRECIOS_UNITARIOS!$B:$B,$D<f>,...!$D:$D)`,
  **AP** = `AN*AO`.
- Los precios NO están en `POR EJECUTAR`: se buscan por **nombre de actividad**
  en `PRECIOS_UNITARIOS` (B = nombre, D = precio). Para cambiar un V/U hay que
  tocar `PRECIOS_UNITARIOS!D`, no la fila del presupuesto.
- El libro vive en **SharePoint**: al abrirlo por COM hay que tocar `wb.FullName`
  antes de enumerar hojas (enlaza en diferido, si no `Sheets.Count` da 0) y
  poner `wb.AutoSaveOn = $false`.

---

## APLICADO

### 3 · Fases PTAR (dato tomado del `.xlsm` adjunto)

Las tres filas `2.12.1.1.x` existían pero **las tres tenían el mismo precio**
($2.996.950.427,13). El `.xlsm` adjunto tiene la tabla `Memorias` con el costo
de construcción de PTAR indexado año por año; de ahí salen los valores reales:

| fila PU | actividad | antes | ahora |
|---|---|---:|---:|
| 808 | PTAR FASE III (2025) | 2.996.950.427 | **2.943.808.568** |
| 809 | PTAR FASE IV (2027) | 2.996.950.427 | **3.145.544.814** |
| 810 | PTAR FASE V (2029) | 2.996.950.427 | **3.337.108.493** |

`2.12 CONSTRUCCION PTAR`: 8.990.851.281 → **9.426.461.875** (+435.610.594).

Nota: esos tres valores sólo se pudieron leer tras reparar la cascada de `#REF!`
del `.xlsm` (celda `Memorias!A18` con `=TRANSPOSE(#REF!)+1`), usando la serie de
inflación del bloque ANTERIOR que el usuario aprobó
(1,0928 / 1,0627 / 1,0477 / 1,0377 / 1,0297 / 1,0300 / 1,0300).

### 6 · Sumidero contra IDU

| | |
|---|---:|
| antes (`PRECIOS_UNITARIOS!D240`) | 14.543.853,23 |
| ahora — IDU 2026-I código 3897, SL-150 H=0,85M prefabricado | **6.186.409** |

`2.4.3.5 SUMINISTRO E INSTALACIÓN DE SUMIDEROS` (110 UN):
1.599.823.856 → **680.504.990** (−919.318.865).

El tipo lo eligió el usuario. Para referencia, el resto de la escalera IDU:
SL-100 prefab 4.673.967 · SL-200 prefab 7.360.452 · SL-250 prefab 8.485.894 ·
NS-047 pluvial en vía (código 4558) 8.015.596.

### Efecto en cadena — el mecanismo de porcentajes SÍ funciona

Tras los dos cambios, `2.1 PRELIMINARES` (3,5%) y `2.13 IMPREVISTOS` (5%)
recalcularon solos:

    2.1  PRELIMINARES   4.359.978.184 -> 4.343.048.394
    2.13 IMPREVISTOS    6.446.539.172 -> 6.421.507.269
    2    ACTIVIDADES POR EJECUTAR 135.377.322.613 -> 134.851.652.648

---

## 1 · Subtotales por subetapa — el mecanismo está bien, pero es frágil

Hay **270 filas con UM = %**: 34 de preliminares (3,5% por subetapa), las de
imprevistos (5%) y las de indirectos (capítulo 5). Su V/U es, p.ej.:

    AO7 = SUMPRODUCT(--($A$41:$A$1347=5), $F$41:$F$1347, $AO$41:$AO$1347)

o sea: suma todas las filas de **nivel 5** entre las filas 41 y 1347, de la
**columna de esa subetapa**. Hoy está correcto — 41 es justo después de las
propias filas de % y 1347 es justo el final de `2.12`, antes de `2.13 IMPREVISTOS`.

**El riesgo**: las cotas 41 y 1347 están clavadas. Insertar filas *dentro* del
rango no molesta (Excel ajusta la referencia), pero **cualquier actividad nueva
agregada después de la fila 1347 queda fuera del subtotal** y el porcentaje no se
mueve. Es la fragilidad que el usuario describe. Se comprobó que hoy no falta
nada: cada una de las 34 subetapas tiene su fila de % y su columna.

## 2 · Excavaciones de andén — CAUSA ENCONTRADA, es del `.lsp`

La fila existe y está en cero:

    2.2.1.4.1  Excavación mecánica en material común (...)  M3  cantidad 0
    2.2.2.5.1  (la misma actividad, pero en VÍA)            M3  12.785,44

El plugin **sí** emite esa actividad para andén (`urbanismo_cantidades.lsp`
línea 31009), pero justo antes hace esto:

```lisp
(if (wcmatch (strcase (urb:safe-string
      (cdr (assoc "ANDEN_METODO" atts)) "PENDIENTE")) "PENDIENTE*")
  (progn
    (setq corte 0.0 relleno 0.0)
    (prompt (strcat "\nMT pendiente en anden " handle
                    ": corte/relleno no exportados."))))
```

Cuando el andén tiene `ANDEN_METODO = PENDIENTE` (el valor por defecto), el
corte y el relleno se fuerzan a **0** a propósito, para no exportar como volumen
medido algo que no se comparó contra la superficie de terreno `SUP_TN`.

O sea: no falta la fila ni falta el emisor — **faltan los andenes con método de
terreno**. Para que lleguen cantidades hay que regenerar los andenes calculando
el MT contra `SUP_TN`. Por eso el recebo `2.2.1.4.2` sí trae 5,44 M3 (un andén
que sí quedó con método real) y el resto no.

## 5 · Pozos desagregados — YA SE UBICÓ EL ÍTEM A TODO COSTO

Comparando las dos redes queda evidente:

**`2.4.2.4` SANITARIO** (el problema)

| código | actividad | cant | V/U | total |
|---|---|---:|---:|---:|
| 2.4.2.4.1 | Suministro e instalación **base, cono y tapa** para pozo | 83 UN | 6.292.915 | 522.311.916 |
| 2.4.2.4.2 | Cañuela y acabado interior de pozo | 83 UN | 954.000 | 79.182.000 |
| 2.4.2.4.3 | Anillo/cilindro prefabricado de pozo | 265,51 ML | 1.916.374 | 508.816.522 |
| 2.4.2.4.4 | **Cono de reducción para pozo** | 83 UN | 1.272.000 | 105.576.000 |
| 2.4.2.4.5 | **Marco y tapa de pozo** | 83 UN | 1.590.000 | 131.970.000 |

**`2.4.3.4` PLUVIAL** (el patrón limpio)

| código | actividad | cant |
|---|---|---:|
| 2.4.3.4.1 | Suministro e instalación base, cono y tapa para pozo | 141 UN |
| 2.4.3.4.2 | Anillo en concreto prefabricado | 7,39 ML |

El `.1` ya es **a todo costo: incluye base, cono y tapa**. Pluvial no cobra nada
más aparte del anillo. Sanitario sí, y ahí está la duplicación:

- `2.4.2.4.4 Cono de reducción` → el cono ya está en `.1` → **105.576.000 duplicados**
- `2.4.2.4.5 Marco y tapa` → la tapa ya está en `.1` → **131.970.000 duplicados**
- `2.4.2.4.2 Cañuela` (79.182.000) → NO está nombrada en `.1`, pero pluvial
  tampoco la cobra. Queda a criterio.

Estrictamente duplicado: **237.546.000**. Con la cañuela: **316.728.000**.

**OJO**: el plugin también emite esas dos actividades (`.lsp` líneas 31867 y
31869), así que si sólo se ponen en cero volverán en la próxima exportación.
Hay que quitarlas también del emisor.

Aparte: el anillo de sanitario da 3,2 ML por pozo (265,51 / 83) y el de pluvial
0,05 ML por pozo (7,39 / 141). Uno de los dos está mal medido; por la altura
típica de un pozo, el sospechoso es el de **pluvial**, que parece faltante.

## 7 · Cabezales al bioswale — falta el precio

    2.4.3.7.1  Cabezal de descarga en concreto Ø12"-Ø16" (incl. aletas y solado)
               66 UN  x  8.500.000  =  561.000.000
    2.4.3.7.2  ... Ø18"-Ø24"        0 UN  x  12.500.000
    2.4.3.7.3  ... Ø8"-Ø10"         0 UN  x   6.000.000
    2.4.3.7.4  Cabezal de entrega   0 UN  x  37.186.137

La escalera 6 / 8,5 / 12,5 M es internamente coherente. El IDU **no sirve** de
referencia: sus ítems "cabezal" son vigas cabezal de puente en M3 de concreto,
no cabezales de descarga de alcantarillado. La única referencia alta del propio
libro es "Cabezal de entrega" a 37.186.137, 4,4 veces más. Se necesita el valor.

## 4 · Nivel azul = subetapas en indexación — plan, sin ejecutar

Hoy el capítulo 6 está agrupado por AÑO y la etapa queda en el nivel 5:

    6        INCREMENTOS (INDEXACION)                     41.559.084.747
    6.1      INDEXACION POR EJECUTAR
    6.1.1    INDEXACION AÑO 2023            <- nivel 3, el "azul"
    6.1.1.1  INDEXACION AÑO 2023            <- nivel 4, redundante
    6.1.1.1.1  INDEXACION ... AÑO 2023 (GENERAL)    <- nivel 5, aquí está la etapa
    6.1.1.1.2  INDEXACION ... AÑO 2023 (ETAPA 01)

Para que el nivel azul sean las subetapas hay que **invertir el agrupamiento**:
nivel 3 = etapa, nivel 5 = año. Son 51 filas de nivel 5 reordenadas + 10 pares
de cabecera en vez de 8 (4 filas más, que caben al final porque 1723 es la
última fila del libro). El código de la columna C es una fórmula y se renumera
solo; el precio lo busca por nombre, así que mover la fila no lo pierde.

Salvedad importante: la indexación está desagregada por **ETAPA**
(GENERAL, ETAPA 01..09), mientras que los porcentajes y la hoja DINAMICA van por
**SUBETAPA** (1, 2, 3, 3A, 3B, 4, 4A...). Bajar la indexación a subetapa no es
reordenar: hay que recalcularla, y ese modelo no está en este libro.

## 8 · Cantidades del bioswale

La respuesta completa (la receta de 9 actividades sobre el área rayada) está en
`xlsm_ajustes_20260914.md`, sección 8. Aplica igual porque es comportamiento del
plugin, no del libro. En ESTE libro el bioswale tampoco tiene dónde caer: no hay
filas con esos nombres, por eso `ALC-PLUVIAL / Jardinería 2.656,77 M2` viene
saliendo como huérfana en las exportaciones.
