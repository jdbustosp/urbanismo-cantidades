# 251126_Ppto Urb ext Maipore.xlsm — diagnóstico de los 8 ajustes pedidos

Fecha: 2026-09-14. Agente: Claude. Equipo: BOG085CD119BDQN.
Archivo: `Downloads/251126_Ppto Urb ext Maipore.xlsm` (5,9 MB, con macros).
Respaldo: `Documents/URBANISMO/work/ppto_20260914/backup/...ORIGINAL.xlsm`

Estructura: hoja `BD` (3.329 filas; tabla plana con NIVEL PPTO 1..6, UM, Cant,
V/U, VR TOTAL, ETAPA) + 6 tablas dinámicas. La de los pantallazos es
`pivotTable1`, hoja "Din ppto", con campos de fila NIVEL 1, NIVEL 2, NIVEL 3 y
**NIVEL 6**. No tiene vínculos externos. Cálculo en automático (no es el problema).

---

## 1. Los porcentajes del subtotal no recalculan — CAUSA RAÍZ

No es recálculo: **están en error de referencia**. Todo sale de UNA celda:

    Memorias!A18  =  =TRANSPOSE(#REF!)+1

Era una matricial que derramaba la inflación 2024-2029 en A18:A23 (el `+1`
convierte el % en factor). Borraron el rango origen; el derrame se colapsó y dejó
**A19:A22 vacías** y A18 rota.

Cascada:

    Memorias!A18
      -> Memorias!A17 = AVERAGE(A16,A18)
      -> Memorias!C17:C23, D17:D23, E17:E23, F18:F23, H17:H23
      -> BD!T1135..T1137 = Memorias!$C$18      (las 3 fases PTAR)
      -> BD!U1135..U1137
      -> todo SUMIFS que sume U con ETAPA 01

Filas de porcentaje de ETAPA 01 rotas: f1201 PGU 0,20% · f1213 GESTIÓN AMBIENTAL
0,75% · f1247 PMT 0,50% · f1272 ADMIN DELEGADA 5,00% · f1282 INC 2024-2025 7,00%
· f1292 INTERVENTORÍA 3,50% · f1306 ESTUDIOS Y DISEÑOS 1,00%.

El código `-2146826265` de esas celdas es `xlErrRef` leído por COM, no un negativo.

### Segundo defecto, independiente: dos estilos de SUMIFS conviviendo

    f1201 y otras:  =SUMIFS(U:U,X:X,X1201,L:L,"4. ACTIVIDADES POR EJECUTAR")
    f1282 y otras:  =SUMIFS($U$3:$U$1281,$X$3:$X$1281,X1282,$L$3:$L$1281,...)

- La de `U:U` **se incluye a sí misma** (esas filas también son del capítulo 4).
- La acotada está **clavada en la fila 1281**: toda actividad nueva agregada
  debajo NO entra al subtotal. Eso es literalmente "no me recalcula el subtotal de
  la subetapa", y volverá a morder apenas se agreguen las excavaciones o las PTAR.

---

## 3. Fases PTAR en "por ejecutar" — YA EXISTEN, están rotas

    f1135  4. POR EJECUTAR > 12. CONSTRUCCION PTAR > 1. PTAR FASE III (2025)  GB 1
    f1136                                          > 2. PTAR FASE IV  (2027)  GB 1
    f1137                                          > 3. PTAR FASE V   (2029)  GB 1

Las tres tienen `T = =Memorias!$C$18` y además **las tres apuntan al mismo año**
(C18 = 2024). Por su nombre deberían ser C19 (2025), C21 (2027) y C23 (2029).
Depende de arreglar la inflación del punto 1.

---

## 2. Excavaciones de andén — SÍ EXISTEN

| fila | etapa | cantidad | valor |
|---|---|---:|---:|
| f208 | ETAPA 03 | 675,37 M3 | 43.332.875 |
| f249 | ETAPA 04 | 2.032,57 M3 | 130.413.340 |
| f277 | ETAPA 05 | 6.570,78 M3 | 421.592.422 |
| f303 | ETAPA 08 | 3.352,63 M3 | 215.110.415 |
| f329 | ETAPA 09 | 489,10 M3 | 31.381.630 |
| | **total** | **13.120,46 M3** | **841.830.682** |

Actividad "EXCAVACION MECANICA, INCLUYE RETIRO EXTERNO A BOTADERO CERTIFICADO".
Contra LOCALIZACION Y REPLANTEO (= área de andén) la relación es **0,78 m** en las
cinco etapas: profundidad uniforme. Cubre las 5 etapas que tienen andén.

OJO: el V/U es **64.161,67/M3, idéntico al de EXCAVACION MANUAL PARA REDES**. Una
excavación mecánica cobrada al precio de una manual es sospechoso.

---

## 5. Pozos desagregados en sanitario

| actividad | cantidad | valor |
|---|---:|---:|
| CILINDRO POZO INSP. MAMPOSTERIA E=0.25M | 255,84 ML | 189.664.956 |
| PLACA CUBIERTA D=2.50M POZO INSPEC. | 73,10 UN | 124.598.295 |
| PLACA FONDO D=2.50M POZO INSPEC. | 73,10 UN | 63.278.072 |
| **total** | | **377.541.323** |

**No encontré ninguna fila de "pozo a todo costo" en sanitario.** El recorrido
completo de actividades de sanitario no tiene ningún ítem que englobe el pozo. Lo
más parecido son dos globales sin descripción:

    f581  SANITARIO PROTECCION "zz. GLOBAL INCLUIDO EN FORMULA" GL 1.000.000.000 ETAPA 08
    f606  SANITARIO PROTECCION "zz. GLOBAL INCLUIDO EN FORMULA" GL 1.000.000.000 ETAPA 09

Antes de borrar 377,5 M hay que saber cuál es el ítem que los reemplaza.

Dato adicional: las cantidades de pozo de SANITARIO y de PLUVIAL son casi
idénticas (255,84 vs 255,49 ML; 73,10 vs 73,00 UN; 73,10 vs 73,31 UN). Parecen
copiadas de una red a la otra.

### Defecto aparte en los globales
    f399 PLUVIAL ETAPA 03  1.000.000.000
    f420 PLUVIAL ETAPA 04      1.000.000   <-- tres ceros de menos?
    f441 PLUVIAL ETAPA 05  1.000.000.000

---

## 6. Sumideros contra IDU

Presupuesto actual: `SUMIDERO ALCANTARILLADO PLUVIAL EN VIA NS-047-1V4 EAAB`,
78,21 UN × **7.065.968,52** = 552.648.476.

IDU 2026-I (`presupuesto/referencia_idu/idu_apu_2026I.tsv`):

| código | ítem | valor |
|---|---|---:|
| 3151 | SL-100 H=1.25M fundido en sitio, premezclado | 3.325.537 |
| 3884 | SL-150 H=1.25M fundido en sitio, obra | 4.047.234 |
| 3712 | SL-100 H=0.85M **prefabricado** | 4.673.967 |
| 3885 | SL-200 H=1.25M fundido en sitio, premezclado | 5.074.178 |
| 3897 | SL-150 H=0.85M **prefabricado** | 6.186.409 |
| 3898 | SL-200 H=0.85M **prefabricado** | 7.360.452 |
| 3899 | SL-250 H=0.85M **prefabricado** | 8.485.894 |

El 7,07 M actual **no está fuera de rango**: cae entre el SL-150 y el SL-200
prefabricados. No se puede "corregir" sin saber qué tipo es el del proyecto. Si
fueran SL-100 prefabricados sobrarían ~2,4 M por unidad (187 M en total).

---

## 7. Cabezales que salen al bioswale

**No existen en el presupuesto.** La única fila con "CABEZAL" es:

    f1116  4. POR EJECUTAR > 7. TRONCAL Y CABEZAL MUÑA > CABEZAL DE DESCARGA
           GB  1  x  5.329.924.998   ETAPA GENERAL

Ese es el cabezal del Muña, no los del bioswale: hay que **crearlos**. El listado
IDU no sirve de referencia directa — sus ítems "cabezal" son vigas cabezal de
puente (M3 de concreto), no cabezales de descarga de alcantarillado.

---

## 8. Cómo salen las cantidades del bioswale — RESPUESTA

Sí, la base es exactamente el área que se raya en AutoCAD. El área rayada es una
polilínea cerrada con XDATA `URB_BIOSWALE`; al exportar, el plugin lee dos
magnitudes geométricas reales del objeto:

    area = área del polígono  (vla-get-Area)
    per  = perímetro          (vla-get-Length)

y aplica una receta de 9 actividades, cada una = factor × (AREA, PER o 1):

| Actividad | UM | base | factor | cantidad |
|---|---|---|---:|---|
| Excavación manual para bioswale/bioretenedor | M3 | AREA | 0,60 | área × 0,60 m |
| Cargue, transporte y disposición de sobrantes | M3 | AREA | 0,60 | área × 0,60 |
| Base de gravilla permeable para bioretenedor | M3 | AREA | 0,20 | área × 0,20 |
| Gravilla 25-40 mm (capa drenante) | M3 | AREA | 0,12 | área × 0,12 |
| Gravilla 10-15 mm (capa filtrante) | M3 | AREA | 0,15 | área × 0,15 |
| Relleno con material orgánico | M3 | AREA | 0,13 | área × 0,13 |
| Tubería perforada PVC 6" para drenaje | ML | PER | 0,50 | perímetro / 2 |
| Rejilla de drenaje para bioswale | UN | UN | 1,00 | 1 por bioswale |
| Jardinería | M2 | AREA | 1,00 | área × 1 |

O sea: **no se mide nada a mano**, todo son espesores multiplicados por el área
rayada. Las cuatro capas (0,20+0,12+0,15+0,13 = 0,60 m) llenan exactamente la
excavación de 0,60 m, así que el modelo cierra. La profundidad 0,60 m es editable
en Ajustes (se guarda como `URB_SEND_ESP_BIOSWALE` en el dibujo).

Único supuesto grueso: la tubería de drenaje se calcula como **medio perímetro**,
aproximación del dren longitudinal, no una medición del trazado real.

### Por qué en ESTE libro el bioswale sale en cero
En BD las únicas filas de bioswale son `PLANTAS PARA BIOSWALE` (M2, 100.000) y
`ARBUSTO PARA BIOSWALE` (UN, 150.000), ambas con **cantidad 0**. El plugin no
emite esos nombres: emite "Jardinería", "Excavación manual para
bioswale/bioretenedor", etc. Al no coincidir el nombre todo cae como huérfano —
de hecho `ALC-PLUVIAL / Jardinería 2.656,77 M2` ya venía saliendo huérfana en las
exportaciones del otro libro. Para vincularlo hay que igualar los nombres (o crear
las filas de la receta) y decidir si las 7 actividades de capas se presupuestan
por separado o se engloban.

---

## 4. Nivel azul = subetapas en indexación

Hoy `pivotTable1` usa como campos de fila NIVEL 1, NIVEL 2, NIVEL 3 y NIVEL 6. En
indexación NIVEL 6 trae el año ("INDEXACION POR EJECUTAR AÑO 2023") y la etapa va
aparte, en la columna ETAPA. Las 97 filas de indexación **ya están desagregadas
por etapa** (GENERAL + ETAPA 01..09) dentro de cada año.

Una misma dinámica no puede usar campos distintos por rama, así que cambiar el
campo afectaría también al capítulo 4. La vía limpia sin tocar el resto es
reescribir el texto de NIVEL 6 en esas 97 filas para que traiga la ETAPA y correr
el año a NIVEL 4/5 (hoy redundantes: repiten "1. INDEXACION POR EJECUTAR"). No
mueve un solo peso, solo reetiqueta.
