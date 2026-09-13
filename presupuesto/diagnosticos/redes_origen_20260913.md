# Redes: unidades + auditoria de ORIGEN (2026-09-13)

## 1. Convencion suministro/instalacion
Confirmada por el usuario: suministro -> UN, instalacion -> ML.
Las filas alimentadas por AutoCAD YA cumplen: la relacion
instalacion(ML) / suministro(UN) da exactamente 6.00 (tubos de 6 m).
  f788 PVC presion O6"  116.08 UN  <-> f799  696.44 ML
  f789 PVC presion O8"  396.80 UN  <-> f800 2380.67 ML
No requieren cambio.

## 2. Defectos reales de unidad (todos en el bloque MANUAL/externo)
| fila | actividad | UM | cant | precio catalogo | cobra |
|---|---|---|---|---|---|
| 1185 | Instalacion de tuberia de alcantarillado en concreto | ML | 837.92 | f226 = $4.260 **por PULG** | $3.570.000 |
| 1190 | Transporte de tuberia en concreto | KG | 837.92 | f233 = $49/KG | $41.058 |
| 1247 | Descargue y acopio de tuberia | KG | 297.19 | f1263 = $64.161/KG | $19.070.000 |

- f1185 es el hallazgo caro: el precio del catalogo es la tarifa IDU por
  pulgada de diametro. Para DI 900 mm (~36") seria 4.260 x 36 = $153.360/ML
  -> 837.92 x 153.360 = ~$128.500.000. Hoy cobra $3,57 M.
  Subestimacion del orden de $125 millones. Requiere decision del APU.
- f1190: la cantidad 837.92 son los mismos METROS de f1185, etiquetados KG.
- f1247: 297.19 = 243.19 + 54 = los ML exactos de GRP 92" + GRP 48".

## 3. Suministro de tuberia en ML (deberia ser UN por la convencion)
f1175, f1177 (pipe jacking DI 900 / DI 30"), f1192, f1248 (GRP 92"),
f1249 (GRP 48"). El precio del catalogo TAMBIEN esta por ML, asi que
cambiar solo la unidad seria falsear. La conversion correcta es en pareja
(cantidad / L, precio x L) y es neutra en dinero, pero exige la longitud
de tubo de cada familia. PENDIENTE del dato.
f1040 "Suministro cable 3x185" se deja en ML: el cable si se vende por metro.

## 4. Auditoria de ORIGEN: no hay actividades del CAD marcadas MANUAL
- 147 especificaciones distintas emite la memoria; 145 tienen fila destino.
- 0 filas AUTOCAD quedarian sin alimentar (ninguna se pone en cero).
- Unicas filas no-AUTOCAD que la memoria alimenta:
  * 39 de parques (Base granular BG, Geotextil 2100/2400): NO es error, es
    colision de nombre. La misma actividad existe en vias (CAD) y en parques
    (ppto externo). Marcarlas AUTOCAD las destruiria en el refresco.
  * 5 de pozos (f940-944): marcadas MANUAL por mi al consolidar "a todo costo".
- 2 huerfanos: "Base de pozo de inspeccion" (83 UN) y
  "[SIN MATCH x3] Cabezal de descarga en concreto" (1 UN).
  El prefijo [SIN MATCH xN] lo pone el propio plugin al no clasificar.

## 5. El libro YA NO depende de la columna ORIGEN
Verificado en el codigo (urbanismo_cantidades.lsp, "PUENTE EXPORT -> HOJA
POR EJECUTAR", l.31146 y sig.): la palabra ORIGEN no aparece en el puente.
El plugin nunca lee ni escribe esa columna; es documentacion para humanos.
Lo que realmente protege una fila es:
  a) la huella del export anterior (urb:ppto-pe-old-rows): solo se tocan
     filas que ESE dwg alimento antes; una fila nunca exportada no se toca;
  b) HasFormula (l.31346): una fila cuyo rango F:AM lleva formula se salta
     con aviso y jamas se pisa.

CAVEAT IMPORTANTE de (b): Range.HasFormula devuelve True solo si TODAS las
celdas del rango son formula; si se mezclan formulas y valores duros Excel
devuelve Null, el codigo compara contra :vlax-true y la fila SI se pisa.
Para blindar una fila hay que poner formula en las 34 celdas F..AM
(=0 en las vacias), no solo en la que se edito.
