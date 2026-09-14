# Rampas, paso peatonal y zona verde vs presupuesto (2026-09-13)

Cruce de lo que EMITE el plugin (`urb:ppto-rows-rampas`,
`urb:ppto-rows-zonasverdes`) contra las filas de nivel 5 de cada capitulo,
y contra lo que la memoria REALMENTE emitio en el dwg actual.

LIMITE DEL METODO: el cruce es por nombre normalizado exacto. El plugin
empareja con un vocabulario difuso, asi que una fila puede estar
alimentada aunque aqui aparezca como huerfana. Senal fiable: si la fila
trae CANTIDAD > 0, esta alimentada (caso f136 "Bordillo prefabricado
A-80", cant=2, que la memoria emite como "Bordillo prefabricado").

## 2.2.4 RAMPA VEHICULAR -- 26 filas, 9 conceptos emitidos
Emite: compactacion de subrasante, descapote, excavacion mecanica,
subbase granular SBG, geotextil tejido 2100, M.O. instalacion de adoquin
y tabletas, recebo B-200, M.O. instalacion de loseta guia y toperol,
bolardo alto M-63.
NO FALTA NINGUNA fila: los 9 tienen destino.
17 filas quedan sin alimentar por el emisor de rampas. Es esperable en
parte -- la rama vehicular NO emite adoquin/losetas/arena/M.O. porque "el
acceso vehicular sin anden debajo trae su propio pavimento" y las piezas
las cobra el emisor de PREFABRICADOS. Pero todas estan hoy en CERO salvo
el bordillo (2 un), asi que conviene confirmar cuales deberian llenarse
solas y cuales son manuales de verdad:
  f131 A-105 remate, f133 A-86, f134 A-85, f135 A-100, f141 transporte de
  prefabricados, f150 M.O. A-105  -> MANUAL
  f132 A-10, f136 A-80, f137 adoquin, f138/139/140 losetas, f142 arena,
  f145 M.O. bordillo, f146 M.O. sardinel, f148 M.O. replanteo,
  f149 M.O. nivelacion  -> marcadas AUTOCAD y en cero

## 2.2.5 RAMPA PEATONAL -- 24 filas, 21 conceptos emitidos
NO FALTA NINGUNA fila. Es el capitulo mejor relacionado de los cuatro.
Sin alimentar (3): f164 sardinel alto A-86, f166 sardinel especial A-100
(el plugin solo emite el BAJO A-85) y f181 M.O. instalacion de sardinel
prefabricado.

## 2.2.6 PASO PEATONAL SEGURO -- 15 filas, 14 conceptos emitidos
NO FALTA NINGUNA fila.
Ojo con el ENRUTAMIENTO CRUZADO, que es correcto pero no obvio: este
capitulo no lleva losetas ni su M.O. -- el plugin las manda a ANDENES
(2.2.1) -- y el remate de rampa lo manda a RAMPA PEATONAL (2.2.5).
Sin alimentar (1): f206 "Relleno con material seleccionado B-200"
(AUTOCAD, en cero). El emisor produce "Suministro y colocacion de recebo":
revisar si es la misma actividad con otro nombre.

## 2.2.7 ZONA VERDE -- 4 filas, 4 conceptos emitidos  <<< EL HUECO REAL
FALTAN TRES de los cuatro conceptos:
  - Localizacion y replanteo
  - Relleno Manual Tierra Negra X 30CM
  - Coberturas Zonas Verdes
Esos tres los emite el plugin cuando la zona verde esta DENTRO DE UN
PARQUE (zona <> ""). Fuera de parque emite solo "Empradizacion y
conformacion", que si tiene fila. Conclusion: **las zonas verdes de
parque estan calculando tres actividades que no tienen donde caer.**

Ademas, dos filas del capitulo esperan movimiento de tierras que el
emisor de zona verde NO produce:
  f217 Excavacion mecanica en material comun (AUTOCAD, cero)
  f218 Suministro y colocacion de recebo B-200 (AUTOCAD, cero)
Y f215 "Suministro e instalacion de arbol" (MANUAL): la arborizacion no
se emite desde el dwg.

## Que hacer
1. Crear en 2.2.7 las tres filas que faltan (o renombrar las existentes
   para que el emparejador las alcance). Es el unico caso donde se pierde
   cantidad calculada.
2. Decidir si zona verde debe emitir corte/relleno: el bloque ya guarda
   CORTE_M3 y RELLENO_M3, solo no se emiten como filas.
3. Confirmar el nombre de f206 contra "Suministro y colocacion de recebo".
4. Las filas de sardinel A-86/A-100/A-10 y los remates A-105 son
   manuales por diseno; dejarlas asi o emitirlas si se modelan.
