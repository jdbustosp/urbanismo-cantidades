# Qué está conectado con AutoCAD y qué no (2026-09-17)

Agente: Claude. Equipo: BOG085CD119BDQN.
Libro: `colsubsidio.com/.../260915_ACTUALIZACION GENERAL PPTO/urbanismo maipore.xlsx`
Lectura SIN abrir Excel (el .xlsx se leyó como zip/XML; el usuario lo tenía abierto).

## Cómo funciona el vínculo
- `POR EJECUTAR`: A=nivel (1..5), C=código por fórmula, D=actividad, E=subtotal,
  F..AM=cantidad por subetapa (aquí escribe el plugin), AN=SUM(F:AM),
  AO=SUMIF(PRECIOS_UNITARIOS por NOMBRE), AP=AN*AO.
- Subtotales (niveles 1..4) en **E**, con LET/XMATCH: buscan la siguiente fila de
  nivel <= al propio y suman AP de los nivel 5 de ese tramo. **Son automáticos**:
  una fila nueva insertada DENTRO del capítulo entra sola al subtotal.
- `URB_EQUIVALENCIAS` (93): clave del plugin -> nombre de actividad del libro.
- `URB_PARAMETRICAS` (6): familia|magnitud -> actividad + factor (los parámetros
  del usuario). Hoy: ANDEN TOPEROL_UND/GUIA_UND/TOPEROL_ML y ZONA_VERDE CORTE/RELLENO.
- `URB_AGG` (4.000): volcado del último export. Las claves con `[SIN MATCH xN]`
  son salidas del plugin que el libro no tiene.

## Medición
- Actividades nivel 5: **1.445**. Alimentadas desde AutoCAD: **160 (11%)**.
- Detalle fila por fila: `conexion_autocad_20260917.tsv` (fila, SI/NO, ruta de
  capítulos, actividad, UM).
- Huérfanas del plugin: `sin_match_20260917.txt` (6): Cabezal de descarga en
  concreto, Instalacion/Suministro tuberia PVC flexible 15, Jardineria,
  Suministro e instalación de banco de ductos PVC-TDP 6Ø6", Suministro sardinel
  alto A-86 para rampas.

### Por capítulo (conectadas / total)
| Capítulo N2 | conectadas | total |
|---|---:|---:|
| REDES HIDRAULICAS-SANITARIAS Y GAS | 131 | 201 |
| PERFILES VIALES (VIAS-ANDENES) | 103 | 175 |
| EQUIPAMIENTOS (PARQUES-SENDEROS-PUENTES) | 39 | 456 |
| REDES SECAS | 24 | 79 |
| TRONCAL Y CABEZAL MUÑA | 3 | 130 |
| PRELIMINARES | 0 | 34 |
| IMPREVISTOS | 0 | 34 |
| ACTIVIDADES Y OBRAS ADICIONALES | 0 | 35 |
| INDIRECTOS (PGU, CAR, PMT, vigilancia, interventoría, estudios) | 0 | 205 |
| INDEXACION | 0 | 51 |
| PTAR / HUMEDALES / ALMA CAFÉ / CASONA | 0 | 44 |

### Dentro de PERFILES VIALES (lo que falta conectar)
- ANDENES > Mobiliario: 0 de 11 (árbol, banca M-30, banca L=2,06, canecas M-121,
  protector de árbol M-91, contenedores de raíces A..F).
- SEÑALIZACIÓN Y DEMARCACIÓN: 0 de 43 (30 horizontal + 13 vertical).
- ZONA VERDE > Empradización/Arborización: 1 de 6.
- VÍA > Acabados y Drenaje, CICLORRUTA > Acabados: parcial.
- El resto de ANDENES/VÍA/RAMPAS/PASO PEATONAL está conectado (descapote,
  suministro, instalación, granulares, excavaciones y rellenos).

### Subestaciones (para el proyecto Serie 3 de ENEL)
`REDES SECAS > RED DE MEDIA TENSIÓN` ya tiene los rubros con precio y cantidad 0:
- MANIOBRA Y PROTECCIÓN: celda MT SF6 17,5 kV-630 A CTS508 $28.194.007; fusible
  limitador CTS507 $1.590.000; caja de maniobra pedestal 5 vías ET512 Fig.4
  $106.000.000; 3 vías Fig.1 $79.500.000; CDMT-7 $180.200.000.
- SUBESTACIONES Y TRANSFORMADORES: transformadores 30..630 kVA (45 kVA =
  $46.640.000) y "Base, foso de aceite, cerramiento y adecuación civil"
  $12.720.000.
