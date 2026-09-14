# Actividades y formulacion: ciclorruta, rampa peatonal, paso peatonal y zona verde

Generado 2026-09-13 contra el libro y el motor v5.3.0.
"Sin formulacion" = el plugin NUNCA emite esa actividad: la cantidad se escribe a mano.


## 2.2.3 CICLORRUTA

| codigo | actividad | UM | cantidad hoy | como la calcula AutoCAD |
|---|---|---|---|---|
| 2.2.3.1.1 | Compactación de subrasante (Incluye nivelación) | M2 | 0 | AREA x 1,00 -- area de la polilinea de la ciclorruta |
| 2.2.3.1.2 | Descapote mecánico de material vegetal (Incluye cargue y retiro externo) | M2 | 0 | AREA x 1,00 |
| 2.2.3.2.1 | Suministro, extendida y compactación de Rodadura Asfáltica MD-13 | M3 | 0 | AREA x 0,08 -- espesor editable (Estructura de senderos) |
| 2.2.3.2.2 | Transporte de equipos para asfaltos | VJ | 0 | **SIN FORMULACION** -- manual |
| 2.2.3.2.3 | Bordillo prefabricado A-80 | UN | 0 | PERIMETRO x 1,25 (1 pieza cada 0,80 m). SE SALTA si la ciclorruta lleva prefabricado por costados: ahi cada costado es su propio bloque y cuenta su ML |
| 2.2.3.2.4 | Transporte de prefabricados | KG | 0 | **SIN FORMULACION** -- manual |
| 2.2.3.2.5 | Suministro de cañuela prefabricada | UN | 0 | **SIN FORMULACION** -- manual |
| 2.2.3.3.1 | M.O. instalación de bordillo prefabricado | ML | 0 | PERIMETRO x 1,00. Mismo salto que el bordillo |
| 2.2.3.3.2 | M.O. instalación de cañuela prefabricada | ML | 0 | **SIN FORMULACION** -- manual |
| 2.2.3.4.1 | Excavación mecánica en material común (Incluye cargue, transporte y disposición externa) | M3 | 0 | AREA x 0,38 -- espesor editable |
| 2.2.3.4.2 | Suministro y colocación de recebo B-200 | M3 | 0 | **SIN FORMULACION** -- manual |
| 2.2.3.5.1 | Subbase granular SBG | M3 | 0 | AREA x 0,30 -- espesor editable |
| 2.2.3.5.2 | Geotextil tejido 2100 | M2 | 0 | AREA x 1,00 |

**2.2.3: 13 actividades, 8 calculadas por AutoCAD, 5 sin formulacion.**

## 2.2.5 RAMPA PEATONAL

| codigo | actividad | UM | cantidad hoy | como la calcula AutoCAD |
|---|---|---|---|---|
| 2.2.5.1.1 | Compactación de subrasante (Incluye nivelación) | M2 | 0 | AREA_M2 del bloque de rampa |
| 2.2.5.1.2 | Descapote mecánico de material vegetal (Incluye cargue y retiro externo) | M2 | 0 | AREA_M2 |
| 2.2.5.2.1 | Suministro sardinel alto A-86 para rampas | ML | 0 | **SIN FORMULACION** -- manual |
| 2.2.5.2.2 | Suministro sardinel bajo A-85 para rampa | UN | 0 | SARDINEL_A85_ML del bloque, redondeado al entero superior (la pieza A-85 es de 1,00 m) |
| 2.2.5.2.3 | Suministro sardinel especial A-100 para rampa | UN | 0 | **SIN FORMULACION** -- manual |
| 2.2.5.2.4 | Suministro y construcción de remate de rampa en concreto fundido en sitio | M2 | 0 | A81_UND x 0,39 m2 por pieza |
| 2.2.5.2.5 | Adoquín gris 10x20x6 | UN | 0 | ADOQUIN_20X10_UND del bloque |
| 2.2.5.2.6 | Loseta toperol 20x20x6 | UN | 0 | LOSETA_TOPEROL_UND; si no, TOPEROL_ML / 0,20 |
| 2.2.5.2.7 | Loseta guía 20x20x6 | UN | 0 | LOSETA_GUIA_UND; si no, LOSETA_GUIA_ML / 0,20 |
| 2.2.5.2.8 | Bordillo prefabricado A-80 | UN | 2 | BORDILLO_ML / 0,80 |
| 2.2.5.2.9 | Transporte de prefabricados | KG | 0 | suma de pesos de catalogo: adoquines x 2,88 kg + losetas x 5,76 kg + A-80 x 134,40 kg |
| 2.2.5.2.10 | Arena de nivelación | M3 | 0 | ARENA_M3 del bloque; si no, AREA_M2 x 0,04 |
| 2.2.5.2.11 | Loseta lisa 20x20x6 | UN | 0 | LOSETA_LISA_UND |
| 2.2.5.3.1 | M.O. localización y replanteo | M2 | 0 | AREA_M2 |
| 2.2.5.3.2 | M.O. instalación de adoquín y tabletas | M2 | 0 | AREA_M2 |
| 2.2.5.3.3 | M.O. nivelación con arena | M2 | 0 | AREA_M2 |
| 2.2.5.3.4 | M.O. instalación de bordillo prefabricado | ML | 11.9 | BORDILLO_ML |
| 2.2.5.3.5 | M.O. instalación de loseta guía y toperol | ML | 8 | LOSETA_GUIA_ML + TOPEROL_ML |
| 2.2.5.3.6 | M.O. instalación de sardinel prefabricado | ML | 0 | **SIN FORMULACION** -- manual |
| 2.2.5.4.1 | Excavación mecánica en material común (Incluye cargue, transporte y disposición externa) | M3 | 0 | corte del movimiento de tierras del bloque; si no lo trae, AREA_M2 x espesor de anden |
| 2.2.5.4.2 | Suministro y colocación de recebo B-200 | M3 | 0 | relleno del movimiento de tierras del bloque (0 si no lo trae) |
| 2.2.5.5.1 | Subbase granular SBG | M3 | 0 | SBG_M3 del bloque; si no, AREA_M2 x 0,50 |
| 2.2.5.5.2 | Geotextil tejido 2100 | M2 | 0 | GEOTEXTIL_M2 del bloque; si no, AREA_M2 x 1,15 |
| 2.2.5.6.1 | Suministro e instalación de bolardo alto en hierro Tipo M-63 | UN | 0 | BOLARDO_UND del bloque |

**2.2.5: 24 actividades, 21 calculadas por AutoCAD, 3 sin formulacion.**

## 2.2.6 PASO PEATONAL SEGURO

| codigo | actividad | UM | cantidad hoy | como la calcula AutoCAD |
|---|---|---|---|---|
| 2.2.6.1.1 | Compactación de subrasante (Incluye nivelación) | M2 | 0 | AREA_M2 del bloque de rampa |
| 2.2.6.1.2 | Descapote mecánico de material vegetal (Incluye cargue y retiro externo) | M2 | 0 | AREA_M2 |
| 2.2.6.2.1 | Adoquín gris 10x20x6 | UN | 0 | ADOQUIN_20X10_UND del bloque |
| 2.2.6.2.2 | Bordillo prefabricado A-80 | UN | 0 | BORDILLO_ML / 0,80 |
| 2.2.6.2.3 | Transporte de prefabricados | KG | 0 | suma de pesos de catalogo: adoquines x 2,88 kg + losetas x 5,76 kg + A-80 x 134,40 kg |
| 2.2.6.2.4 | Arena de nivelación | M3 | 0 | ARENA_M3 del bloque; si no, AREA_M2 x 0,04 |
| 2.2.6.3.1 | M.O. localización y replanteo | M2 | 0 | AREA_M2 |
| 2.2.6.3.2 | M.O. instalación de adoquín y tabletas | M2 | 0 | AREA_M2 |
| 2.2.6.3.3 | M.O. nivelación con arena | M2 | 0 | AREA_M2 |
| 2.2.6.3.4 | M.O. instalación de bordillo prefabricado | ML | 0 | BORDILLO_ML |
| 2.2.6.4.1 | Excavación mecánica en material común (Incluye cargue, transporte y disposición externa) | M3 | 0 | corte del movimiento de tierras del bloque; si no lo trae, AREA_M2 x espesor de anden |
| 2.2.6.4.2 | Relleno con material seleccionado B-200 | M3 | 0 | **SIN FORMULACION** -- manual |
| 2.2.6.4.3 | Suministro y colocación de recebo | M3 | 0 | relleno del movimiento de tierras del bloque |
| 2.2.6.5.1 | Subbase granular SBG | M3 | 0 | SBG_M3 del bloque; si no, AREA_M2 x 0,50 |
| 2.2.6.5.2 | Geotextil tejido 2100 | M2 | 0 | GEOTEXTIL_M2 del bloque; si no, AREA_M2 x 1,15 |

**2.2.6: 15 actividades, 14 calculadas por AutoCAD, 1 sin formulacion.**

## 2.2.7 ZONA VERDE

| codigo | actividad | UM | cantidad hoy | como la calcula AutoCAD |
|---|---|---|---|---|
| 2.2.7.1.1 | Empradización y conformación | M2 | 0 | AREA_M2 del bloque. SOLO cuando la zona verde NO esta dentro de un parque |
| 2.2.7.2.1 | Suministro e instalación de árbol | UN | 0 | **SIN FORMULACION** -- manual |
| 2.2.7.3.1 | Excavación mecánica en material común (Incluye cargue, transporte y disposición externa) | M3 | 0 | **SIN FORMULACION** -- manual |
| 2.2.7.3.2 | Suministro y colocación de recebo B-200 | M3 | 0 | **SIN FORMULACION** -- manual |

**2.2.7: 4 actividades, 1 calculadas por AutoCAD, 3 sin formulacion.**

## Total

**56 actividades en los cuatro capitulos; 12 sin formulacion.**

## Lo que el plugin calcula y NO tiene fila donde caer

Estas tres las emite la zona verde cuando esta DENTRO DE UN PARQUE, y el
capitulo 2.2.7 no las tiene. Hoy se calculan y se pierden:

| actividad | UM | como la calcula |
|---|---|---|
| Localizacion y replanteo | M2 | AREA_M2 del bloque |
| Relleno Manual Tierra Negra X 30CM | M3 | VOLUMEN; si no, AREA_M2 x espesor (0,20 por defecto) |
| Coberturas Zonas Verdes | M2 | AREA_M2 del bloque |

## Notas

- Las cantidades de la columna "cantidad hoy" son las del libro al
  2026-09-13. Casi todas en cero porque esos elementos aun no se han
  dibujado; lo unico con dato es la rampa peatonal (bordillo y su M.O.).
- Los espesores marcados "editable" se cambian desde la ventana
  Estructura de senderos y quedan guardados en el dibujo.
- Ademas de estas actividades fijas, cada familia admite PARAMETRICAS
  (AREA, PERIMETRO, VOLUMEN, CORTE, RELLENO, UNIDAD) que el usuario puede
  enganchar a cualquier actividad del libro sin tocar el codigo.
- 2.2.7 tiene el corte y el relleno de la zona verde disponibles como
  parametricas, pero sus dos filas de movimiento de tierras (2.2.7.3.1 y
  2.2.7.3.2) NO se alimentan solas.
