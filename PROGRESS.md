# Progress — urbanismo_cantidades.lsp

## Estado guardado — 2026-09-10 (2), v4.87.0 (Claude, BOG085CD119BDQN)

Agente: **Claude**. Equipo: **BOG085CD119BDQN**. Usuario local: `juanbusper`.

Cuarto y sexto punto del reporte, que resultaron ser el mismo cuello de botella:
el selector de cotas de la vía.

- **"Me está limitando mucho a seleccionar vía al principio y vía al final...
  ¿qué pasa si no tengo vía al final, o si no tengo ni al principio ni al
  final?"** El picker (`urb:pick-road-cotas-loop`) **siempre** aceptó cualquier
  fuente — vía creada (rasante interpolada en el clic), pozo/elemento del
  modelo, etiqueta con número, o valor digitado — pero lo decía mal: hablaba de
  *"la COTA del extremo INICIAL/FINAL de la vía"* y **exigía dos referencias**
  (`"Se necesitan al menos 2 cotas; seleccion cancelada"`). Sin una segunda no
  se podía continuar.
  Ahora:
  - los mensajes nombran las cuatro fuentes, sin decir "vía";
  - con **una sola** cota, se pide la **pendiente (%)** y con eso se arma la
    rasante;
  - con **ninguna**, se digitan cota inicial y pendiente.
  La rasante resultante usa los **mismos records** de siempre
  (`urb:cota-por-pendiente`, pura y autoprobada), así que el movimiento de
  tierras, la memoria y la exportación no cambian de camino.
- **"La vía que voy a hacer no tiene alineamiento ni cotas, pero tengo los de la
  vía de al lado."** Con lo anterior queda cubierto sin código nuevo: el modo de
  alineamiento **"Nuevo"** ya permite *dibujar* el eje
  (`urb:select-or-draw-road-axis`), y las cotas se toman clicando la **vía
  vecina** — `urb:cota-from-pick` interpola su rasante en el punto del clic. Lo
  que faltaba era poder hacerlo con una sola referencia, que es justo lo que se
  acaba de habilitar.

Validación: suite Core Console **84 OK / 0 FALLOS**, autopruebas **34/34**.
Instalado 4.87.0, hash repo = instalado.

**Pendiente del mismo mensaje, sin empezar**: el movimiento de tierras de
**andenes y zonas verdes** — debe dejar escoger vía/pozo como referencia, pero
cuando la referencia es una vía la cota **no** es su rasante sino **superior**
(el andén va por encima de la calzada). Hay que decidir de dónde sale ese
desnivel (altura de bordillo configurable en Ajustes es lo más probable) y
revisar con ese criterio el MT de la zona verde.


## Estado guardado — 2026-09-10, v4.86.0 (Claude, BOG085CD119BDQN)

Agente: **Claude**. Equipo: **BOG085CD119BDQN**. Usuario local: `juanbusper`.

Tres de los seis puntos del reporte del usuario. Los tres se reprodujeron en
Civil real antes de tocar nada.

1. ✔ **"Si edito una vía, cuando termino de editar me la borra del todo."**
   Causa encontrada y medida: `urb:explode-road-block-boundary` se apoyaba en
   *"el contorno es la ÚNICA LWPOLYLINE del bloque"* y se quedaba con **la
   última** que apareciera, borrando las demás. Ese supuesto ya no se cumple:
   medido, el bloque de vía trae **dos** polilíneas — el contorno (600,00 m²) y
   una de apoyo de área 0,00. Cuando la última era la de apoyo, el contorno real
   se borraba y la vía desaparecía. Ahora se elige por geometría
   (`urb:largest-closed-polyline`: la cerrada de mayor área, con respaldo al
   comportamiento anterior). Se aplicó la misma corrección al desempaque del
   **andén**, que tenía el mismo patrón.
2. ✔ **"Los andenes no están quedando en bloque, quedan todos los elementos por
   aparte."** No era un fallo del empaquetado: era su **coste**. Medido, un andén
   de 24 m con guía y toperol generaba **3.840 CIRCLE** (uno por domo) y
   `urb:package-anden` tardaba **15,2 s**; en un andén real de cientos de metros
   son minutos, y el bloque solo se arma si el usuario aguanta la espera — si
   interrumpe, el material queda suelto (modo de fallo ya documentado en el
   propio `urb:package-anden`). El punteado pasa a resolverse con el patrón
   `URB_TOPEROL.pat`, que este motor **ya escribía y nunca usaba**: un HATCH por
   banda en vez de un círculo por domo.
   Medido en el mismo caso: **334 objetos** (antes 4.454) y **1,2 s** de
   empaquetado, con 0 piezas sueltas.
3. ✔ **"Ya aparece la franja de toperol, pero quedó una franja gris; lo que
   quería era que quedaran los punticos."** El relleno gris uniforme de v4.83 se
   comía la textura. Ahora la franja va **clara** y los puntos **oscuros** — el
   punteado es la textura, no el fondo —, y al venir de un patrón se dibujan
   visibles a cualquier zoom. La **guía** conserva su tono por banda.
   `urb:count-toperol-symbols` (el control de calidad de v4.82, que solo contaba
   CIRCLE) ahora cuenta también el hatch del patrón; sin eso rechazaba un acabado
   que sí tenía su toperol.

Validación: suite Core Console **83 OK / 0 FALLOS**, autopruebas **33/33**.
E2E real con ActiveX **0 FALLOS**: andén empacado en 1,2 s con 0 sueltas, 14
hatches de punteo y 0 círculos, fondo claro; y el desempaque de vía conservando
el contorno de 600,00 m². Instalado 4.86.0, hash repo = instalado.

**Pendiente del mismo mensaje del usuario, sin empezar**: los tres puntos de
movimiento de tierras y alineamiento — (a) MT por pendiente obliga a vía al
principio Y al final, debería aceptar vía o pozo en cualquiera de los dos
extremos y varias cotas de pozos; (b) MT de andenes/zonas verdes debe dejar
escoger vía/pozo pero la cota **no** es la rasante de la vía sino superior;
(c) poder trazar una vía nueva que no tiene alineamiento ni cotas propias,
tomándolos de la vía vecina.

**Nota de herramientas**: escribir el `.lsp` con `Set-Content -Encoding UTF8`
(PowerShell 5.1) le mete **BOM** y lo pasa a CRLF. Hay que reescribirlo con
`UTF8Encoding($false)` y `\n`. Igual de importante: `[System.IO.File]` resuelve
rutas relativas contra el directorio del proceso, no contra el `Set-Location`
de PowerShell — usar siempre ruta absoluta (un descuido asi dejo en cero el
archivo del laboratorio).


## Estado guardado — 2026-09-08 noche (5), v4.85.0 (Claude, BOG085CD119BDQN)

Agente: **Claude**. Equipo: **BOG085CD119BDQN**. Usuario local: `juanbusper`.

El usuario confirmó lo que quedaba abierto en v4.84.0: **la rampa vehicular
también con aletas**.

- El desarrollo de rampa (`urb:ramp-end-objects`) ya no depende del tipo: lo
  llevan **los dos** — paso peatonal y acceso vehicular — siempre que el módulo
  dé la medida (`urb:ramp-ends-fit-p`). Si no da, se conserva el remate simple
  de v4.83.
- **Se avisa en la línea de comandos en los dos casos**: cuando entra el
  desarrollo (con las medidas de aleta y rampa) y cuando no entra (diciendo qué
  medidas hacen falta). Antes caía al remate simple en silencio, que es
  justamente cómo se acumularon los reportes de esta jornada.
- **Área**: con desarrollo, el criterio es el mismo para los dos tipos — cuerpo
  + las dos bandas centrales de rampa; las aletas se cobran por ML/UND, como en
  el módulo paramétrico. Sin desarrollo, el acceso vehicular conserva su área
  total de siempre. `BORDILLO_ML` del acceso vehicular ahora suma los bordillos
  del desarrollo (antes siempre "0").

Validación: suite **82 OK / 0 FALLOS**, autopruebas **32/32**. E2E real con
ActiveX **0 FALLOS**, con los tres casos:

| caso | resultado |
|---|---|
| paso peatonal 6 × 3 m | `AREA_M2 13,680` · `A81_UND 4` · `TOPEROL_ML 5,200` · `BORDILLO_ML 16,000` · 4 diagonales · 400 domos · 12 bordillos |
| acceso vehicular 6 × 4 m | `AREA_M2 19,280` · `A81_UND 4` · `TOPEROL_ML 5,200` · `BORDILLO_ML 12,000` · 4 diagonales · 400 domos · 12 bordillos |
| acceso vehicular 3,0 × 2,5 m | sin desarrollo: `AREA_M2 7,500` (área total de siempre) · `A81_UND 0` · remate simple |

Instalado 4.85.0, hash repo = instalado.

**Aprendizaje del caso corto** (falso fallo del primer intento, no del motor):
las tapas se eligen sobre el **eje largo**, así que un módulo de 2,5 × 4 m tiene
4,00 m de largo y **sí** admite los dos desarrollos — el "corto" de verdad es el
que tiene su lado LARGO por debajo de 3,50 m. El umbral deja como mínimo 0,50 m
de cuerpo entre los dos desarrollos.


## Estado guardado — 2026-09-08 noche (4), v4.84.0 (Claude, BOG085CD119BDQN)

Agente: **Claude**. Equipo: **BOG085CD119BDQN**. Usuario local: `juanbusper`.

El usuario confirmó el supuesto que quedó abierto en v4.83.0: en los extremos
del paso peatonal quiere el **desarrollo completo de la rampa con las aletas
laterales**, no solo la cuña A81.

- **`urb:ramp-end-objects`** (nueva): dibuja en cada extremo el módulo real de
  U-201, con las medidas del módulo paramétrico que el usuario ya da por bueno:
  - **aleta lateral de 0,60 m a cada lado** = toperol 0,20 (gris con domos
    blancos) + bordillo 0,10 + prefabricado **A81 0,30 con su diagonal**,
    espejada como en el paramétrico;
  - **banda central de rampa** entre las dos aletas, con la textura del material
    del paso (adoquín o concreto);
  - **bordillo transversal de 0,20** que cierra el desarrollo contra el cuerpo.
  Constantes: `*urb-rampa-aleta*` 0,60 · `*urb-rampa-desarrollo*` 1,30 ·
  `*urb-rampa-cierre*` 0,20.
- **`urb:ramp-ends-fit-p`** decide si el paso da la medida — la condición
  *"cuando son tramos largos"*: tapa ≥ 1,70 m (dos aletas + 0,50 de banda) y
  ≥ 3,50 m entre los **puntos medios** de las dos tapas. Se mide por punto medio
  (`urb:ramp-frame-mid`) y no por los vértices de arranque, que son esquinas
  opuestas y en un paso corto y ancho darían una diagonal engañosamente larga —
  con lo que el desarrollo se habría comido todo el cuerpo y el comando habría
  abortado con "los remates cubren todo el módulo".
- Si no da la medida (o en el acceso vehicular) se conserva la cuña simple de
  v4.83: rectángulo con diagonal.
- **Cantidades**: `A81_UND` = 4 (2 aletas × 2 extremos), `TOPEROL_ML` y
  `BORDILLO_ML` suman lo del desarrollo, y `AREA_M2` = cuerpo **más** las dos
  bandas centrales de rampa — mismo criterio del módulo paramétrico, donde las
  aletas se cobran por ML/UND y no por área.

Validación: suite Core Console **82 OK / 0 FALLOS**, autopruebas **32/32**.
E2E real con ActiveX **0 FALLOS** sobre un paso de 6 × 3 m girado 30°:
`AREA_M2 13,680` (= 9,00 del cuerpo + 2 × 1,80 × 1,30 de rampa),
`A81_UND 4`, `TOPEROL_ML 5,200`, `BORDILLO_ML 16,000`; en el bloque, 4
diagonales, 400 domos en 8 piezas de toperol y 12 objetos de bordillo.
Instalado 4.84.0, hash repo = instalado.

**Nota**: el desarrollo con aletas se aplicó al **paso peatonal**, que es lo que
el usuario señaló en la foto 4. El **acceso vehicular** conserva su remate de
0,60 m con diagonal (ya visible desde v4.83). Si también debe llevar aletas, es
un cambio análogo y está aislado en `urb:ramp-end-objects`.


## Estado guardado — 2026-09-08 noche (3), v4.83.0 (Claude, BOG085CD119BDQN)

Agente: **Claude**. Equipo: **BOG085CD119BDQN**. Usuario local: `juanbusper`.

Cuatro observaciones del usuario sobre la sesión de prueba (fotos 1–4).
Confirma que **el paso peatonal por tres puntos ya quedó bien**.

1. ✔ **"Lo del toperol sigue sin aparecer."** Se reprodujo en Civil real
   (andén recto de 24 × 2,4 m rotado 30°, guía y toperol en Sí) y **el toperol
   sí se generaba**: 3.840 domos, todos dentro del contorno y todos dentro del
   bloque empaquetado. Lo que fallaba era que **no se ve**:
   - la franja táctil se pintaba con la **misma alternancia gris/blanca del
     andén** — decisión antigua documentada en el propio código: *"la franja
     queda integrada al patrón y se distingue solo por la textura"* — así que a
     escala de plano es idéntica al resto del andén;
   - la textura que debía distinguirla eran domos de **radio 0,008 m** (16 mm de
     diámetro): a la escala a la que el usuario mira el plano no llegan a un
     píxel.

   Corrección: helpers puros `urb:tactile-fill-color` / `urb:tactile-symbol-color`.
   El **TOPEROL** pasa a tono propio uniforme (gris 8) con los domos en blanco —
   el mismo criterio del módulo paramétrico U-201, que el usuario ya da por
   bueno —, y el domo toma su tamaño real: `*urb-toperol-radio*` = 0,0125 m
   (25 mm). La **GUÍA** conserva su alternancia gris/blanca, que así se aprobó.
   Se corrigieron los dos caminos (offset y segmentado) y el módulo de rampa.
2. ✔ **"No entiendo por qué me pide remates transversales"** (modo *Dibujar
   contorno* de RAMPA). Los remates son las dos **tapas** del contorno, y el
   motor ya sabía encontrarlas: `urb:ramp-auto-frames` reutiliza
   `urb:costado-tip-segments` (el mismo criterio de los costados del andén)
   sobre el eje largo. El comando ya **no pregunta**; informa los anchos
   detectados y solo pregunta si el contorno no permite decidirlo.
   Se separó `urb:ramp-frame-at` (por índice de segmento) de
   `urb:ramp-end-frame` (por punto marcado), que queda como respaldo.
3. ✔ **"De la rampa vehicular no se ve el dibujo de la rampa"** (foto 3): el
   remate se rellenaba en **blanco** sobre un cuerpo también claro, así que el
   módulo quedaba como un polígono liso. Ahora el remate va en gris, el tono con
   el que el usuario ya lee las piezas inclinadas.
4. ✔ **"En los extremos del paso peatonal, cuando son tramos largos, que
   aparezca esa parte de la rampa"** (foto 4, señalado en rojo). Se dibuja en
   cada extremo la misma pieza del módulo paramétrico U-201: un **rectángulo con
   DIAGONAL** (la cuña inclinada). En el paso peatonal es la pieza A81 de 0,30 m
   y solo se pone si el tramo es largo (**≥ 2,00 m entre remates**, la condición
   que puso el usuario); queda contada en `A81_UND`. En el acceso vehicular el
   rectángulo es el propio remate de 0,60 m.

Validación:

- Suite completa (Core Console 2023, `verify.lsp`): **81 OK / 0 FALLOS**.
  Autopruebas del motor **31/31** (2 nuevas sobre los tonos táctiles y el radio).
- E2E real con ActiveX (AutoCAD 2023 + perfil C3D), **0 FALLOS**:
  - toperol: 3.840 domos de radio 0,0125, todos blancos, sobre 55 piezas de
    relleno **todas grises** (0 blancas) + la retícula de junta en color 9;
  - guía: conserva 29 grises / 29 blancas;
  - remates detectados solos en un paso de 6 × 3 m: **3,00 y 3,00 m** (las
    tapas, no los lados de 6 m);
  - paso peatonal por contorno: `A81_UND = 2`, con sus 2 diagonales dibujadas;
  - acceso vehicular: 2 diagonales y remates en gris.
- Instalado 4.83.0; hash del repo = hash del bundle instalado. La DLL de la
  cinta no se pudo reemplazar porque Civil 3D estaba abierto — no se tocó en
  esta entrega, así que no hace falta.

**Supuesto que conviene confirmar con el usuario**: la "parte de la rampa" de la
foto 4 se interpretó como la pieza A81 (rectángulo con diagonal) del módulo
paramétrico. Si lo que quería era el desarrollo completo de rampa (aletas
laterales con su superficie), es un cambio mayor y hay que precisarlo.


## 2026-09-08 21:37 — v4.82.0 — Codex / BOG085CD119BDQN

Agente: Codex. Equipo: BOG085CD119BDQN. Commit: entrega v4.82.0.
Paso peatonal y acceso vehicular: eliminada seleccion obligatoria de contorno.
RAMPA ofrece Tres (inicio, eje/ancho, sentido/fondo) o Dibujar (PLINE con
arcos y cierre, luego dos remates). Fuente temporal consumida al completar;
no se borra ninguna geometria preexistente. UNDO agrupa creacion completa;
PLINEWID se restaura, puntos WCS, rechaza eje/fondo nulos.

Toperol NO diagnosticado definitivamente: ahora se cuentan circulos reales
generados de capa TOPEROL antes de empaquetar; con opcion Si y cero domos
se rechaza acabado y se muestra mensaje, no se acepta exito parcial de guia.
No afirmar que este control repara el caso de la foto.

Pruebas finales: Core2023 79 OK/0 FALLOS. Incluye geometria pura de tres
puntos y 240 circulos DXF; interfaz y constructor real de rampas pendientes.
Ensayo Civil3D propio PID38700: 480 circulos antes y 480 despues de empaquetar
en anden recto rotado6x2 sin contenedor. LOAD del candidato fallo por un
parentesis en helper RAMPA, corregido antes de prueba final. Las funciones
del anden habian cargado; resultado util solo para ese subsistema/fixture,
NO para certificar entrega completa. Se cerro PID propio al tope90s.

Lectura de copia del DWG guardado: dos andenes, 4597 y 3652 circulos TOPEROL
dentro de bloques; opcion Si. Archivo fuente real:
260915_ACTUALIZACION GENERAL PPTO/Memorias/URB_MASTER_GENERAL.dwg,
fecha 2026-09-08 20:31:06, 32217766 bytes. No representa necesariamente la
captura reciente. COM de sesion activa no proporciono acceso util; no hubo
escritura ni control de pantalla. Para cerrar toperol: guardar DWG actual
y revisar bloque concreto + mensaje TOPEROL:n domos. No volver a parchar
causas supuestas ni afirmar resuelto por pruebas sinteticas.

## 2026-09-08 21:17 — v4.81.0 — Codex / BOG085CD119BDQN

Agente: Codex. Equipo: BOG085CD119BDQN. Commit: entrega v4.81.0.
Usuario confirma mejora del recorte; quedan toperol invisible, ultima banda
corrida y geometria diferenciada de pasos/accesos segun cuatro imagenes.

- Corregida fase blanca: con desplazamiento 1.0m faltan 0.8m, no 1.6m.
  Franjas tactiles rectas recortadas heredan fase desde el inicio del anden,
  no reinician el patron en el extremo de cada region resultante.
- El fallo de simbolos deja aviso con causa, no devuelve exito silencioso.
  NO se afirma solucion del toperol de la foto: el generador puro pasa,
  pero falta reproducir recorte/orden de dibujo del bloque real.
- RAMPA diferencia flujo: peatonal conserva inicio/fin/fondo; paso peatonal
  y vehicular usan polilinea cerrada existente + dos remates elegidos.
  Conserva arcos y longitud libre, original y cota. Paso: adoquin o concreto,
  confinamientos 0.20m; vehicular: liso, remates 0.60m con diagonales.
  Son valores de representacion declarados en prompt, no dimensiones de
  diseno inferidas de fotos. No genera pendientes/solidos 3D ni recorta
  automaticamente vecinos. Tipos mantienen sus capitulos separados.
  Cantidades area neta medida; A81/toperol=0 en nuevos modulos; borde solo
  remates de paso. FONDO_M=0 indica geometria libre, no fondo rectangular.

Pruebas: lote final Core Console 76 OK/0, carga RAMPA/ANDEN y 240 circulos
DXF en franja 3x0.2m (region adaptada, NO ActiveX). Primeros lotes detectaron
parentesis en harness y constructor; corregidos antes del lote final.
Civil 3D: unico intento Hidden PID24984, 90s; harness mal formado y carga
fallida antes de correccion. Su FALLO parcial no es evidencia geometrica;
harness corregido pero NO reejecutado. Pendiente validacion visual/E2E.
Sin modificacion de DWG/Excel originales ni control de pantalla.

## 2026-09-08 20:50 — v4.80.0 — Codex / BOG085CD119BDQN

Agente: Codex. Equipo: BOG085CD119BDQN. Commit: ver entrega v4.80.0.
Distorsion tactil y contenedor que no recorta acabado/prefabricado:

- Simbolos usan bucles encadenados de REGION y paridad para huecos; ya no
  tratan las aristas desordenadas de Explode como un poligono ni aceptan
  la envolvente rectangular como superficie valida.
- Cerca de contenedores, guia/toperol conservan eje recto y se recortan con
  la region neta; no siguen el entrante. Huellas se llevan a la cota de la
  region antes de Boolean. Deteccion de anden existente usa geometria WCS.
- Insertar contenedor corta referencias rectas de prefabricados existentes,
  conserva metadatos/enlaces y solo elimina el original al crear sustitutos.
  Una cadena completamente tapada no vuelve a dibujarse por fallback.
- No descartar islas cuando el recorte produce varios bucles.

Verificado: regresion Core Console 71 OK/0; focal contra motor instalado
10 OK/0 (18.2 s), incluidos ANDEN registrado y costado 6-2.2=3.8m en dos
partes. SHA256 repo=instalado:
637274EEBA3A7D5AE0F128631FF11B1420119A33A989AEEAABA373C87019C76F.
Civil 3D 2023 real: un intento Hidden, PID 9712, cerrado a 90.5 s sin resultado.
No afirmar validacion geometrica ActiveX ni visual. Harness reproducible en
diagnosticos/anden4800; originales DWG/Excel no modificados.

Limites: prefabricados curvos se conservan con aviso; el recorte de prefab
recto exige que la huella intercepte su referencia (no resuelve intrusion
parcial que solo toque su ancho). Bloques viejos no se reparan al instalar:
probar recreacion/edicion tras reiniciar Civil 3D. Verificacion visual pendiente.
Protocolo agil reforzado en TESTING_CIVIL3D.md por peticion del usuario.

## Corrección inmediata — 2026-09-08 20:20, v4.79.1 (Codex, BOG085CD119BDQN)

Agente: **Codex**. Equipo: **BOG085CD119BDQN**. Usuario local: `juanbusper`.
Commit funcional: `04f7f95`.

El usuario abrió Civil 3D 2023 e informó `Unknown command "ANDEN"`. No era un
fallo de modelación: la entrega 4.79.0 iniciaba la lectura del LSP pero se
detenía antes de registrar los comandos. Hubo dos causas corregidas:

- En el mensaje de estado agregado al final de 4.79.0 quedó un `if` con dos
  expresiones de alternativa sin `progn`, error de sintaxis de AutoLISP. La
  E2E geométrica había terminado antes de ese último ajuste textual; desde
  ahora la carga final se repite después de cualquier edición posterior.
- `acaddoc.lsp` dependía exclusivamente de `S::STARTUP`. Si el arranque de otro
  complemento fallaba primero, Urbanismo no se alcanzaba a cargar. El instalador
  ejecuta ahora `urbcant:bootstrap` inmediatamente al leer `acaddoc.lsp` y deja
  `S::STARTUP` como respaldo; además protege el startup previo con
  `vl-catch-all-apply`.

Verificación corta y específica, en segundo plano:

- Inicio limpio con instalación 4.79.1: `ANDEN=SI`, `URBANISMO=SI`, ambos
  `TYPE=SUBR`, `VERSION=4.79.1`, `DONE`.
- Regresión Core Console 2023: **71 OK / 0 FALLOS**.
- Motor instalado y repositorio con SHA-256 idéntico. No se modificó el DWG.

La corrección geométrica de costados y recorte posterior de 4.79.0 permanece
en 4.79.1. El usuario debe abrir/reiniciar Civil 3D una vez para cargar el nuevo
`acaddoc.lsp`; no necesita reinstalar manualmente.

## Estado guardado — 2026-09-08 20:00, v4.79.0 (Codex, BOG085CD119BDQN)

Agente: **Codex**. Equipo: **BOG085CD119BDQN**. Usuario local: `juanbusper`.
Commit funcional: `d42e788`.

Atendidas las dos precisiones nuevas del usuario sobre andenes y contenedores
de raíces:

- **Costados longitudinales estables.** `urb:poly-costado-chains` ya no toma
  el eje de la familia de aristas con mayor longitud acumulada. Un entrante
  profundo agrega dos caras transversales y podía hacer ganar al eje corto,
  por lo que los bordillos/sardineles recorrían las puntas del andén. Ahora
  usa `urb:anden-axis-angle`, basado en la envolvente orientada: el entrante
  no voltea el eje y los prefabricados quedan en los dos lados longitudinales,
  interrumpidos en la huella del contenedor por la lógica de v4.77.
- **Contenedor posterior al andén.** Después de insertar un elemento `CONTEN`,
  `urb:recut-andenes-for-container` filtra por caja y solape poligonal real,
  reconstruye únicamente los andenes afectados y solo elimina el bloque
  anterior cuando el nuevo quedó completo. Conserva `URB_Q_SCOPE` y vuelve a
  enlazar los prefabricados automáticos. Si había movimiento de tierras válido,
  no lo copia porque el área cambió: queda pendiente de recalcular mediante
  `EDITAR`, evitando exportar volúmenes obsoletos.
- `urb:rebuild-working-boundary` ejecuta ahora el recorte físico antes de
  regenerar el acabado. Un contenedor completamente interior se omite del
  acabado aunque una polilínea simple no pueda representar el hueco interior.

Verificación en segundo plano, sin tocar DWG/Excel del usuario:

- Caso focal que hacía fallar la versión anterior: eje por aristas = 90°;
  eje nuevo = 0°; cadenas longitudinales **7,0 m y 14,6 m**, correctas.
- Regresión Core Console 2023: **71 OK / 0 FALLOS**.
- E2E con AutoCAD 2023 y perfil Civil 3D: **0 FALLOS**. El flujo andén primero
  → contenedor después sustituyó exactamente **1** andén, área **40,000 →
  37,360 m²**, conservó `URB_Q_SCOPE` y retiró `URB_ANDEN_MOV` obsoleto. El
  harness escribió `DONE`; Civil no cerró por sí solo dentro de 180 s y el
  lanzador terminó únicamente el PID de prueba, sin repetir la corrida.

Instalado en el bundle local: motor **4.79.0**, manifiesto **4.79.0** y SHA-256
del LSP instalado idéntico al repositorio. Para verlo en la sesión del usuario:
reiniciar Civil 3D y probar tanto un andén nuevo con entrante como un contenedor
añadido sobre un andén existente. El segundo caso ya no obliga a recrear el
andén manualmente.

## Estado guardado — 2026-09-08 noche (2), v4.78.0 (Claude, BOG085CD119BDQN)

Agente: **Claude**. Equipo: **BOG085CD119BDQN**. Usuario local: `juanbusper`.
Commit: ver `git log` (mensaje `v4.78.0: el contorno del anden se recorta...`).

Foto nueva del andén recién modelado + petición literal del usuario: *"solo el
bloque del andén tiene que estar entre los prefabricados"*. Es la tercera vez
que lo pide, y hasta v4.77 se había atendido **a medias**: se recortaba el
ACABADO (losetas, juntas, táctiles) y el ÁREA, pero **la polilínea del contorno
seguía pasando por debajo del bordillo y del contenedor**. Por eso al
seleccionar el bloque sus límites no coincidían con lo dibujado.

- **`urb:anden-clip-contour`** (nueva): sustituye la propia polilínea del
  contorno por el borde de la región ya recortada (contorno − prefabricados −
  contenedores). Se ejecuta en `urb:create-sidewalk-command` **entre los
  costados y el acabado**, así que el acabado, el área y el perímetro se
  calculan ya sobre el contorno neto. Usa `entmod`, no `entmake`, para
  **conservar el HANDLE** — de él cuelgan la xdata del andén, las piezas
  generadas y el vínculo con los costados.
- Piezas puras nuevas y autoprobadas: `urb:curve-as-segment` (recta/arco
  explotado → `(p1 p2 bulge)`, con `bulge = tan(Δ/4)` calculado como
  `sin/cos` porque AutoLISP no tiene `tan`), `urb:chain-take-next`,
  `urb:chain-loops-from-segments` (reencadena los trozos sueltos de
  `vla-Explode` en bucles cerrados, en cualquier sentido),
  `urb:loop-signed-area`, `urb:loop-reverse` (al invertir, el bulge cambia de
  signo **y** se corre un vértice) y `urb:region-loops`.
- **Degradación segura**: si la región no se puede construir, si aparece una
  curva que no sabemos volcar a polilínea (elipse, spline) o si el `entmod`
  falla, el contorno queda **intacto** y sigue funcionando el recorte del
  acabado de v4.76. Si no hay nada que recortar tampoco toca nada.
- Efecto colateral esperado: `AREA_BRUTA_M2` ahora coincide con `AREA_M2`
  porque el contorno ya es el neto. La marca `AREA_NETA=Si` sigue evitando el
  doble descuento en `urb:ppto-rows-andenes`.

Verificación:

- Suite completa (Core Console, `verify.lsp` del protocolo de Codex):
  **71 OK / 0 FALLOS**. Autopruebas del motor **29/29** (3 nuevas: reencadenado
  de un bucle, elección del bucle mayor, inversión sin voltear el arco).
- E2E real con ActiveX (AutoCAD 2023 + perfil C3D), **0 FALLOS**:
  - Parte 1 (contenedor + bordillos externos): contorno 38,500 → **37,360 m²**
    tras el recorte, cerrado (flag 70 = 1); prefabricados 7,8 / 10,0 / 20,0 m,
    ninguno dentro de la huella del contenedor; `AREA_M2 37,360 |
    AREA_BRUTA_M2 37,360 | AREA_NETA Si`.
  - Parte 2 (bordillos **internos** de 0,20 m en los dos lados): contorno
    20 × 2 m = 40 m² → **32,000 m²** exactos = 20 × 1,60, y el bloque
    empaquetado reporta ese mismo 32,000. Es la comprobación literal de
    *"el andén queda entre los prefabricados"*.
- Instalado 4.78.0; hash del repo = hash del bundle instalado.

**Pendiente del mismo mensaje**: el usuario dice que el andén *"salió mal"* y
adjunta la foto. Además del contorno (ya resuelto arriba) se ve una **zona
moteada en el vértice inferior derecho**, con textura mucho más fina que la
retícula de loseta del resto y que parece desbordar el contorno. No se pudo
reproducir sin el DWG: hace falta el contorno real (un WBLOCK de ese andén
basta) para montarlo en el laboratorio. Sospechas ordenadas: (a) partición en
dos ejes `urb:two-axis-split-data` sobre un contorno irregular, que da a esa
punta un eje propio; (b) franja táctil (toperol) que en vez de una banda de
40 cm cubre la punta.


## Estado guardado — 2026-09-08 noche, v4.77.1 (Claude, BOG085CD119BDQN)

Agente: **Claude**. Equipo: **BOG085CD119BDQN**. Usuario local: `juanbusper`.

Tres observaciones del usuario sobre el andén recién dibujado:

1. **Área del andén incluía los prefabricados** (properties: contorno 17,514 vs
   `AREA_M2` 19,71). Ahora `urb:package-anden` guarda en `AREA_M2` el **área
   NETA** — la región del contorno después de restar prefabricados y
   contenedores (`urb:anden-area-neta`, medida sobre la región real) —, deja el
   contorno en `AREA_BRUTA_M2` y marca el bloque con `AREA_NETA=Si`. El
   colector `urb:ppto-rows-andenes` **salta sus tres descuentos** (contenedores,
   anillos internos y prefabricados solapados) cuando ve esa marca, para no
   descontar dos veces; los bloques anteriores no la traen y siguen por el
   camino de siempre. Medido E2E: `AREA_M2 37,360 | AREA_BRUTA_M2 38,500 |
   AREA_NETA Si`, con el contenedor quitando exactamente 1,140 m².
2. **Botón "Sendero" seguía en la cinta**: el código C# ya no lo tenía desde
   v4.72.2, pero Civil 3D 2023 cargaba `UrbCantRibbon2023_v4700.dll`, compilada
   antes de esa limpieza (la de 2025 sí se había recompilado). Se recompiló como
   `UrbCantRibbon2023_v4770.dll` (nombre nuevo: la DLL vieja queda bloqueada
   mientras Civil 3D corre) y `PackageContents.xml` apunta a ella.
3. **Prefabricados mal dibujados** (imagen 1 vs imagen 2): pendiente de
   reproducir — ver nota abajo.

Suite **68 OK / 0 fallos**; instalado 4.77.1, hash repo = instalado.

## Estado guardado — 2026-09-08 tarde, v4.77.0 (Claude, BOG085CD119BDQN)

Agente: **Claude**. Equipo: **BOG085CD119BDQN**. Usuario local: `juanbusper`.

Segunda foto del usuario sobre el mismo andén: ya no salía la pieza suelta de
v4.76.1, pero el costado **seguía el entrante y envolvía el contenedor** (marco
de prefabricado alrededor de la caja). Regla del usuario: *"alrededor del
contenedor de raíces no va ningún prefabricado"*.

- **`urb:chain-split-por-poligonos`** (pura): parte la cadena de un costado y
  quita los tramos cubiertos por un contenedor, cortando el segmento justo en
  el borde de su huella. Sirve igual si el usuario dibujó el entrante (la
  cadena entra al hueco) que si dibujó el contorno derecho (la cadena pasa por
  encima del contenedor). Los segmentos en arco no se cortan.
- **`urb:point-near-poly-p`**: el test de interior con tolerancia (2 cm) es lo
  que hace que también se recorte el tramo que corre TANGENTE a la cara del
  contenedor — sin él, el punto medio cae exactamente sobre la arista y el
  ray-casting lo da por afuera (medido: sobraban 0,7 m de bordillo pegados a
  la caja).
- **`urb:contenedor-corners` / `urb:contenedor-polys`**: huella real en mundo
  del contenedor desde su bloque (punto de inserción + rotación + ancho/largo
  del catálogo + lado guardado en `URB_MOBILIARIO`). Sin xdata o sin catálogo
  el contenedor no recorta: se conserva el comportamiento anterior.
- **`urb:poly-costado-build`** ahora construye **un bloque por tramo útil** y
  devuelve `(longitud-total lista-de-referencias)`; los dos llamados en
  `urb:poly-costados-build` acumulan las referencias con `append`.
- **Medido E2E con ActiveX real** (mismo caso: rectángulo 20×2, entrante
  1,5×1,0, contenedor CONT-C de 2,20 m sobre el borde): el costado de ese lado
  pasa de **una pieza de 22,0 m que envolvía la caja** a **10,0 m + 7,8 m**
  (faltan justo los 2,2 m que ocupa el contenedor); el lado limpio sigue en
  20,0 m; ningún prefabricado queda dentro de la huella. 0 fallos.
- **Suite**: 68 OK / 0 fallos, con dos regresiones nuevas ("El costado se
  interrumpe en el contenedor", "Sin contenedores el costado queda entero").
  Instalado 4.77.0; hash repo = instalado.
- Sigue pendiente de decisión (sin tocar) lo reportado en v4.76.1: `AREA_M2`
  guarda el área cruda del contorno y el excedente que el contenedor invade
  fuera del entrante (~1,14 m²) no se descuenta al presupuesto aunque sí se
  excluye del dibujo.

## Estado guardado — 2026-09-08 15:4x, v4.76.1 (Claude, BOG085CD119BDQN)

Agente: **Claude**. Equipo: **BOG085CD119BDQN**. Usuario local: `juanbusper`.

- **Causa raíz del reporte con foto** (prefabricados sueltos junto al contenedor
  de raíces y andén que se extendía más allá de lo debido): al dibujar el
  contorno con un ENTRANTE para rodear el contenedor,
  `urb:poly-costado-chains` elegía las "puntas" del andén por **longitud**
  (los 2 segmentos más cortos no adyacentes). Las dos aristas del entrante
  (1,0 m) son más cortas que las puntas reales (2,0 m de ancho), así que el
  contorno se partía en una cadena basura —el fondo del entrante, 1,5 m, que
  salía como prefabricado suelto— y otra de 42,5 m que mezclaba los dos
  costados, las dos puntas y el zigzag del entrante.
- **Corrección**: las puntas se eligen ahora por **posición sobre el eje
  dominante** (`urb:anden-straight-edges-angle`): son los segmentos cuyo punto
  medio cae en los extremos del eje largo; un entrante siempre queda en el
  medio. Sin eje dominante (contorno todo en arcos) se conserva la heurística
  anterior como respaldo. La lógica se extrajo a `urb:costado-tip-segments`,
  función pura y probable sin crear entidades.
- **Medido antes/después** en el mismo caso (rectángulo 20×2 con entrante de
  1,5×1,0 y contenedor CONT-C): antes cadenas de 1,5 m y 42,5 m; después
  22,0 m (lado con entrante, recorriendo el hueco) y 20,0 m (lado limpio).
- **E2E con ActiveX real** (AutoCAD 2023 + perfil C3D, DWG de prueba propio):
  2 prefabricados —uno por costado, sin pieza suelta—, `build-anden-finish` y
  `package-anden` OK, y el recorte físico de v4.76.0 confirmado por primera vez
  con geometría real: la región del acabado baja de **38,500 a 37,360 m²**,
  descontando exactamente los 1,140 m² del contenedor. 0 fallos.
- **Suite**: 66 OK / 0 fallos (Core Console 2023), incluida la regresión nueva
  "Puntas del andén se eligen por extremo, no por longitud". Instalado 4.76.1;
  hash repo = instalado.
- **Pendiente reportado, no tocado**: el atributo `AREA_M2` del andén guarda el
  área cruda del contorno (38,50) mientras lo dibujado es 37,36; el descuento
  al presupuesto lo hace `urb:anden-area-contenedores`, que desde v4.76.0 exige
  que el punto de inserción del contenedor caiga DENTRO del polígono. Con
  entrante ese punto queda sobre el borde, así que el excedente que el
  contenedor invade fuera del entrante (~1,14 m²) no se descuenta en el
  presupuesto aunque sí se excluye del dibujo. Decisión del usuario/Codex.
- Validación visual en Civil 3D pendiente del usuario: **los andenes ya creados
  conservan su geometría empacada y deben recrearse** para tomar el arreglo.

## Estado guardado — 2026-09-08 14:35, v4.76.0 (Codex, BOG085CD119BDQN)

Agente: **Codex**. Equipo: **BOG085CD119BDQN**. Usuario local:
`juanbusper`. Commit funcional: `29d3b66`.

- El acabado del andén ahora resta físicamente las huellas de bordillos,
  sardineles, cañuelas y contenedores de raíces antes de crear rellenos,
  juntas, guía o toperol; ya no depende solo de `DRAWORDER`.
- Un entrante junto a un contenedor se interpreta como vacío y no como un
  segundo brazo del andén: el patrón conserva un solo eje y no intenta rodearlo.
- El diálogo indica dibujar el contorno exterior sin rodear contenedores; estos
  se omiten automáticamente. Se evita además el doble descuento de cantidades
  cuando el usuario ya dibujó un entrante alrededor del contenedor.
- Verificación: **65 OK / 0 fallos**, Core Console 2023, 40,21 s. Instalado
  4.76.0; hash repo=instalado. Validación visual pendiente del usuario en Civil
  3D; los andenes antiguos deben recrearse para regenerar su geometría interna.

## Protocolo ágil de validación — 2026-09-08 14:11 (Codex, BOG085CD119BDQN)

Agente: **Codex**. Equipo: **BOG085CD119BDQN**. Usuario local:
`juanbusper`. Commit: `9f1032c`.

Se incorporó a `TESTING_CIVIL3D.md` un protocolo por impacto con cinco niveles,
presupuestos de 15 s a 90 s, un solo intento de Civil 3D real, corte obligatorio
ante modales y máximo total de 10–15 minutos. También define reutilización por
hash, matriz mínima por tipo de cambio y evidencia compacta para reducir tokens.

## Estado guardado — 2026-09-08 14:05, v4.75.0 (Codex, BOG085CD119BDQN)

Agente: **Codex**. Equipo: **BOG085CD119BDQN**. Usuario local:
`juanbusper`. Commit funcional: `8877a1e`.

- Corregida la clasificación del diálogo de áreas: tipologías `Andenes`,
  `Senderos` y `Equipamientos`; el segundo selector contiene el material o
  acabado correspondiente. La cinta compilada no contiene el botón Sendero.
- Rampas: la ventana contiene Tipología y conserva capítulos separados para
  peatonal, vehicular y paso peatonal. El contenedor de raíces usa punto
  inicial, eje y lado/sentido.
- Redes: una sola configuración gobierna ancho y altura de texto para húmedas
  y secas; la migración aplica 0,20/0,60 y recalcula la longitud hasta la cara
  de pozos/cajas. Andenes y prefabricados normalizan su orden de dibujo.
- Instalado localmente en el bundle de Autodesk y cargador `acaddoc.lsp` de
  Civil 3D 2023. Hash SHA-256 del LSP instalado idéntico al repositorio.
- Validación reproducible: **64 OK / 0 fallos** en Core Console 2023 sobre una
  copia del maestro, 33,99 s. Límite: Civil 3D completo oculto quedó detenido
  por avisos modales; no se declara validación visual. Protocolo futuro: una
  sola corrida rápida (máximo 10–15 min); no repetir aperturas bloqueadas.

## Estado guardado — 2026-09-08, v4.74.0 (Codex, BOG085CD119BDQN)

Agente: **Codex**. Equipo: **BOG085CD119BDQN**. Usuario local:
`juanbusper`. Commit funcional: `8277ed1`.

- Prefabricados: cada elemento conserva destino de presupuesto `Anden` o
  `Via`; las rutinas automaticas asignan el destino segun el origen y las
  manuales permiten escogerlo. Se conservaron los conceptos exactos del libro.
- Rampas: `RAMPA-PEATONAL`, `RAMPA-VEHICULAR` y `PASO-PEATONAL` quedan bajo
  Rampas y se exportan a capitulos distintos.
- Contenedor de raices: solicita punto inicial, eje y punto lateral para fijar
  el sentido de dibujo, sin invertir textos por escala negativa.
- Redes humedas y secas: objetivo comun de ancho 0,20 m y texto 0,60 m.
- Consulta por objeto limitada a la entidad seleccionada; en la copia del
  master bajo de 610–640 ms a 16–32 ms. Cambio de etapa/subetapa ahora verifica
  escritura completa y restaura si ocurre un fallo parcial.
- Verificacion final: `61 OK / 0 FALLOS`. Evidencia y scripts en
  `diagnosticos/prioridades4740/README.md`.
- No se modificaron el Excel ni el DWG vigentes. Quedan pendientes una prueba
  visual en Civil 3D completo, decidir la ampliacion contractual aproximada de
  $783.253.493, resolver el cabezal 90908 sin diametro y modelar/conectar los
  313 accesorios ACU historicamente sin tramo.
- Estado de instalacion: esta version queda guardada en Git; no se instalo el
  bundle local porque el usuario pidio detener y documentar antes de continuar.

## Estado actual — 2026-09-07, v4.73.0 (Codex)

Repositorio: esta carpeta `URBANISMO EXTERNO`, con `.git` dentro y remoto
`jdbustosp/urbanismo-cantidades`. El motor se mantiene en
`urbanismo_cantidades.lsp`. Civil 3D carga la copia instalada en
`%AppData%/Autodesk/ApplicationPlugins/UrbanismoCantidades.bundle/Contents`.
Para actualizar: `INSTALAR.bat`; para comprobar la entrega sin instalar:
`powershell -File instalar_bundle.ps1 -ValidateOnly`.

Continuidad entre agentes/computadores: leer `CLAUDE.md` y el unico handoff
`../../handoffs/urbanismo-externo.md`. Las rutas antiguas que siguen abajo son
historia; no deben usarse como instrucciones de instalacion vigentes.

### v4.73.0 — Integridad de datos, diagnostico y validacion de entrega

- `mp:setatts`: parche con merge por clave, validacion previa, conservacion de
  campos ocultos, vaciado explicito, idempotencia y rollback ante fallo.
  `mp:store-cant-data` mantiene contrato de reemplazo completo para migraciones.
- `URB_DATA_AUDIT`: version/fecha de ultima escritura. No implica que todas las
  cantidades hayan sido calculadas por esa version.
- Cantidades: Diagnostico de integridad y Consulta de cantidades de un elemento,
  reutilizando colectores existentes sin invocar preactualizacion de redes.
  Lista navegable, detalle y seleccion por handle. No evalua el match Excel ni
  detecta todo cambio geometrico externo; no certifica cantidades.
- Registros negativos quedan REVISAR; exportacion general se cancela ante
  fallos de preactualizacion, en vez de exportar silenciosamente datos antiguos.
- Cambio de etapa/subetapa por lote: vista previa del alcance, Aplicar/Cancelar,
  UNDO agrupado y errores separados de objetos no compatibles.
- Configuracion: consultar version en sesion y motor instalado en disco.
- Instalador: prevalidacion y hashes de componentes; rutas del cargador
  verificadas (la conversion original ya era correcta). Manifiesto 4.73.0 y comentario XML invalido corregido.
- Pruebas y limites: ver TESTING_CIVIL3D.md y el handoff. No se alteraron DWG
  ni libros de presupuesto de trabajo. No se dividio el motor en modulos.

## Historial anterior (las rutas y estados de estas entradas son historicos)


Bitácora de trabajo con Claude Code sobre este repositorio. Úsala para retomar el hilo en otra máquina o en una sesión nueva.

## Estado del repo

- Repo git inicializado el 2026-08-02 sobre la carpeta `BLOQUES PPTOS` (donde ya vivía el archivo de trabajo). No se movió nada de sitio — AutoCAD/Civil 3D lo sigue cargando desde la misma ruta de siempre.
- **2026-08-03 — el `.git` real se reubicó** a `...\VARIOS\REPOSITORIO CODIGOS\urbanismo-cantidades\.git` (carpeta separada solo para el control de versiones). `BLOQUES PPTOS` sigue siendo la carpeta de trabajo (ahí se edita el `.lsp`, ahí lo carga AutoCAD) y conserva un archivo `.git` (no carpeta) tipo puntero (`gitdir: ...`) que redirige a la ubicación real. `core.worktree` en el `.git` real apunta de vuelta a `BLOQUES PPTOS`. Efecto práctico: `git status`/`add`/`commit`/`push` funcionan igual desde cualquiera de las dos rutas, sin cambiar el flujo de trabajo.
- **Cuidado al cambiar de máquina** (RESUELTO 2026-08-11): ambos punteros (`BLOQUES PPTOS/.git` y `core.worktree` dentro de `REPOSITORIO CODIGOS/urbanismo-cantidades/.git/config`) guardaban una **ruta absoluta**, y como Google Drive monta la unidad distinto en cada computador (`D:\Drive\Mi unidad\...` en modo mirror vs `C:\Users\<usuario>\Streaming de Google Drive\Mi unidad\...` en modo streaming), git se rompía por completo (`fatal: not a git repository`) en cada cambio de máquina hasta corregir ambas rutas a mano (pasó el 2026-08-04 y de nuevo el 2026-08-11). **Arreglo definitivo**: ambos punteros quedaron con **rutas relativas** (`gitdir: ../REPOSITORIO CODIGOS/urbanismo-cantidades/.git` y `worktree = ../../../BLOQUES PPTOS`, esta última relativa a la carpeta `.git` real, por eso los 3 niveles). Como la estructura interna de `Mi unidad\VARIOS\` es idéntica en ambas máquinas, git funciona en las dos sin tocar nada más.
- Remoto: https://github.com/jdbustosp/urbanismo-cantidades
- `.gitignore` excluye `backups/` y los `urbanismo_cantidades_backup_*.lsp` sueltos — desde ahora el historial de versiones lo lleva git (`git log`), no copias manuales del archivo completo.
- Flujo de trabajo: editar → `git add urbanismo_cantidades.lsp` → `git commit` → `git push`. Ver [`TESTING_CIVIL3D.md`](TESTING_CIVIL3D.md) para cómo se verifica cada cambio antes de subirlo.

## Flujo entre computadores (Drive + GitHub + bundle) — 2026-08-11

Qué vive dónde:
- **Drive (sincroniza solo entre máquinas):** `BLOQUES PPTOS` (el `.lsp`, esta bitácora, `bundle/`, `instalar_bundle.ps1`) y el control git en `REPOSITORIO CODIGOS` (punteros relativos, funcionan en ambas máquinas).
- **GitHub (respaldo y fuente de verdad):** cada push de cada sesión. Si Drive alguna vez corrompe o hace "copia en conflicto", `git pull` restaura el estado bueno — no se pierde nada.
- **Local por máquina (NO se sincroniza, y así debe ser):** el bundle instalado en `%AppData%\Autodesk\ApplicationPlugins\UrbanismoCantidades.bundle` — AutoCAD lo exige local. Para instalar/actualizar en cada computador: **doble clic a `INSTALAR.bat`** (en la raíz de BLOQUES PPTOS; sin terminal, muestra el resultado y espera una tecla). `instalar_bundle.ps1` hace lo mismo desde PowerShell si se prefiere. Correrlo de nuevo = actualizar el plugin a la versión actual del repo.

Disciplina (3 reglas, en orden de importancia):
1. **Un computador a la vez** — nunca editar en ambos simultáneamente (única causa real de copias en conflicto de Drive sobre el repo).
2. **Al terminar en una máquina:** commit + push, y dejar que Drive termine de subir antes de apagar.
3. **Al empezar en la otra:** esperar a que Drive termine de bajar antes de abrir/editar; ante cualquier cosa rara, `git status` y si hace falta `git pull`.

## Qué es este archivo

AutoLISP/Visual LISP para AutoCAD + Civil 3D. Cuantifica obras de urbanismo (andenes, prefabricados, zonas verdes, vías con movimiento de tierras, redes de servicios) y exporta a Excel vía ActiveX. ~14,200 líneas, namespaces `urb:` (núcleo) y `mp:` (módulo "Maipore Redes"). Comandos públicos: `URBANISMO` y `EDITAR`.

## Historial de cambios (más reciente primero)

### 2026-09-08 (parte 39, PC secundario, v4.72.1 → v4.72.2) — boton "Sendero" fuera del ribbon (redundante desde v4.72.0)

- Pedido del usuario (pantallazo del ribbon con el boton "Sendero" marcado con X): el comando/boton independiente "Sendero" (ventana propia con Tipo=Sendero/Ciclorruta/Plazoleta/Skatepark/...) quedo REDUNDANTE desde v4.72.0 — toda esa lista de tipos ya se crea desde **Anden** (Tipo=Sendero/Cancha/Ciclorruta/Equipamiento de parque). Se verifico contra el codigo antes de tocar nada: `urb:create-sidewalk-command` (boton Anden) delega en `*urb-send-tipos*` exactamente igual que el comando viejo, asi que ningun tipo se pierde.
- **Motor**: eliminados `c:URBSENDERO`, `urb:sendero-command` y `urb:send-write-dcl` (dialogo `urb_sendero` propio); `urb:send-fill-sub` se conservo porque Bioswale la comparte. `c:URBSENDERO` se agrego a `urb:remove-legacy-commands` para limpiar el comando si queda en memoria de una sesion con el bundle viejo. Global huerfano `*urb-send-dcl-ok*` retirado.
- **Ribbon** (`ribbon-net/UrbCantRibbon.cs`): quitado `AddBigCmd("Sendero", "URBSENDERO", "sendero")` del panel Crear → Urbanismo. Recompilado y verificado **UrbCantRibbon2025.dll** (net8, el que usa este PC en Civil 3D 2026) — sin AutoCAD instalado, solo con el SDK de dotnet y los paquetes NuGet AutoCAD.NET 25.0.0; mismos 2 warnings NU1608 preexistentes (pin roto documentado en el csproj), 0 errores.
- **UrbCantRibbon2023.dll (2019-2024) sigue PENDIENTE de recompilar**: este PC secundario no tiene AutoCAD 2023 instalado (`compilar_2023.ps1` lo exige para referenciar sus DLL) — el boton "Sendero" sigue apareciendo en esa serie hasta recompilarlo en un PC que sí tenga AutoCAD 2023. No es grave mientras tanto: el comando LISP ya no existe, así que un clic ahí solo imprime "Unknown command" en la línea de comandos (sin crash).
- **Verificacion headless** (`work\rm_sendero\check.scr` sobre `ETAPAS.dwg`): motor 4.72.2 carga limpio; `c:URBSENDERO`/`urb:sendero-command`/`urb:send-write-dcl` confirmados AUSENTES; `c:ANDEN`/`urb:poly-element-draw`/`urb:send-fill-sub`/`c:URBBIOSWALE`/`urb:create-sidewalk-command` confirmados presentes. Bundle instalado y hash verificado igual al DLL recien compilado.

### 2026-09-07 noche (parte 38, PC secundario, v4.72.0 `b93da53` → v4.72.1) — ronda de 8 frentes: diálogo 2 niveles, IDs oficiales del plano por POSICIÓN, cabezales por rango, precios IDU

- **v4.72.0**: diálogo de áreas en 2 niveles (Tipo = Andén/Sendero/Cancha/Ciclorruta/Equipamiento; Material dependiente con `*urb-elem-variantes*`; ANDEN-CONC nuevo; guía/toperol solo Andén+Loseta; RAMPA fuera); MT implícito (SUP_TN automática + picker de cotas de implantación directo, andén incluido vía `urb:anden-earthworks-por-cotas`); bioswale sin costados; ventana pozos/sumideros limpia (profundidad = tapa−clave); etiqueta de accesorio = SOLO número; cuadros de red como tablas AutoCAD (`urb:cuadros-red-command`) + perfil esquemático de MT de vía (`urb:via-perfil-esquema-command`).
- **SharePoint por PC**: en el secundario la biblioteca vive en `D:\colsubsidio.com\...\260915_ACTUALIZACION GENERAL PPTO\` (la de `C:\Users\jdbus\colsubsidio.com` es una instancia parcial VIEJA — no usar). Config self-healing reescrita.
- **ronda4 sobre el master vigente**: REPOSACC v1 = 594/594 accesorios ya clavados ≤5 cm vs diseño (0 movidos) + WIPETODOS (13 defs con wipeout, WIPEOUTFRAME 0, draworder) + RELABELACC + CLEANACCATTS (52 attdefs LOTE/SUPERFICIE_TN/ESTADO_COTA_TN/ORIGEN_CREACION fuera) + DIAGCONEX3 (281 conectados / 313 sin tramo = red ACU sin modelar) + export limpio 7.658 filas 0 huérfanas.
- **⚠️ Incidente ronda4b (lección crítica)**: REPOSACC2 emparejó por NÚMERO asumiendo AC-### == NODO del plano — FALSO (nuestra numeración era consecutivo propio): 548 accesorios movidos a nodos ajenos, 413 diámetros dañados, QSAVE al vigente. Recuperación: copia dañada preservada en BACKUPS, master restaurado del backup pre-ronda4. **Regla: el par modelo↔plano se hace por POSICIÓN, jamás por número.**
- **REPOSACC3 por POSICIÓN (fix0907c, ronda4c)**: match misma familia ≤0,10 m contra `ronda0907/acu_diseno_atts.tsv` (730 nodos con NODO=/DIAM= volcados de TOTALES\ACUEDUCTO.dwg) → 572 accesorios ADOPTAN el ID oficial del plano + 13 diámetros + 2 salidas del diseño; 0 sin par, 0 duplicados. Gotcha descubierto: `mp:setatts`→`mp:store-cant-data` REEMPLAZA el XDATA con el alist recibido — siempre pasar el registro COMPLETO mergeado con `mp:alist-set` (jamás solo los pares cambiados).
- **v4.72.1 — cabezales por RANGO**: el concepto `CABEZAL_PLUVIAL` emite los dos números del rango del libro (8 10 / 12 16 / 18 24) según el Ø del punto — un Ø intermedio (14) no aparece literal y empataba las 3 filas (71 huérfanas). `CABDIAM` heredó el Ø del extremo de tramo pluvial más cercano a los 67 cabezales que lo tenían VACÍO (62×Ø12, 4×Ø14, 1 sin tramo cerca → CABDIAM2 tol 3 m); `NORMACC` normaliza diámetros adoptados del plano ("06"→"6"; "6 EMPATE LINEA"→"6" + anotación al log — el cero inicial y el texto rompían el match por dígitos). En el libro: 2 filas nuevas de cabezal por rango (Ø8"-Ø10" 6,0M / Ø18"-Ø24" 12,5M) clonadas de la Ø12"-Ø16" 8,5M (`presupuesto/scripts_libro/precios_idu_0907.ps1`).
- **Precios IDU 2026-I** (`diagnosticos/precios_idu_20260907.tsv`): válvulas de compuerta 2,2-2,6× sobre IDU → VU = IDU×1,35 (HD bridada vs elástica E.L.): Ø4 1,61M / Ø6 3,03M / Ø8 5,11M / Ø12 10,25M; caja para válvula 2,65M→1,01M (NS-027×1,2).
- **Comparador IDU v2** (`presupuesto/referencia_idu/comparar_idu.py`): guard de diámetros REAL (solo con marca Ø/pulgada/D=/DN; la clase `[ØO]` atrapaba la O de "CODO" y metía el ángulo 90 como diámetro), guard de intervención (obra nueva no aparea con DEMOLICION/LAVADO/DESMONTE/RETIRO), fracciones mixtas colombianas ("2,1/2" = 2,5"), precómputo por ítem IDU (el bucle corre ~8M veces). Lista curada por desviación: `diagnosticos/revision_idu_curada_20260907.tsv`.
- **Empates del plano**: 8 accesorios que el plano anota EMPATE (nodos 144/114/183 Ø4, 79/75A/1 Ø12, tees 199/217 Ø6×Ø6) venían como TIPO OTRO/TEE y las equivalencias viejas los mandaban a "Unión de reparación"/"Tee 6×6" → `TIPOFIX` (ronda4f) les pone "Empate a red existente"/"Empate en tee" y `presupuesto/scripts_libro/empates_cabezales_0907.ps1` siembra las equivalencias nuevas, borra las 2 filas DUPLICADAS del cabezal Ø12-Ø16 (residuo de la corrida v3 fallida de precios, que capturó la excepción tras el Copy+Insert y aun así guardó) y tilda "tubería" en las filas nuevas. Export final: 7.658 filas, 1 huérfana honesta (cabezal handle 90908 sin Ø, sin tramo a ≤22 m — está en el backlog de descoles sin traza).

### 2026-09-07 tarde (parte 37, PC principal, v4.71.1) — barrido VU, depuración global, preliminares 3,5% real, MT completo de presión, subtotales solo-VT

- **VU en blanco eliminados**: 17 precios nuevos para el paquete descoles/box culvert/cámaras (SC-/MAT-/MO-) y complementarios (HSEQ/paleteros/pólizas/CAR/vigilancia/CCTV) — 0 actividades sin precio (`diagnosticos/precios_ronda3_20260907.tsv`).
- **9 correcciones de coherencia AL ALZA**: tuberías "novafor 315/250 mm" de parques 3-4× por debajo de la serie oficial del propio libro (315 mm = 12" → tubo 6 m 941.853); ALMA CAFÉ alineada (RDE21 4" → 228.893, arena/recebo → 110.000); dren francés 200 ≠ 100 mm.
- **Preliminares 3,5% real** (reclamo "no puede ser VU=1 con cantidad tan alta"): celdas de subetapa = BASE por subetapa, VU = 0,035 con formato "3,5%", VT = 3,5% × base — la dinámica muestra el 3,5% de cada subetapa.
- **MT acueducto espejo exacto** (−7: exc manual/conglomerado [resaltadas por el usuario], relleno inicial, manejo de aguas, demoliciones/reposiciones) + **motor v4.71.1**: cimentación/recebo/entibado extendidos a tramos de PRESIÓN (arena 0,10 m sobre clave; el bloque de creación solo cubría gravedad) con derivación en el export desde la geometría cuando los atributos vienen vacíos — el MT del ACU se llena SIN re-editar el master; +localización/replanteo (3 redes húmedas) y cinta de señalización (ACU).
- **Depuración global "no van"**: pluvial queda con PVC flexible Ø12/14/20/24 (−28 tuberías: Ø18/Ø27 y toda la serie de concreto); pozos pluviales −2 (cono y tapa duplicado, cámara ≥36"); censo completo de filas en cero en `diagnosticos/censo_cant_cero_20260907.txt` (el resto se conserva: catálogo del motor, diseño por modelar, ítems contractuales). Hoja reescrita desde `diagnosticos/pe_nuevo3_20260907.tsv` (1.540 filas).
- **Redes secas verificadas**: MT y TELECOM tienen capítulo de movimiento de tierras; AP y OBRAS ELÉCTRICAS llevan la excavación embebida en el APU de canalización.
- **Dinámica**: subtotales N1..N4 (arriba) visibles SOLO en VALOR_TOTAL (CANTIDAD/VU ocultos con ";;;" vía PivotSelect); BD 3.009 filas, Actualizar-todo probado headless.
- Suite **85 checks TODO-OK** (PPTO-PARAMETRICA 112→113 por la localización nueva). Backup: `BACKUPS/urbanismo maipore_backup_antes_ronda3_20260907.xlsx`.

### 2026-09-07 mañana (parte 36, PC principal, v4.71.0) — GEN reparada + refresh dinámica arreglado, pluvial desagregado como sanitario, MT unificado, puente export→hoja

- **Bug GEN cazado y reparado** (reclamo del usuario: `[Expression.Error] The column 'GEN'...` al refrescar la dinámica): el paso2 de la reestructuración escribió POR EJECUTAR con 41 columnas en un layout de 42 — las fórmulas CANT/VU/VT pisaron la subetapa GEN (col 39) y `SUM(RC6:RC38)` la excluía. Hoja REESCRITA completa en 42 col (GEN=AM, CANT=AN, VU=AO, VT=AP, subtotales `INDEX(C42)`, 3,5% con VU col 41, formato L1 y outline de filas al final) en un solo script verificado; query BD_PE robusta con `Table.UnpivotOtherColumns` + `RemoveColumns MissingField.Ignore` (ya no depende de la lista de subetapas) y `PE_RANGO=A2:AP5000`. RefreshAll headless OK: BD_CONSOL 2.688→3.009 filas (los 674 aportes GEN que se perdían).
- **Pluvial desagregado** (reclamo "actividades de pluvial que sobran… desagregar suministro/instalación"): las 22 refs "Tubería MAT D Hex (banda)" + 2 duplicadas de SUMIDEROS (copia exacta columna a columna = doble conteo del lookup, verificado) se reemplazaron por SUMINISTRO (UN=ML/6) + INSTALACIÓN (ML) por material+diámetro (18+18), cantidades migradas con control ML in=out 6.361,79; NOVAFORT→nombres del sanitario "PVC flexible ØX" (precio heredado por SUMIF), concreto→"en concreto CSR/CCR/CER ØX" con 28 precios nuevos altos (`diagnosticos/precios_pluvial_20260907.tsv`); biofiltros duplicado eliminado; capítulos renombrados (POZOS DE INSPECCIÓN, PRUEBAS) y reordenados espejo del sanitario.
- **MT unificado** (reclamo "el MT de pluvial y acueducto no se parece al de sanitario"): ACUEDUCTO con MT como 3er capítulo y actividades en el orden del sanitario (específicos de presión al final); pluvial ya era espejo y subió a 3ª posición. Fuente de la hoja: `diagnosticos/pe_nuevo2_20260907.tsv` (+`pe2_cambios_20260907.log`).
- **Motor v4.71.0**: rama pluvial sin caso especial Hex (emite suministro+instalación+zanja completa como las otras redes; el MT pluvial se llenará del modelo); traducción NOVAFORT/NOVALOC/PVC→"PVC flexible", CSR/CCR/CER→"en concreto MAT"; cimentación ACU→"Cama y atraque en arena de pena". **Puente export→hoja `urb:ppto-write-pe`**: vuelca la agregación de TablaMemorias (todos los DWG) en las celdas de subetapa de POR EJECUTAR (el libro reestructurado guarda valores) — fila resuelta con el vocabulario del match (desc exacta, desempate zona/capítulo/UM), filas del export anterior en 0 vía snapshot `urb:ppto-pe-old-rows`, manuales intactas, filas con fórmula saltadas. Harness: +`PPTO-PUENTE-PE` (85 checks), `ppto_test.xlsx` al layout 42.
- Backup libro: `BACKUPS/urbanismo maipore_backup_antes_pluvial42_20260907.xlsx`.

### 2026-09-07 madrugada (parte 35, PC principal, commits `09f68a3`..`ba29753`) — libro con formato y dinámica viva, perf medido, precios 2026, resolutor multi-PC verificado

- **Libro**: POR EJECUTAR con formato completo (colores por nivel, bordes, agrupador de filas resumen-arriba re-aplicado tras bug ClearOutline, columnas de subetapas colapsables, A/B ocultas con ITEM autónomo, VALOR_TOTAL subtotalizado en las 285 filas de capítulo vía LET/XMATCH); EJECUTADO etapa/subetapa GENERAL (+columna SUBETAPA); hoja BD reconstruida por POWER QUERY (BD_PE unpivot + BD_EJEC 5 niveles + BD_CONSOL 2.687 filas) y DINAMICA nueva compacta (una columna jerárquica, Cant/VU prom/VT, N5 con UM entre paréntesis, slicers) que se refresca con Actualizar-todo.
- **Perf del export MEDIDO** (urb:perf-log/rows-timed nuevos, v4.70.1): colectores 9,8 s + match 4,4 s = ~14 s de plugin sobre el master real; la lentitud percibida era la apertura del master en frío. No se optimizó a ciegas.
- **Precios 2026**: 11 ajustes al alza (concreto 560k, granulares de parques igualadas a las oficiales 217-236k, malla/hierro 7,5k, descapote 35k, arena peña 110k) + 1 corrección de unidad (MDC-II 5.5cm: 960k/M2 era precio de M3 → 78k/M2, REVISAR). Bioswale completo (+cargue y retiro). Cobertura planos redes documentada (sin faltantes ni sobrantes de ppto).
- **Resolutor multi-PC v4.70.2**: nombre de archivo dinámico + test E2E real (config rota → encontró el libro junto al master y self-healeó). Suite 84 checks TODO-OK en 4.70.1 y 4.70.2.



### 2026-09-06 (parte 34, PC principal, commits `27d795f`..`e50feaa`+) — v4.70.0: todo lo faltante modelable + reestructuración completa del libro

Jornada doble (Excel + motor), pedido "ejecuta todo de corrido":
- **Libro vigente reestructurado**: EJECUTADO nuevo desde la BD de actas de Lugel (734 filas, 3 categorías, totales exactos $158.612.001.569); POR EJECUTAR reescrita (1.565 filas, 55 cambios: cañuela, rampas completadas, cárcamos→MT como ML, tuberías ACU a UN, pluvial sin duplicados + capítulos nuevos MT/bioretenedores/cabezales, zona verde con exc/rellenos) con **numeración automática por fórmula** (niveles 3-5), V/U 100% por SUMIF, 3,5% de preliminares por subetapa vía SUMPRODUCT; PRECIOS_UNITARIOS 1.290 filas (216 sembradas) y **0 en $0** (25 completados con criterio alto + justificación por analogía interna, `diagnosticos\precios_completados_20260906.tsv`); barrido de coherencia VU: 0 duplicados inconsistentes, 12 outliers explicables (`vu_barrido_20260906.txt`).
- **Motor v4.70.0**: catálogo de áreas 5→14 tipos (canchas sintética/múltiple, skatepark, escaleras, gradería, pista caucho, parque de niños, zona gym, biciparqueo — mismo diálogo del Andén, recetas exactas del ppto por parque, MT heredado, redirect por zona+hint); bioswale con receta de la cartilla (8 actividades 2.5.3.7); mobiliario +11 tipos de parque; suministro ACU en UN=ML/6; **comando SENALIZACION aparte** (42 tipos: líneas ML con factor de ocupación, símbolos M2, señales UN) con botón en cinta — **ambas DLL recompiladas en este PC** (2023 v4700 FW4.8 + net8 2025/2026); suite 84 checks TODO-OK (checks nuevos + 2 del harness actualizados a diseños vigentes).
- **Multi-versión**: manifiesto cubre 2019-2024 (R23-R24.2, DLL FW4.8) y 2025-2026 (R25.0-R25.1, DLL net8); 2027 (net10) requerirá DLL nueva — documentado en el propio XML. El motor LISP carga por acaddoc en cualquier versión.
- Lecciones PowerShell/COM del día (en el handoff): índices 2D `(5+$k)` con paréntesis, fórmulas por bloques + Retry ante RPC_E_CALL_REJECTED, no llamar `$b` al parámetro de un helper que invoca scriptblocks, anclas de texto con NumberFormat "@" (locale es-CO), AutoSave de OneDrive.



### 2026-09-02 tarde (parte 33, PC principal, commit `478b700`) — traslado a SharePoint completo + carga de comandos en 2023 + retrim tramos húmedos

- **Traslado a SharePoint (pedido del usuario)**: libro y master vigentes ahora en `colsubsidio.com\...\260915_ACTUALIZACION GENERAL PPTO\` (libro raíz; master en `Memorias\` con xrefs en `Memorias\XREF\`). Config del plugin re-apuntada. Los **8 xrefs guardaban rutas relativas del esquema viejo de Drive y salían rotos** → re-apuntados a `.\XREF\<resto>` (relativas, válidas en ambos PCs), verificado con doble censo headless. Backups: NUEVA carpeta única `...\PROYECTO_URBANISMO_GENERAL\BACKUPS\` (29 existentes movidos + los de hoy). Lo viejo de Drive queda congelado como histórico.
- **Purga del master real** (autorizada): AUDIT OK, regapps 5.717→41, escalas reseteadas, 35,7→31,4 MB, nada modelado perdido.
- **"Unknown command ANDEN" en 2023**: el Autoloader carga el .lsp solo en el PRIMER documento (AutoLISP es por-documento) — el dwg de trabajo quedaba sin motor; antes lo tapaba el Startup Suite viejo. Fix de clase: `instalar_bundle.ps1` genera el cargador `acaddoc.lsp` (NETLOAD DLL + load del motor, con guardas) para CADA `C3D 20xx\enu\Support` (antes solo 2026). Verificado headless: motor 4.68.0 y comandos definidos automáticamente.
- **Tramos húmedos cortos (foto pozo 33)**: la pasada por handles destapó que **294/295 tramos SAN/PLU no tenían HANDLE_EXTREMO_INI/FIN**. Retrim v2: busca el pozo real de la misma red sobre la prolongación del eje (perp ≤0.35, alcance ≤2.8), re-vincula handles y sincroniza con `mp:sync-tramo-values` → **217 reposicionados al borde (0.60) + re-vinculados**, 77 sin pozo cerca (zonas sin modelar, ver `diagnosticos\retrim_hum2_0902_result.txt`), 0 errores. Cantidades intactas.



### 2026-09-01 noche (PC secundario, Civil 3D 2026) — v4.67.0: 2ª ronda del mismo día (8 frentes)

1. **Picker de cotas de diseño intuitivo** (`urb:pick-design-cotas`) para el MT de polígonos (zona verde/sendero/rampa): cada cota por clic sobre vía/pozo/etiqueta O digitada ([Digitar]: número + punto); **mínimo 1** (1 = plano horizontal, 2 = rasante lineal, 3+ = plano ajustado). Responde "¿y si no hay vía?": se digita y ya.
2. **Rampa**: corta el sardinel/bordillo existente bajo su frente (`urb:trim-prefabs-for-ramp`: extrae la referencia del prefabricado, quita el rango ocupado y reconstruye las piezas restantes; pregunta [Si/No] <Si>) + corte/relleno opcional del módulo (xdata `URB_RAMPA_MOV`). El ancho por clic ya estaba en v4.66 (la queja del usuario venía de una sesión con el motor viejo).
3. **Senderos con el símbolo del andén**: retícula NET 0.40 gris en vez del sólido de color (ciclorruta conserva azul sólido).
4. **Pluvial sin cotas obligatorias**: sin claves → recubrimiento normativo 1.2 m (RAS 0330) + diámetro + cama; la banda Hex sale de la PROFUNDIDAD_MEDIA; la validación no exige pendiente en modo normativo.
5. **Texto/espesor de tramos configurables** (Ajustes: `URB_MP_TEXTO_TRAMO`, `URB_MP_ANCHO_TRAMO`; aplican a defs nuevos/renormalizados; ACU sigue hairline).
6. **Accesorios ACU a la capa PPTO-ACUEDUCTO** (una capa por red); `PPTO-ACCESORIOS-ACUEDUCTO` deja de crearse.
7. Harness `ajustes0902/fix0901b.lsp`: BORRAEJEC (elimina elementos y capas *-EJEC — el ppto queda solo-pendiente), MOVERACC, AUDITACC/CENTRAACC (defs de accesorio corridos re-centrados), REWIPE/REFIXVIA (re-aplican los fixes de anoche si la sesión abierta del usuario los pisa al guardar).

### 2026-09-02 (PC secundario, Civil 3D 2026) — v4.66.0: ronda de 11 pedidos (diálogos + MT + accesorios + cárcamo)

1. **Sardinel externo garantizado en curvas**: el lado se decide con test punto-dentro-del-contorno (muestreo cada 0.25 m + ray casting) en vez del producto punto contra el centroide, que fallaba en tramos curvos (foto del usuario: sardinel izquierdo interno).
2. **Picker de cotas reconoce POZOS del modelo** (`urb:cota-from-model-punto`): COTA_TAPA/COTA_TN_INI de cualquier bloque MP_PUNTO_*; orden libre vía/pozo/etiqueta y N pozos intermedios con extrapolación (ya existente) — aplica a MT por Pendiente, andén "Cotas seleccionadas", zona verde y sendero.
3. **Tramo ACU simplificado**: diálogo propio sin extremos ni cotas de diseño; excavación normativa RAS 0330 (recubrimiento 1.0 m a clave + diámetro + cama) cuando no hay cotas.
4. **Accesorios ACU**: campo Número (etiqueta = "AC-461 TEE"), sin Lote/Sector; dirección al crear (etiqueta se mantiene horizontal, `mp:level-etiqueta-atts` también en el refresco de etiquetas); opción [Xref] que reconoce el tipo desde el bloque del plano (nentsel + matriz).
5. **Prefabricado y zona verde sin campos de espesor** (config: `URB_PREFAB_ANCHO_*`, `URB_GREEN_ESP_TIERRA` nueva en Ajustes); zona verde con hatch verde sólido transparencia 70.
6. **Motor de corte/relleno por cotas** (`urb:earthworks-from-picks`): plano por mínimos cuadrados (≥3 cotas) o rasante lineal (2), malla adaptativa 0.5–2.5 m contra SUP_TN; opcional al crear zona verde (atts CORTE_M3/RELLENO_M3) y sendero (xdata URB_SEND_MOV). Sin filas de export todavía (zonas verdes nunca han exportado).
7. **Cárcamo**: toggle en diálogos de tramo hidro → att CARCAMO → fila ppto "Carcamo" ML; libro con filas CARCAMO clonadas en 2.5.1.1.11 / 2.5.2.2.10 / 2.5.3.1.21 (precio via SUMIF a PU B804).
8. **Rampa**: ventana solo con etapa/subetapa — el clic sobre el borde define dirección Y hasta dónde va (banda central = distancia − 1.20 m de aletas), opción [Longitud] para digitarla; el fondo lo define el clic final al bordillo (2 rondas de feedback del usuario el mismo día). Export verificado tras la corrida: 7893 filas, 0 huérfanas, 0 errores.
9. DCL bump `maipore_listas_v12`. Harness `work\ajustes0902\` (AUDITSOBRE/FIXSOBRE/SPLITACC piloto).

### 2026-08-27 (parte 32b, PC principal, commit `0a6c815`) — v4.60.1: el descuento de bordillo sobrevive al EDITAR

Diagnóstico del master (copia, read-only) encontró la causa real del "no me descuenta el bordillo": un anillo `URB_PREFAB_ANILLO` Interno con handle destino MUERTO — al EDITAR, el andén se re-empaqueta con handle nuevo y el costado quedaba apuntando al viejo (descuento perdido en silencio).
- `urb:relink-anden-anillos`: en EDITAR (rama andén empacado) se captura el handle viejo antes de borrar y los anillos se re-apuntan al bloque nuevo.
- Adopción en `urb:anden-area-anillos`: anillo Interno con destino muerto cuyo centro de bbox cae dentro de la caja del andén → re-vínculo + descuento en el siguiente export (repara casos ya rotos sin comando nuevo). OJO: el punto de inserción de los bloques prefab es SIEMPRE (0,0,0) — la posición real es el centro del bbox.
- Verificado contra el caso real en copia del master: huérfano adoptado (descuento 1.05 m² estable, ambos vínculos vivos). Suite 82 checks TODO-OK.
- **Purga piloto validada en la copia**: AUDIT OK, regapps 5.717→29, bloques 1.921→1.466, escalas reseteadas, 89.234→89.229 entidades (nada modelado se pierde), 34.72→33.2 MB. Capas legado del árbol están VACÍAS (censo: 0 entidades top-level). La purga del master REAL quedó pendiente de confirmación del usuario (bloqueada por permisos de la sesión autónoma).

### 2026-08-27 (parte 32, PC principal, commit `7b42b92`) — v4.60.0: 5 fixes de la ronda de reportes con pantallazos

Suite 82 checks TODO-OK (3 nuevos: `EXTRAPOLA-PENDIENTE`, `CURVA-CHAINS-BULGE`, `CURVA-CHAIN-POLYLINE`):
- **Rasante extrapolada por pendiente** (`urb:cota-at-axis-distance`): fuera del rango de cotas ya no se congela el valor del borde — se extrapola con la pendiente de los 2 puntos extremos. El gate de cobertura (`urb:compute-road-earthworks`) acepta cobertura PARCIAL (≥3 estaciones y span cubierto ≥ max(3×intervalo, 20% del tramo)) con mensaje "Rasante con EXTRAPOLACION: ...". Resuelve la vía rechazada con 13 cotas y huecos de 26/125 m.
- **Toperol dentro de la región** (`urb:fill-tactile-symbols`): cada símbolo se valida con `urb:point-in-poly-p` contra el contorno real de la franja antes de dibujarse (antes se sembraba sobre el rectángulo de bounds u/v y en recortes a inglete/curvos caía fuera del bloque). La guía valida además sus dos extremos.
- **Guía rediseñada**: UNA barra longitudinal por tableta (largo = módulo − 2 márgenes) en vez de 4+ columnas de cápsulas de 15 cm solapadas cada 5 cm (el efecto "eslabones" del pantallazo). El toperol conserva su retícula de domos cada 5 cm.
- **Costados curvos** (`urb:poly-costado-chains`/`chain-polyline`/`chain-length`): las cadenas conservan el bulge — vértices (x y bulge), bulge del último vértice anulado (pertenece a la punta cortada), la polilínea de referencia emite los 42 y la longitud se mide como arco real (θ=4·atan|b|, arco=c·θ/(2·sin(θ/2))). El prefabricado sigue la curva vía `vla-Offset` (ya era arc-aware). Cubre andén + sendero + bioswale (mismo motor).
- **Costado al frente del andén**: los bloques de costado reciben `DRAWORDER _Front` tras el vínculo `URB_PREFAB_ANILLO` (el achurado del andén, insertado después, tapaba la franja interna del bordillo).
- La cadena del descuento de bordillo (AREA_M2 → xdata → `urb:anden-area-anillos`) se auditó completa y es correcta en código; el caso real del usuario se diagnostica con `work\audit_mt\diag_master_0827.lsp` (censo de capas/proxies/anillos rotos, read-only sobre copia).

### 2026-08-26 (parte 31, PC secundario) — v4.58.0: rediseño visual redes secas + cruce eléctricas 17/18 contra el libro real

Jornada iterativa con el usuario revisando en vivo (muestra mínima `work\lote_redes\MUESTRA_TRAMO.dwg`, 6 versiones):
- **Simbología del plano**: cajas replicadas 1:1 (CS276 tapa doble 2.00×1.70, CS280 2.00×2.00 con círculo, CS274/275 sencilla 1.08 = "CAJA AP 274"), rotadas como el plano, etiquetas "276" arriba / consecutivo abajo (att `NUM_VIS`), texto ≤0.60 pegado al símbolo. Tramos MT/BT-AP: franja 0.20 de **borde a borde de caja** (recorte = media caja: 1.00/0.54; cantidades siguen centro a centro), ducteria "6Ø6" PVC" arriba y "L=xx.xx" abajo (att `LONG_VIS`), texto ≤0.90. TODO MT en capa única `PPTO-ELECTRICA-MT`.
- **Panel de propiedades depurado** (MT/BT): fuera Circuito/Desde/Hasta/Conductor/DiámDucto/Libres/Profundidad/Ubicación/TipoRed/Memorias/entibados/triturado/recebo/Cama/Relleno/Sobrante/Reposición (datos persisten en XDATA — `mp:setatts` guarda la copia completa); nuevos `ARENA_M3`/`BASE_GRANULAR_M3` con los nombres del presupuesto. `POSTE_ELEC` con `LUMINARIAS`+`TIPO_LUMINARIA`. Chequeo de nivelación por caja (`COTA_TAPA` vs terreno muestreado → `NIVELACION` OK/ENTERRADA/COLGADA ±0.15).
- **Cruce eléctricas contra el libro REAL** (`urbanismo maipore.xlsx`, corregido por el usuario a mitad — el primer cruce fue contra el libro equivocado): filas MT/AP recalibradas a la redacción literal del capítulo 2.6 → **17/18 conceptos vinculados AUTO con match exacto** (banco 6Ø6"→6Ø6", suministro+tendido 3x185, exc/arena/base, cinta, mandrilado, CS276, CS274, poste 12m, luminaria DECOLED, tubería 2Ф3", cable 4x4 THW). Único pendiente: CS280 (el libro no la tiene — intencional). Sin sobrantes/reposición por orden del usuario (el libro las tiene, 1026/1027, sin cantidades del modelo). Harness `lote_redes/verify_cruce_elec.lsp` (reutilizable).
- **Hallazgos técnicos**: (1) la red AP completa vive DENTRO de los bloques `CR T1..T5` de SERIE 6 (632 cajas AP-274, red BT SUBT PROY, postes con luminarias con referencia real) — las sondas no entraban a bloques anidados; (2) bloques "zombi" de AutoCAD: purgar+recrear el mismo nombre en una sesión resucita la geometría vieja — reparar definiciones en sitio, nunca purge+recreate; (3) `ssget "_X"` salta capas congeladas (usar `entnext`); (4) `vla-PlotToFile` crashea en C3D 2025 headless.
- Pendiente (próxima sesión): remodelado AP del master desde CR T1..T5 (cajas reales, red caja a caja, postes con luminarias, acometidas 2x12 AWG), re-simbolizar el MT existente del master, trafos por kVA, decisión CS280 y 1Ø3"/3Ø3" vs la única 2Ф3" del libro.

### 2026-08-25 noche (parte 30, PC secundario, commit `8ec9348`) — v4.57.6: corrección de LOTE REDES tras revisión visual del usuario

El usuario revisó a mano el resultado de LOTE REDES (parte 29) y reportó 3 problemas: sardinel "Interno" en vez de "Exterior", accesorios de acueducto ilegibles (704 círculos idénticos), y tramos MT/redes secas viéndose "círculo a círculo como si fueran pozos" en vez de caja a caja.

- **Sardinel**: investigado con sondas de solo lectura sobre el master — los datos ya muestran `MODELADO=Exterior` en ambos sardineles nuevos. No se modificó nada (no hay bug que corregir según los datos); pendiente confirmación visual del usuario.
- **Accesorios de acueducto**: dos bugs de raíz en `lote_redes.lsp` — todos compartían un color de instancia, y la propagación de diámetro usaba `mp:setatt-one` (no regenera la ETIQUETA visible) en vez de `mp:update-block-after-edit`, dejando el diámetro en blanco en la etiqueta. Corregido el harness (afecta corridas futuras) + reparación aparte contra los 704 ya existentes (`reparar_accesorios2.lsp`, corrido una vez sobre la copia de trabajo vía Civil3D headless completo — accoreconsole no sirve para verificar esto, no resuelve bien estos objetos). Resultado verificado: 704/704 con etiqueta completa, color por `TIPO_ACCESORIO` (TEE=1, HIDRANTE_TORRE=2, VALVULA*=3, TAPON=253, REDUCCION=140, CODOs=30, OTRO=8).
- **MT/BT-AP "círculo a círculo"**: causa real en el motor, no en el harness — `mp:make-cant-tramo-block` dibujaba 2 círculos genéricos "de pozo" dentro de CADA definición de bloque de tramo MT/BT-AP, igual que alcantarillado, pero MT/BT-AP ya tienen sus nodos (cajas CS276/280, postes, trafos) como bloques punto independientes — los círculos tapaban la caja cuadrada real. Fix: `mp:tramo-own-node-blocks-p` (nueva, extiende el criterio que ya existía para hidrosanitario `mp:hydro-tramo-p`) usado en los dos puntos de `mp:make-cant-tramo-block` que decidían dibujar el círculo — MT/BT-AP quedan sin círculos propios, igual que acueducto/alcantarillado. Aplica solo a tramos nuevos; para los 722 ya existentes (220 MT + 553 BT-AP, ya sin contar tramos MT-segmento duplicados) se corrió una reparación que edita las DEFINICIONES de bloque compartidas (no las instancias, mucho más rápido) borrando los 1444 círculos horneados — verificado 0 remanentes, conteos de instancias intactos.
- Los 3 pasos anteriores se aplicaron al master real (`URB_MASTER_GENERAL.dwg`) con backup fechado en cada uno (`_backup_antes_repararacc_20260825`, `_backup_antes_mtcirculos_20260825`) y bundle reinstalado en este PC con motor 4.57.6.
- Sin resolver: la idea abierta del usuario de una UX de inserción interactiva para accesorios ("pincharlo y que se dibuje tal cual viene en plano") no se implementó — se interpretó que el fix de color+etiqueta ya resuelve el requisito duro ("que sea fácil rastrear cualquier accesorio"), y el resto era una sugerencia con libertad explícita ("tú mirarás cuál es la mejor forma").

### 2026-08-24 noche (parte 29, PC secundario) — LOTE REDES: pluvial, acueducto, MT y alumbrado modelados en el master real

Pedido del usuario: "como hiciste con alcantarillado, modélame media tensión, alumbrado, pluvial y acueducto, y verifica inconsistencias con presupuesto". Ejecutado completo la misma noche con arquitectura nueva de 2 fases (extracción en accoreconsole sin diálogos → construcción en Civil 3D 2025 headless), 4 pilotos + 4 corridas iteradas cazando bugs reales, y corrida final v4 aplicada al master con backup. Resultado: **pluvial** 357 puntos + 229 tramos; **acueducto** (fuente TOTALES, corregida a pedido del usuario) 704 accesorios + 337 tramos; **MT** 291 cajas + 57 equipos + 220 tramos; **alumbrado** 603 luminarias + **553 tramos reconstruidos** encadenando luminarias del mismo circuito (el plano no trae la red dibujada — validado contra la suma de etiquetas: 16.037 vs 15.584 ML). Harness + resultados + lecciones en [`lote_redes/`](lote_redes/README.md) (carpeta nueva del repo, sincroniza entre PCs). Cruce con presupuesto: `cantidades_modelo.txt` (167 conceptos); afectaciones documentadas en el README y el handoff (cabezales/captaciones/acometidas sin tipo en el plugin, tubería pluvial por rangos de profundidad, recubrimiento acueducto supuesto 1.00 m). El detalle de las versiones v4.53-v4.57 del plugin (misma sesión, más temprano) está en los commits individuales.

### 2026-08-24 (parte 28, PC secundario) — v4.53.0: PC nuevo con Civil 3D 2025/2026, cinta reorganizada, Filtrar/Rastrear, contenedor de raíces corregido, Bioswale a Pluvial, prefabricado por costados

Primera sesión en un segundo computador (Civil 3D 2025 + 2026 instalados, no 2023). Hallazgo de arranque: `UrbCantRibbon2025.dll` llevaba desde el 13/08 sin recompilar y en realidad **nunca había compilado con éxito** — `AddMemoriasContextMenu()` (agregada el 13/08) usaba el alias `AcDb` que solo se definía bajo `#if URB_AEC_PROPERTY` (activo en el build 2023, no en el de 2025). Corregido: el alias `using AcDb = Autodesk.AutoCAD.DatabaseServices;` salió del `#if`; y como esa función sí compiló pero **crasheaba con Access Violation 0xC0000005** en 2025 (probable desajuste de versión AutoCAD.NET/AutoCAD.NET.Core, ver NU1608), se deshabilitó específicamente para el build `NETCOREAPP` (`#if !NETCOREAPP`) hasta investigar el paquete NuGet correcto. Instalador (`instalar_bundle.ps1`) corregido también: `TRUSTEDPATHS` solo confía en el nivel exacto de la carpeta — el `.dll` vive en `Contents\net\` (subcarpeta de `Contents\`, que sí estaba confiada) y mostraba el diálogo de seguridad "Unsigned Executable File" en cada recompilación; se agregó la variante recursiva `\...`.

Ronda grande de ajustes de UX pedidos en vivo:
- **Panel "Elemento" → "Editar"** (el botón adentro sigue diciendo "Elemento"); **Cuadro/Memoria/Verificación** salen de la cinta (siguen por comando `QCUADRO`/`QMEMORIA`/`QVERIFICACION`).
- **Localización** quedó SOLO para georreferenciación (zonas/parques marcados, seleccionar, quitar marca, marcar nueva) — el filtro por etapa/subetapa que vivía ahí se movió.
- **Botón nuevo "Filtrar"** en Cantidades: filtro por etapa/subetapa + **rastreo por texto del presupuesto** (`urb:track-by-texto`: recolecta en memoria las mismas filas que arma el export — sin abrir Excel — y matchea con el tokenizador/score difuso ya probado de la vinculación real, `urb:ppto-words`/`urb:ppto-word-match-p`; ej. "tuberia 8" selecciona todos los tramos que generan "Instalación tubería PVC 8""). Tras la primera prueba: ya no solo SELECCIONA, **AISLA** con `ISOLATEOBJECTS` nativo (apaga todo lo demás) — y como eso apagaba también los XREF (aparecen como un solo INSERT), se agregan automáticamente al aislamiento los INSERT de xref (`IsXRef`, mismo patrón del lote RESIDUAL). Botón "Quitar filtro" (`UNISOLATEOBJECTS`) para restaurar la vista.
- **Contenedor de raíces corregido**: salía como un diamante rotado 90° respecto al andén/sendero. Causa: el bloque se dibujaba CENTRADO con el LARGO por el eje Y local, pero `vla-InsertBlock` alinea el eje X local con el ángulo del segundo clic — se rediseñó con el punto de inserción en una ESQUINA y el largo por el eje X local (sufijo de bloque `_C3` para forzar regeneración en dibujos con la definición vieja).
- **Bioswale salió de Sendero y entró a Pluvial** (Crear → Redes húmedas → Pluvial → Bioswale, comando `URBBIOSWALE`): es un elemento de red pluvial, no de parques. Wiring completo: capa/receta propias (`*urb-bioswale-tipo*`), filas de presupuesto (`urb:ppto-rows-poly-elemento` generalizado, compartido con Sendero), zona/Localización (`urb:bioswale-selected`), filtro por etapa (`urb:element-etapa`, `urb:loc-collect-etapa`), colector de Filtrar/Rastrear.
- **Ventana de Sendero simplificada**: fuera el bloque "Movimiento de tierras" (texto informativo) y el campo "Ancho m" del prefabricado perimetral — ambos se volvieron **editables en Ajustes → "Senderos y prefabricados"** (espesor de estructura por tipo, que ahora sí afecta la fila de excavación exportada vía `urb:send-espesor-de`; ancho por defecto por tipo de prefabricado vía `urb:prefab-default-ancho`).
- **Prefabricado por COSTADOS** (nuevo, distinto del anillo perimetral que envuelve todo el contorno): permite un tipo distinto por lado (ej. cañuela en un costado, bordillo en el otro) SIN envolver las puntas. Tipo de cada costado configurado una sola vez en Ajustes; al crear el sendero se pide trazar cada costado configurado (misma mecánica ya probada del botón Prefabricado independiente, `urb:build-prefab-from-reference` — cero geometría nueva, solo reutilización).
- **Ajustes → "Organizar capas del plugin"**: crea/actualiza un filtro "URBANISMO" en el árbol del Administrador de capas (como "All non-Xref Layers") agrupando `URB-*`. Requirió código .NET nuevo (`URBLAYERFILTER` en el ribbon, `Autodesk.AutoCAD.LayerManager.LayerFilter/LayerFilterTree` — namespace confirmado por reflexión contra `AcDbMgd.dll` real, ya que la primera suposición `DatabaseServices.Filters` no existe) porque AutoLISP clásico no tiene esta API.

**Pendiente de validar en vivo por el usuario** (todo pasó verificación de sintaxis — balance de paréntesis, sin duplicados, compilación limpia de ambas rondas — pero NINGUNO de los flujos nuevos se probó con clic real del usuario todavía, salvo el aislamiento del Filtrar que sí se confirmó en pantalla): contenedor de raíces con la geometría nueva, Bioswale end-to-end (crear, zona, filtro, exportar), Ajustes de espesor/ancho (que realmente cambien la cantidad exportada), prefabricado por costados (el flujo de doble trazado), y el filtro de capas "URBANISMO" (la API de LayerManager nunca se probó contra un Civil 3D real, solo se confirmó por reflexión que los miembros existen). **DLL de 2023 sin recompilar**: los cambios de `UrbCantRibbon.cs` de esta sesión (botón Bioswale, comando URBLAYERFILTER, fix del alias AcDb) solo se compilaron para 2025 en este PC — la próxima sesión en el PC principal (Civil 3D 2023) debe correr `ribbon-net\compilar_2023.ps1` para que la cinta de ese equipo quede al día.

> **Nota**: entre la parte 27 (v4.23) y la parte 28 (v4.48) hubo ~25 versiones documentadas en el handoff (`..\..\handoffs\urbanismo-externo.md`) y la memoria compartida, no aquí. Resumen: motor de presupuesto Excel completo (vinculación, match, memorias, paramétricas, zonas de parque, mobiliario urbano).

### 2026-08-21 (parte 28) — v4.48.0: redes secas normativas CODENSA, senderos por polígono cerrado y bioswale a pluvial

Ronda grande pedida por el usuario ("has todos los cambios correspondientes a esas redes para que ya quede listo para modelar" + senderos "igual a una via o un anden que me ponga a cerrar el poligono").

- **Diálogos Tramo MT / BT-AP depurados** (`mp:write-dcl`, `mp:dialog-tramo-mt/bt` y los de EDITAR): fuera Serie, Circuito, Ductos libres, Profundidad de zanja y las 2 notas (los campos que el usuario marcó como no importantes). Nuevo popup **"Ubicacion ducteria"** (Andén o zona verde / Calzada) con atributo `UBICACION` en ambos bloques de tramo.
- **Excavación/relleno normativos** (`mp:elec-normative-depth`): profundidad de zanja SIEMPRE automática para tramos eléctricos = recubrimiento CODENSA (0.60 m andén / 0.80 m calzada, Likinormas CS203/CS207) + altura del banco (columnas = ceil(sqrt(ductos)), coherente con `mp:default-trench-width`; 0.05 m de separación y base). Antes dependía de un dato manual que nunca se digitaba y la excavación salía 0.
- **Filas de presupuesto eléctricas recalibradas contra el libro real** (`urb:ppto-rows-tramos`): MT emite banco de ductos (texto EXACTO `Suministro e instalación de banco de ductos PVC-TDP NØD` — distingue 4Ø6/6Ø6/9Ø6/12Ø6 por igualdad), suministro + tendido de cable (helper `urb:elec-cond-tokens` separa `3x185mm2`→`3x185 mm2` para que el score distinga calibres), excavación, relleno en arena (envolvente del banco − ductos), base granular B (excavación − envolvente), sobrantes, reposición, cinta y mandrilado. BT/AP emite solo tubería TDP (el APU del libro incluye excavación/relleno) + cable.
- **Capítulos alias por red** (`*urb-ppto-red-capitulo-alias*` + `urb:ppto-caps-de`): ELECTRICA-BT-AP también sirve "RED DE ALUMBRADO PÚBLICO" y ELECTRICA-MT sirve "OBRAS ELECTRICAS" — antes TODA fila de alumbrado caía huérfana porque el libro no tiene capítulo "red de baja tension". 7 consumidores del mapeo actualizados a lista.
- **Cajas CS274/CS275** en todos los catálogos (`*mp-caja-elec-list*` nuevo, extremos, elementos, diálogos, colores/capas, `mp:tipo-caja-de`); cajas, luminarias y postes ahora generan fila UN 1.0 (`urb:ppto-rows-puntos`); `*mp-lum-list*` ganó "DECOLED 100 W" (la luminaria real del libro).
- **Numeración automática de elementos eléctricos** (`mp:elec-id-prefix` + `mp:next-elec-id`): MT no tenía numeración (alumbrado sí) — los diálogos de caja/elemento proponen el siguiente ID libre por tipo (C276-01, C274-01, P-01...) escaneando los bloques del dibujo; respaldo al insertar si el campo queda vacío.
- **Botón "Sendero"** (c:URBSENDERO, catálogo `*urb-send-tipos*`): 6 tipos por POLÍGONO CERRADO (mismo `urb:draw-closed-polyline` del andén) — sendero de trote, sendero ecológico, plazoleta en concreto, ciclorruta (azul, capítulo CICLORRUTA), rampa en concreto de ancho variable (capítulo RAMPA PEATONAL, receta reducida) y **bioswale/biorretenedor clasificado a RED PLUVIAL** (pedido explícito). Cada tipo lleva receta de actividades reales (modo AREA×factor / PERimetro×factor), relleno sólido de color, xdata `URB_SENDERO`, y familia paramétrica SENDERO/BIOSWALE (AREA/PERIMETRO/UNIDAD) para actividades del usuario.
- **Hint de sección en el match por zona** (`urb:ppto-match-zona` + campo 12 de fila cruda): responde la pregunta del usuario "si tengo una cicloruta en un parque, ¿cómo sé que queda bien clasificada?" — con Zona parque marcada, la ciclorruta cae en la sección CICLORUTA de su parque y el sendero en SENDEROS PEATONALES; el hint es preferencia con fallback, no jaula. Verificado contra el libro real (fila del match dentro del rango de la sección correcta).
- **Desempate de actividades duplicadas**: el libro repite la MISMA actividad con texto idéntico en varias secciones (tubería 2Ф3" TDP, caja CS-274, luminaria, árbol por parque) y el empate de score las dejaba huérfanas para siempre — ahora un duplicado de texto idéntico no bloquea (se toma la primera, igual que el match exacto).
- **ENCODING — incidente y lección**: el archivo es **UTF-8 sin BOM y así lo lee Civil 3D 2023**. Se convirtió a ANSI creyendo la convención vieja y la suite cazó el destrozo (CONT-E y ARBOL huérfanos por U+FFFD); además el Edit tool reescribe UTF-8 y corrompió los 0xF3. Restaurado de backup + re-aplicadas las ediciones. NUNCA convertir a ANSI.
- **Suite**: 66 checks (15 nuevos de esta ronda: profundidades normativas por ubicación, catálogos, numeración, tokens de conductor, match exacto del banco Ø, excavación MT, cable 3x185 vs 3x120, alias de capítulos, tubería AP, CS-274, catálogo de senderos, hint de zona×2, filas de sendero end-to-end 10×3 m). Invariantes intactos: TRITURADO 43.457, CONT-D 3.528, 112 filas mías, idempotencia 266=266.
- Ribbon: botón **Sendero** (icono propio camino curvo) en Crear→Urbanismo; DLL `UrbCantRibbon2023_v4480.dll`.
- **v4.50.0 (mismo día, cuarta ronda)**: PREFABRICADO PERIMETRAL en andenes y senderos — `urb:build-prefab-anillo` construye un anillo de bordillo/sardinel/cañuela alrededor del contorno cerrado como bloque prefabricado estándar (offset controlado por ÁREA, independiente del sentido del polígono); sección nueva "Prefabricado perimetral" (tipo/posición/ancho) en las ventanas de andén y sendero; **Externo** = fuera del área dibujada (área intacta), **Interno** = franja dentro que se DESCUENTA: el andén la resta vía vínculo xdata `URB_PREFAB_ANILLO` (handle del andén) y el sendero salta las filas PER de su receta (el prefab cuenta su propio ML) y resta perímetro×ancho del área. Verificado: anillo 10×3 externo = 26.00 ML / 5.20 m²; sendero interno concreto 2.48 m³ con bordillo omitido. Suite 75/75; commit `1987c72`.
- **v4.49.0 (mismo día, tercera ronda de feedback)**: capas PROPIAS por tipo de sendero (color ByLayer; catálogo con campos capa+espesor); ventana de sendero estilo andén (popups tipo/etapa/subetapa + sección movimiento de tierras; excavación = área×espesor, fila agregada a trote/ecológico/plazoleta con el texto real del ppto, 12.0 m³ verificados en el E2E); **Localización dinámica** (mismo comando ZONAPARQUE): ventana con zonas marcadas + conteo, Seleccionar/Quitar/Marcar, y filtro por etapa/subetapa que deja seleccionados los elementos de TODAS las especialidades (`urb:element-etapa`, espejo de lectura de `urb:apply-etapa-subetapa`; senderos también en el cambio de etapas en lote). Suite 73/73; commit `2740e50`.
- **v4.48.1 (mismo día, feedback en vivo del usuario)**: RAMPA gana ventana previa (`urb:rampa-dialog`: etapa/subetapa/ancho 2.00-3.00/fondo; antes todo por línea de comandos con etapa fija 1/1); ribbon reorganizado — panel Editar → **Elemento** (botón Elemento + desplegable **Ubicacion** con Etapas y **Localizacion**, el antiguo Zona parque que sale de Cantidades). El "no aparece Sendero" reportado era la sesión de Civil abierta desde antes de instalar el bundle. Suite 67/67; DLL `v4481`; commit `a0b9a31`.
- **v4.50.1 (mismo día, quinta ronda — pedido explícito del usuario sobre su imagen de un tramo real)**: RECORTE VISUAL del tramo hasta el borde del círculo del pozo, para que el número quede legible — `mp:tramo-visual-gap` calcula el hueco (radio de `*mp-vis-radius*`) solo cuando AMBOS extremos están vinculados a un pozo/caja; `mp:insert-cant-tramo` inserta el bloque desde el punto ya desplazado con la longitud visual recortada, y `mp:sync-tramo-values` reaplica el mismo recorte cada vez que el tramo se re-sincroniza (crear, EDITAR, o el pase en lote). **Las CANTIDADES no cambian**: `mp:derive-tramo-values` sigue recibiendo los puntos p1/p2 REALES (centro a centro), el recorte es puramente de la geometría insertada. Suite 75/75; commit `92c0af8`.
- **LOTE RESIDUAL — red sanitaria completa modelada en el master real** (`work\lote_residual\`, fuera del repo git — son datos de un proyecto, no código del plugin): a pedido del usuario, se leyó el xref RESIDUAL de `URB_MASTER_GENERAL.dwg` y se modeló la red con los comandos del plugin (headless, sin diálogos). Dos corridas, cada una con piloto sobre copia + backup antes de tocar el archivo real:
  - **Corrida 1 (red principal, 13:43)**: 87 pozos + 90 tramos de alcantarillado sanitario. El usuario había dejado un **tramo guía** (pozos 32→33) modelado a mano para indicar qué cotas clave tomar — el script lo detecta, NO lo duplica (reutiliza sus 2 pozos para enlazar los tramos vecinos) y compara sus cotas contra las que el lote asocia automáticamente: cota inicial idéntica (2557.83), diámetro idéntico (8"), cota final con 2 cm de diferencia (el lote tomó la etiqueta de llegada al pozo 33, el usuario la de salida — pendiente de decidir el criterio).
  - **Corrida 2 (domiciliarias + aguas tratadas, 15:27)**: +61 pozos (51 DOM + 10 tratadas, renombradas TRAT-01…TRAT-10 porque su atributo POZO traía una cota en vez de un ID) y +170 tramos (60 domiciliarios con diámetro 6" por defecto cuando no hay etiqueta; tratadas en 24" encadenadas). Los 91 elementos de la corrida 1 no se duplicaron (dedupe por handle de extremos). Se aplicó el recorte visual (v4.50.1) a los 261 tramos resultantes.
  - **Total en el master: 150 pozos sanitarios + 261 tramos**, todos con movimiento de tierras calculado contra la superficie real (SUP_TN), listos para sumar al presupuesto. Sin etapa/subetapa (pedido explícito — pendiente asignarlas cuando el usuario decida, vía el filtro de Localización o el botón Etapas en lote).
  - Lección técnica quemada en la memoria del proyecto: dentro de la definición de un xref, las capas y los bloques anidados llegan con el nombre **prefijado** (`"RESIDUAL|SAN_POZO_PROY"`) — hay que quitar el prefijo antes de comparar.

### Cierre de la sesión 2026-08-21 (partes 28, versiones v4.48.0 → v4.50.1)

Sesión larga con 6 rondas de feedback en vivo del usuario sobre 3 frentes: **redes secas** (excavación normativa CODENSA, numeración automática, cajas CS274/275), **senderos y parques** (ciclorruta/plazoleta/bioswale por polígono cerrado, capas propias, prefabricado perimetral externo/interno, filtro de Localización multi-especialidad) y **modelado de datos reales** (la red sanitaria completa del proyecto Maiporé, 150 pozos + 261 tramos, sobre el master de producción). Todo verificado con la suite headless (66 → 75 checks según la ronda, siempre 0 fallos) antes de instalar, y cada versión documentada aquí y en el handoff antes de pasar a la siguiente. Ver el handoff (`..\..\handoffs\urbanismo-externo.md`) para el detalle completo versión por versión, incluidos los aprendizajes de la corrida en el master real.

### 2026-08-13 (parte 27) — v4.23.7 → v4.23.12: la saga completa del MOSTRAR (crash de la paleta resuelto por diseño + tabla ancha persistida)

Iteración en vivo con el usuario tras la parte 26. Resumen de las 6 versiones:

- **v4.23.7**: freno al servicio Idle (sondeaba en CADA evento) + telemetría en ambas mitades hacia `%TEMP%\urbcant_ribbon.log`. La telemetría demostró que la mitad LISP no era el problema (MOSTRAR = 31 ms sobre la VIA-01 real).
- **v4.23.8**: la telemetría ubicó el crash DENTRO de `ExecuteInCommandContextAsync` (fatal nativo, sin excepción capturable) → **ese API queda VETADO en Civil 3D 2023**; disparo por `SendStringToExecute` tras soltar el bloqueo.
- **v4.23.9**: seguía crasheando → causa real: el **sondeo periódico de PropertySets choca con la paleta de Propiedades activa** (carrera nativa). Sondeo eliminado (solo eventos) + aviso "Bloque sin atributo MEMORIAS (esquema viejo): pase EDITAR".
- **v4.23.10**: segunda reincidencia con la paleta → regla del protocolo: **cambiar el diseño, no seguir parchando**. El desplegable AEC nativo en Propiedades queda DESHABILITADO por defecto (reactivable con `URBCANT_MEMORIAS_PROP=1`); el control queda en `QMEMORIAVIA`/`QMEMORIATRAMO` y el campo de texto MEMORIAS de la sección Atributos de Propiedades (MOSTRAR/OCULTAR escritos a mano — la vía del reactor LISP, estable).
- **v4.23.11** (fallida, cazada por el harness): MOSTRAR intentaba RECALCULAR la tabla ancha; sin superficie fallaba **y dañaba el movimiento guardado**.
- **v4.23.12 (final)**: arquitectura correcta — las filas de la tabla ancha (VERIFICACION MOVIMIENTO DE TIERRAS, la que el usuario identifica como SU tabla) se **persisten en `ldata URB_VIA_AUDIT`** cada vez que el cálculo real corre (crear/EDITAR/botón Verificación); `urb:draw-road-audit-table` es un dibujador puro; MOSTRAR pinta desde lo guardado al instante (sin superficie, sin eje obligatorio, sin efectos secundarios) y OCULTAR la retira. Vía sin datos guardados → memoria resumida + aviso de correr Verificación una vez. Validado sobre copia del maestro real: **10 checks TODO-OK** (persistir → 9 columnas → ocultar → mismo ciclo a través del bloque empacado → VIA-01 sin datos cae a 2 columnas con la rasante intacta).

### 2026-08-13 (parte 26) — v4.23.6: el desplegable de MEMORIAS en Propiedades ya dispara su comando (cerrado el pendiente de Codex)

Retomado el pendiente que Codex dejó al agotar créditos: el desplegable nativo `MEMORIAS` (Propiedades → Datos extendidos, MOSTRAR/OCULTAR — tabla de verificación en vías, tabla de movimiento de tierras en tramos) no ejecutaba nada al cambiarlo.

- **Causa (diagnóstico de Codex, confirmado en su código)**: el servicio .NET sincroniza propiedad→atributo DENTRO del evento `Idle` con el documento bloqueado; el reactor LISP encola el pedido y difiere `vla-SendCommand "ACTUALIZARMEMORIAS"`, pero Civil 3D **descarta** ese envío en ese contexto.
- **Arreglo (`UrbCantRibbon2023_v4236.dll`)**: el servicio marca `_commandPending` al escribir el atributo y, al salir del `using` del bloqueo (y de `_busy`), dispara `ACTUALIZARMEMORIAS` vía **`ExecuteInCommandContextAsync`** (el mecanismo soportado para correr comandos desde contexto de aplicación), con respaldo `SendStringToExecute` si fallara. Marca en el log: "ACTUALIZARMEMORIAS disparado en contexto de comando" (`%TEMP%\urbcant_ribbon.log`).
- **Validación (protocolo v3)**: la mitad LISP completa en headless — vía sintética empacada → MOSTRAR → tabla visible → OCULTAR → retirada → MOSTRAR → reconstruida (**7 checks TODO-OK**, harness en `work\memorias_dropdown\`). La mitad .NET compila e instala (DLL con nombre versionado: entra sin cerrar la sesión abierta). El clic real del desplegable solo se valida en vivo; criterio de falsación: si la tabla no aparece, mirar el log — si la línea del disparo está, el problema es del comando LISP; si no está, del evento .NET.
- Nota: función solo-2023 por ahora (el proyecto 2025 no compila `URB_AEC_PROPERTY` — NuGet sin AecPropDataMgd); en 2025 siguen los comandos QMEMORIAVIA/QMEMORIATRAMO y el atributo editado a mano.

### 2026-08-13 (parte 25) — v4.23.5: Protocolo v3 de verificación — y en su estreno cazó TRES bugs latentes de núcleo

A pedido del usuario ("cuando me des una respuesta, que esté validada; perfecciona tu autoevaluación"), se formalizó el **Protocolo v3** en [TESTING_CIVIL3D.md](TESTING_CIVIL3D.md) §3d — 5 pasos vinculantes antes de decir "arreglado": (1) confirmar la versión que produjo la evidencia, (2) reproducir el flujo EXACTO del usuario y comprobar que el harness falla contra el código viejo, (3) arreglar la clase (síntoma imposible por diseño; fallas silenciosas → mensajes que se explican), (4) validar con invariantes + peor caso en UNA corrida headless, (5) entregar con números y criterio de falsación.

- **Librería común** `C:\Users\juanbusper\Documents\URBANISMO\work\_lib\verify_lib.lsp`: constructores sintéticos (rect, anillo curvo de peor caso, corredor curvo, vía completa con rasante según convenciones v4.23.x) y asserts (`vlib:check`, conservación de área, conteos por rol, detector de huecos, resumen `TODO-OK/HAY-FALLOS`). Un harness nuevo queda en 20-40 líneas. `urb:ensure-trusted-path` ahora también confía `Documents\URBANISMO\work\...` en cada carga (sin diálogo de seguridad).
- **La autoprueba de estreno falló en el caso de vía y la investigación por sondas encontró TRES bugs reales de núcleo** (ninguno del harness). Autoprueba final: **8 checks, 0 fallos, TODO-OK** (clic sobre vía empacada con eje borrado → 99.500 exacto).
  1. **EL MAYOR — `or` de AutoLISP devuelve `T`, NO el valor** (probado empíricamente: `(or nil "abc") → T`, distinto de Common Lisp). Todo `(setq x (or a b))` usado como "toma el primero que exista" entregaba el símbolo `T`. Barrido completo del archivo: 7 sitios corregidos a cadenas de `if` — el eje en `urb:road-axis-recover` (devolvía `T` como eje → "unable to get ObjectID: T"), `boundary` tras empaquetar la vía (**la causa raíz del histórico aviso "memoria: areas-17 | data: nil"**), el eje en la rasante de andén "Vía creada" y en la tabla de verificación (**por eso pedía seleccionar el eje aunque el handle fuera válido**), `urb:prefab-data`, `c0/c1` de la rasante de diseño, y el matching ID/firma de filas Excel en 2 sitios (`(cdr found)` con `found=T` tronaba). Los booleanos legítimos (`if (or ...)`) quedaron intactos.
  2. **`urb:set-xdata-strings` nunca soportó agregar una SEGUNDA app a una entidad**: agregaba la app nueva como un segundo grupo `-3`; en entidades planas `entmod` se quedaba solo con el grupo nuevo (**borraba la xdata de las otras apps devolviendo "éxito"**) y en entidades ActiveX el `entmod` fallaba — por eso el eje-display de las vías quedaba sin `URB_VIA_EJE` y la recuperación dentro del bloque no encontraba nada. Misma familia del bug de julio (URB_VIA_MOV borrado), corregido entonces solo del lado de lectura. Fix: un solo grupo `-3` fusionado. Con checks permanentes en la autoprueba (entidad plana y ActiveX).
  3. **`handent` de un handle BORRADO devuelve el ename muerto (no nil)** — cada candidato del recover ahora se valida por separado (`urb:usable-axis-or-nil`) para que los respaldos (eje enlazado por via-id / copia dentro del bloque) sí se intenten.
- Además: los `.scr` de verificación cierran con `_.QUIT _N` (con `_Y` en un dibujo modificado AutoCAD pide nombre de archivo y la instancia queda zombi — se mataron 5 zombis de las corridas de hoy). Lección de sondas: un paso frágil del harness (resta sobre un posible error) trunca el archivo de resultado — todo sub-paso va con `vlib:call`.

### 2026-08-13 (parte 24) — v4.21.2 → v4.23.4 (sesiones Codex) + consolidación de vuelta a Claude Code

El usuario trabajó el 2026-08-12/13 con Codex (OpenAI) sobre este mismo repo (8 commits después de la parte 23, todos ya en `main`) y al agotarse sus créditos pidió que Claude Code absorbiera la metodología y el estado. Resumen de lo que dejaron esas versiones (detalle en cada mensaje de commit):

- `v4.21.2` corrigió franjas curvas, toperol y eje de vía; `v4.22.0` auditoría de curvas, tierras, rasantes y pozos; `v4.22.1` simplificó vías y configuración de tramos; `v4.23.0` corrigió rasantes y **memorias de cálculo**; `v4.23.1` pozos y control de memorias; `v4.23.2` agregó el **desplegable de memorias en la cinta** (UrbCantRibbon.cs +143 líneas, DLL 2023 y 2025 recompiladas); `v4.23.3` y `v4.23.4` corrigieron tramos y estabilizaron las tablas de memorias (UrbCantRibbon.cs +453 líneas más, ~600 líneas nuevas de lsp).
- **DLL con nombre versionado** (`UrbCantRibbon2023_v4232/3/4.dll` + `PackageContents.xml` apuntando al nombre nuevo): así se actualiza la cinta sin cerrar la sesión abierta (la DLL vieja queda cargada; la nueva entra al reiniciar). Adoptado como práctica estándar.
- Su laboratorio de verificación vive en `C:\Users\juanbusper\Documents\URBANISMO\work\<tema>\` (harness `.lsp` + `.scr` + resultado `.txt` por tema). Metodología completa documentada en [TESTING_CIVIL3D.md](TESTING_CIVIL3D.md) §3c.
- **PENDIENTE que Codex dejó a medias** (su último mensaje, 2026-08-13 14:26, ya sin créditos): el comando diferido del desplegable de memorias **no se ejecuta cuando se lanza desde el evento `Idle`** — Civil 3D descarta el `SendStringToExecute`. Ejecutado directamente, la tabla se crea bien. Su plan era sustituir ese mecanismo por la interfaz directa .NET–AutoLISP registrada expresamente. Nada de ese plan quedó en un commit (árbol limpio), así que es el primer trabajo de la próxima ronda.
- Consolidación 2026-08-13 (Claude Code): los 9 commits de Codex estaban SOLO locales — se hizo `git push` (`efb234e..894167f` → GitHub). Bundle instalado verificado en v4.23.4 (idéntico al repo). Regla nueva: `git log origin/main..HEAD` al iniciar cada sesión.

### 2026-08-12 (parte 23) — v4.21.1: cobertura garantizada en la modulación curva

El usuario volvió a reproducir el hueco negro con la versión 4.21.0 realmente instalada y cargada. La copia del repositorio y la de `ApplicationPlugins` tenían el mismo SHA-256; Civil 3D había iniciado después de la instalación y la captura era posterior, por lo que el reintento de la parte 22 no cubría todos los casos.

- **Causa corregida**: 4.21.0 trasladaba la banda completa para romper la tangencia y solo verificaba si `vla-Boolean` lanzaba una excepción. Una operación podía terminar con región degenerada o el `HATCH SOLID` podía fallar después; aun así la banda se contaba como válida. Además, trasladarla podía abrir una separación microscópica contra la banda vecina.
- **Recorte sin separaciones**: `urb:clip-stripe` ahora ensancha simétricamente ambos bordes con solapes progresivos `0 / 0.5 / 1.5 / 4 / 10 mm`; las bandas se superponen ligeramente en vez de apartarse. `urb:region-usable-p` exige un área real positiva después del booleano.
- **Relleno transaccional**: nuevo `urb:add-solid-hatch-safe` elimina cualquier hatch parcial si falla `AppendOuterLoop`, una propiedad o `Evaluate`. `urb:decorate-composite-stripe` solo acepta la banda si existen tanto la región útil como el sólido; si no, elimina la tentativa y repite con mayor solape.
- **Cobertura final garantizada**: el detalle 20x20 conserva debajo una única base blanca del contorno completo (`BASE_FILL`). Las bandas grises/blancas quedan por encima mediante el orden de dibujo; si ACIS rechazara todos los reintentos de una banda excepcional, nunca vuelve a verse el fondo negro. Esta base es exclusivamente visual y no modifica las cantidades almacenadas.
- **Mantenimiento**: `PackageContents.xml` se sincronizó de `AppVersion=4.17.7` a `4.21.1`.

### 2026-08-12 (parte 22) — v4.21.0: eje de vía auto-recuperado, aviso de vía sin rasante y bandas sin huecos

El usuario confirmó que la orientación del andén curvo ya sale como debe. Tres arreglos de seguimiento:

1. **Eje identificado solo** (`urb:road-axis-recover`): al usar "Vía creada" para la rasante del andén ya NO pide seleccionar el eje — se resuelve con el handle guardado, la cache de sesión o **reconstrucción automática** desde el contorno crudo dentro del bloque de la vía (la única LWPOLYLINE cerrada de la definición, mismo algoritmo del eje automático de la creación). Solo si todo falla lo pide. La misma recuperación la usa `urb:cota-from-via`, así que clickear una vía como cota también funciona aunque su eje original haya desaparecido.
2. **"No se pudo leer la cota" al clickear una vía — explicado**: si la vía clickeada se reconoce pero NO tiene rasante calculada (el movimiento de tierras se omitió al crearla, como en la vía de prueba del usuario según su log anterior), ahora lo dice explícito: "La via seleccionada NO tiene rasante calculada... Editela y asignele cotas, o seleccione un texto de cota" — antes fallaba en silencio y caía a digitar.
3. **Pedazo en blanco en el andén curvo**: el booleano de una banda falla cuando el borde de la franja pasa exacto por un vértice del contorno (tangencias con las cuerdas del arco) y la banda se saltaba en silencio. `urb:clip-stripe` ahora reintenta con corrimientos de ~1.5 mm (`0 / +1.5 / -1.5 / +4 mm`) que rompen la tangencia sin efecto visible.
- Pregunta del usuario sobre el EMPATE en el cruce vía nueva / vía anterior: el clic sobre la vía anterior se proyecta a SU eje (cota de su rasante en ese punto) y el mismo clic se proyecta al eje de la vía nueva como estación inicial — clickeando exactamente la junta (osnap intersección/endpoint) el empate es exacto.

### 2026-08-12 (parte 21) — v4.20.0: andén curvo con dirección marcada por el usuario, vía-bloque reconocida en el picker y memoria blindada

La rampa de la parte 20 quedó bien (confirmado por el usuario). Tres arreglos sobre lo que siguió fallando:

1. **Andén curvo seguía diagonal** — la parte 20 evitó la partición en dos ejes, pero el eje único lo seguían eligiendo las cuerdas del arco (familia diagonal dominante). Solución definitiva con control del usuario: si el contorno tiene **arcos**, al crear el andén se piden **2 puntos PARALELOS a las bandas del andén/rampa vecino** (con osnap sobre una junta del módulo adyacente el paralelismo es exacto — lo que pidió: "paralelo a la modulación del vecino"). Enter = automático (bandas paralelas al lado recto más largo del contorno, típicamente la tapa compartida). El eje interno (perpendicular a las bandas) queda guardado en el contorno como xdata `URB_ANDEN_AXIS` y **sobrevive a EDITAR**; `urb:create-composite-loseta` lo respeta por encima de clusters y particiones. Andenes curvos viejos sin xdata: mismo automático (lado recto + 90°) vía `urb:anden-straight-edges-angle` (los arcos no votan).
2. **El picker de cotas no reconocía la vía creada** — al clickear una vía EMPACADA, `nentsel` devuelve la geometría anidada del bloque (sin xdata); la xdata `URB_VIA` vive en el INSERT contenedor, que `nentsel` entrega en su 4º elemento. Nuevo `urb:cota-from-pick` prueba la entidad clickeada Y todos sus contenedores — usado por el picker N-cotas y por el auto-detect de "Textos por capa".
3. **Aviso "memoria: areas-17 | data: nil" (el consp nil de siempre, ahora con rastro)** — tras empaquetar la vía en bloque, la relectura de `URB_VIA` sobre el bloque devolvió nil y la memoria se armaba con data vacía. Ahora la xdata se lee ANTES de empaquetar y se usa de respaldo si la relectura falla. (La vía en sí siempre quedó bien; solo fallaba el resumen.)
- Respuesta operativa documentada: tras cada actualización del `.lsp` hay que **cerrar y reabrir** AutoCAD (o `APPLOAD` del archivo en Contents); la cinta (.dll) solo exige cerrar todo cuando se recompila, cosa que no pasó en las partes 19-21.

### 2026-08-12 (parte 20) — v4.19.0: rampa con fondo por clic al bordillo, auto-detect también en "Textos por capa" y curva de andén SIN diagonal

Tres correcciones tras la prueba en vivo del usuario (pantallazos de rampa, log de vía y andén curvo):

1. **Rampa — lado + fondo en UN clic**: el clic del "lado del andén" ahora se hace **sobre el BORDILLO** donde termina la rampa (con osnap Nearest cae exacto). La distancia perpendicular de ese clic al eje de la rampa **es el fondo** — sin seleccionar entidades (solo el punto), así funciona igual con bordillos en bloques, xrefs o líneas sueltas (lo que mató los intentos anteriores con `entsel`/`nentsel`). Un clic pegado al eje (<0.5 m) solo define el lado y el fondo queda el configurado (3.50 o el digitado con la opción Fondo).
2. **Vía — el auto-detect ahora también vive en "Textos por capa"** (el modo por defecto, que fue el que el usuario usó): el primer prompt acepta un texto de cota (comportamiento de siempre: barre la capa), **o una VÍA ya creada** (toma su rasante en el punto del clic), **o una etiqueta con número** (MLeader/etiqueta Civil). Si el clic no fue texto, en vez de cancelar con "El objeto no es texto ni MText", cambia solo a **cotas seleccionadas**: sigue pidiendo la cota final y las intermedias con el mismo picker del modo Pendiente (`urb:pick-road-cotas-loop`, refactor con semilla). El resultado viaja como marcador `("PICKED" picks ...)` que interceptan los 4 consumidores: creación de vía, EDITAR vía, rasante de andén por alineamiento y reconstrucción de rasante de vías viejas.
3. **Andén — diagonal en la curva ARREGLADA de raíz**: la partición en dos ejes (`urb:two-axis-split-data`, pensada para andenes en L) se disparaba también en curvas porque las cuerdas en que se subdivide un arco inventaban un segundo "eje dominante" → la zona curva salía con bandas diagonales. Regla nueva (`urb:lwpoly-has-arcs-p`): si el contorno tiene **arcos reales (bulge)** es una curva continua → **un solo eje** (el del tramo recto dominante) y la curva solo recorta; la partición en dos ejes queda solo para L de esquinas rectas (sin bulges).
- Verificado headless: v4.19.0, `has-arcs-p` distingue polilínea con arco vs recta, el polígono con arco efectivamente genera >1 cluster (la causa raíz confirmada), funciones nuevas definidas. Pendiente prueba visual del usuario.

### 2026-08-12 (parte 19) — v4.18.0: rampa manual, cotas auto-detect, andén sin Modulación y etapas OCULTAS (solo .lsp, sin cambios .NET)

Round multi-disciplina pedido por el usuario (pantallazos de rampa, diálogo de vía, andén en curva y diálogo de andén):

1. **Rampa — selector eliminado**: el prompt "Seleccione el BORDILLO o eje..." se quitó por completo (v6). El usuario reportó que no reconocía el fondo hasta el bordillo y el fondo tocaba digitarlo igual. Flujo actual: punto inicial sobre el borde de la vía → dirección del eje → ancho/fondo por teclado (el fondo digitado ya extendía bien el módulo completo).
2. **Vía — picker de cotas con AUTO-DETECCIÓN** (`urb:pick-road-cotas` + nuevo `urb:cota-from-via`): al seleccionar la cota inicial/final (o las intermedias de pozos), el mismo clic reconoce solo si se tocó (a) un texto/etiqueta de cota en CUALQUIER capa o xref (vía `TextString`/DXF 1 + `mp:last-decimal-number`), o (b) una **vía ya creada** — en ese caso toma la cota de la RASANTE de esa vía en el punto exacto del clic (proyección al eje guardado + records de rasante, con dirección Inicio/Final). Sin preseleccionar tipo; si nada se puede leer, se digita.
3. **Andén — diálogo depurado**: se eliminó la sección **Modulación** completa (Orientación/Extremo — "no está funcionando para nada"; internamente creación usa Automatico/Normal y EDITAR conserva el sentido de cada andén) y el popup **Calcular** del movimiento de tierras (ahora SIEMPRE se calcula; solo queda cómo: Superficie TN + Rasante desde). La orientación recta en curvas ya estaba implementada de la sesión anterior (la curva solo recorta, sin abanico).
4. **Andén — nueva fuente de rasante "Cotas seleccionadas"** (`urb:select-anden-picked-grade`): para andenes SIN vía creada y sin depender de una capa de cotas. Se selecciona o dibuja el eje de referencia y se clickean N cotas con el mismo picker auto-detect del punto 2 (texto en cualquier capa/xref, vía creada o digitada); cada cota se proyecta al eje en el punto del clic → rasante por tramos (`urb:picked-cotas-to-stations`, modo RAW). Queda de tercera opción junto a "Via creada" y "Alineamiento + cotas".
5. **Etapas OCULTAS (no grises)**: con etapas deshabilitadas (Ajustes → Etapas y subetapas), los tiles etapa/subetapa **ya no se emiten en los DCL de CREACIÓN** (andén, vía, prefabricado, zona verde, tramo red/MT/BT, punto hidro, caja eléctrica, elemento eléctrico, accesorio acueducto) y todos los `get_tile`/fills quedan condicionados (un tile ausente truena). Los diálogos de EDICIÓN (`edit_*` de redes, gestor de etapas, comando ETAPAS) conservan los tiles (grises), controlado con `*mp-dialog-edit-mode*` que fijan los `mp:write-dcl*`. El gestor de etapas invalida los caches DCL (`*urb-*-dcl-ok*`, `*mp-dcl-*-ok*`) al cambiar el toggle para regenerarlos al vuelo. `mp:gettile` blindado con `vl-catch-all` para tiles ausentes tras `done_dialog`.
- Sin cambios en C# (DLLs intactas). Verificado headless: versión, DCLs generados con etapas ON (etapa presente, Modulación/Calcular ausentes) y OFF (etapa ausente en creación, presente en edición), funciones nuevas definidas.

### 2026-08-12 (parte 18) — Ribbon v4: Urbanismo externo (3 niveles), sin botón Perfiles y rampa por nentsel

Tres ajustes pedidos por el usuario (con su pantallazo de Ajustes ya funcionando):

1. **Botón "Perfiles" eliminado** del panel Configuración (duplicaba "Perfiles estratigraficos de vias" que vive dentro de Ajustes). Queda solo Ajustes.
2. **Jerarquía Crear v3**: `[Urbanismo externo]` → **Urbanismo** (Via, Anden, Rampa, Zona verde, Prefabricado) | **Redes humedas** (Acueducto → Tramo/Accesorios; Alcantarillado → Tramo/Pozo sanitario; Pluvial → Tramo/Sumidero/Pozo) | **Redes secas** (Media tension → Tramo MT/Tramo BT/Camara; **Alumbrado** separado → Tramo alumbrado/Luminaria). Hasta 4 niveles de navegación en el mismo espacio con "<".
3. **Rampa corta — causa encontrada**: el selector del bordillo usaba `entsel`, pero el sardinel creado por el propio plugin es un BLOQUE (y las vías de proyecto suelen ser xref) → devolvía el INSERT, no una curva, y caía EN SILENCIO al modo manual (por eso "seleccionaba el bordillo" y la rampa quedaba corta). Ahora usa `nentsel` (perfora bloques/xrefs, patrón ya probado en este proyecto) y acepta el bordillo O el eje: cualquier línea hasta donde deba llegar la rampa; el punto inicial se proyecta sobre esa curva y el módulo completo (bordillos, losetas, adoquín) nace desde ahí.
- Verificado headless: lsp OK, sin pestaña legada, DLL v4 "Tab construida: 4 paneles". Pendiente visual del usuario (jerarquía nueva + rampa seleccionando su sardinel-bloque).

### 2026-08-11 (parte 17) — PESTAÑA DOBLE RESUELTA DE RAÍZ: la copia fantasma del Autoloader

Con Civil 3D cerrado por el usuario se pudo instalar el DLL nuevo y cazar la causa REAL de la pestaña doble: cuando el Autoloader cargó el cuix como ComponentEntry (parte 12), **lo COPIÓ a la carpeta Support del perfil** (`%AppData%\Autodesk\C3D 2023\enu\Support\cantidades.cuix` — visto en la clave de registro `Loaded`) y esa copia, fuera del bundle, revivía la pestaña vieja en cada arranque sin que el instalador la tocara.

- Se eliminaron las copias fantasma (cuix + bak + mnr) de Support y el instalador ahora **barre `cantidades*` de todas las carpetas de perfil de Autodesk** (excepto ApplicationPlugins) en cada corrida — protege también al computador del 2025.
- El instalador quedó resiliente al DLL bloqueado (avisa "cierre AutoCAD" y continúa con lsp+íconos) — regla operativa confirmada: actualizar la CINTA requiere AutoCAD cerrado.
- **Verificación final headless**: arranque limpio → lsp OK, `menugroup CANTIDADES` AUSENTE (pestaña única) y DLL nuevo "Tab construida: 4 paneles" (con Excel agrupado en botón desplegable y descarga COM de respaldo). Pendiente solo el vistazo del usuario.

### 2026-08-11 (parte 16) — Ribbon v3: descarga COM del cuix, Excel agrupado y gestor de etapas en DIÁLOGO

Tercer reporte del usuario: seguía la pestaña doble, Excel quedó "suelto" en Cantidades, y el gestor de etapas debía ser un cuadro de diálogo con desplegables (no menú de línea de comandos).

1. **Pestaña doble — causa real**: el auto-CUIUNLOAD por comando abría el DIÁLOGO de CUIUNLOAD (FILEDIA=1) y nunca descargaba. Ahora el DLL descarga el partial legado por **COM** (`Application.AcadApplication` → `MenuGroups` → `.Unload()` via `dynamic`, con `Microsoft.CSharp`/`System.Core` agregados al build 2023) en el primer Idle — sin comandos, sin diálogos, y quita el registro del perfil permanentemente.
2. **Excel agrupado**: `RibbonSplitButton` "Excel" (IsSplit=false, sin sincronizar → botón-menú puro) dentro de Cantidades con las 4 acciones adentro (Exportar/Actualizar/Vincular/Desvincular).
3. **Gestor de etapas como DIÁLOGO** (`urb_etapas` en el DCL principal): toggle "Habilitadas", desplegable de etapa → edit_box con sus subetapas (editable, "Guardar subetapas"), "Quitar etapa", bloque "Nueva etapa" (nombre + subetapas + "Agregar"), "Restaurar original". El diálogo se reabre tras cada operación para refrescar listas; el llenado del popup del gestor es DIRECTO (sin urb:fill-popup, que lo pondría gris con etapas deshabilitadas). Helpers: `urb:etapas-subs-string/replace-at/remove-at`.
4. **Instalador resiliente a DLL bloqueado**: si AutoCAD está abierto, el DLL cargado no se puede reemplazar — ahora avisa "cierre AutoCAD y corra INSTALAR.bat de nuevo" y el resto (lsp, íconos) se instala igual. REGLA OPERATIVA: las actualizaciones de la cinta requieren TODAS las ventanas de AutoCAD cerradas al instalar.
- **Verificado headless (parte LISP)**: DCL urb_etapas generado con sus 5 controles, helpers definidos, subs-string("3")="3,3A,3B". El DLL nuevo quedó compilado (2023 y 2025) pero NO instalado aún por el bloqueo — el usuario debe cerrar Civil 3D → INSTALAR.bat → reabrir.

### 2026-08-11 (parte 15) — Ribbon v2 (jerarquía Urbanismo), Cantidades+Excel y gestor de etapas/subetapas

El usuario confirmó que la pestaña .NET apareció (con la vieja del cuix duplicada al lado — su sesión tenía el cuix bloqueado cuando el instalador intentó borrarlo) y pidió el rediseño completo:

1. **Doble pestaña**: el DLL ahora auto-descarga el partial CUIX legado (`CUIUNLOAD CANTIDADES` vía SendStringToExecute en el primer Idle con documento). Fix inmediato manual: comando `CUIUNLOAD` → CANTIDADES → Unload.
2. **Panel Crear con jerarquía de 2 niveles** (todo en el mismo espacio, botones GRANDES con el nombre debajo — "los símbolos se ven muy pequeños" resuelto): `[Urbanismo]` (ya con ícono propio) → nivel 1: Via, Anden, Rampa, Zona verde, Prefabricado, Red sanitaria, Red pluvial, Acueducto, Media tension → subniveles: sanitaria(Tramo, Pozo), pluvial(Tramo, Sumidero, Pozo), acueducto(Tramo, Accesorios), media tensión(Tramo MT, Tramo BT, Alumbrado, Camara, Luminaria). Botón "<" para subir de nivel.
3. **Cantidades absorbe Excel**: Cuadro, Memoria, Verificacion, Exportar, Actualizar (grandes) + Vincular/Desvincular (chicos). Incluir/excluir y CSV redes salieron de la cinta (los comandos QALCANCE/QCSV siguen escribibles). Panel Excel eliminado → 4 paneles.
4. **Comandos nuevos** `TMT`/`TBT`/`TAP` (tramos media tensión, baja tensión y alumbrado — las funciones internas ya existían en el menú de redes).
5. **Ajustes depurado**: salieron "Cargar perfiles base faltantes" y "Diagnosticar y migrar redes" (funciones siguen por código); entró **"Etapas y subetapas"**.
6. **Sistema de etapas/subetapas editable y des/habilitable** (`urb:etapas-manager-command`): catálogo persistido en el dibujo (`URB_ETAPAS_CATALOGO`, mismos mecanismos que los perfiles) con Agregar/Quitar etapa, editar Subetapas (parser de listas con comas/;/espacios), Restaurar, y **Habilitar/Deshabilitar global** (`URB_ETAPAS_ACTIVO`). Al deshabilitar, los popups etapa/subetapa de TODOS los diálogos de creación quedan grises — centralizado en `urb:fill-popup` y `mp:fill-popup` (un solo punto, cubre urb y mp), y los elementos se crean con la etapa por defecto. `urb:subetapas-for` ahora lee del catálogo (deja de estar quemado en código); `*urb-etapa-list*`/`*mp-etapa-list*` se refrescan al cargar y tras cada edición.
- **Verificado headless**: DLL "Tab construida: 4 paneles" ✓; lsp con TMT/TAP/manager definidos ✓; catálogo 9 etapas y sub("3")=3 ✓; toggle deshabilitar/habilitar ✓; agregar etapa "10" (2 subetapas) persiste y restaurar vuelve a 9 ✓; parser de subetapas ✓. Pendiente visual del usuario: reiniciar, verificar pestaña única con la jerarquía nueva, y probar el gestor en Ajustes.

### 2026-08-11 (parte 14) — FASE .NET: ribbon dinámico dual 2023/2025 (aprobada por el usuario)

El usuario aprobó arrancar la capa .NET con alcance quirúrgico: SOLO la cinta, con el comportamiento que pidió (oprimir "Urbanismo" y que los 14 símbolos de creación aparezcan EN EL MISMO ESPACIO del panel — imposible en CUIx, posible con ribbon dinámico). El motor sigue 100% en el lsp; también confirmó que el otro computador usa Civil 3D **2025** (esta máquina 2023) → soporte dual.

- **`ribbon-net/UrbCantRibbon.cs`**: fuente C# ÚNICO para ambas versiones, en sintaxis C#5 A PROPÓSITO (sin `$""`, sin `?.`) porque la variante 2023 se compila con el csc.exe integrado de Windows. Estructura: `IExtensionApplication` → construye la pestaña vía `Autodesk.Windows` (espera `ComponentManager.ItemInitialized` si el ribbon no existe aún); panel Crear dinámico (`ShowUrbanismoButton` ↔ `ShowCreateIcons`: 14 botones solo-ícono en 2 filas + botón "<" para compactar, swap en vivo del `RibbonPanelSource`); paneles Editar/Cantidades/Excel/Configuración fijos; cada botón dispara su comando LISP con `SendStringToExecute`; íconos PNG cargados desde `Contents/net/iconos/`; log de diagnóstico en `%TEMP%\urbcant_ribbon.log`.
- **Compilación dual**: `compilar_2023.ps1` (csc.exe de Windows + DLLs de referencia del AutoCAD 2023 instalado + WPF del GAC — System.Xaml vive en la raíz del Framework64, no en la subcarpeta WPF) → `bundle/net/UrbCantRibbon2023.dll`. `compilar_2025.ps1` (dotnet SDK 8 — instalado con winget — + paquetes NuGet oficiales `AutoCAD.NET`/`.Core`/`.Model` 25.0.0, SIN necesitar AutoCAD 2025 instalado; ojo: el meta-paquete 25.0.0 tiene un pin roto a `Core 25.0.0-V058`, se resuelve referenciando los 3 paquetes directo) → `bundle/net/UrbCantRibbon2025.dll`. Ambas DLL quedan VERSIONADAS en el repo → el otro PC solo hace pull + INSTALAR.bat, nunca compila.
- **`PackageContents.xml` con 2 bloques `<Components>`** (R23.0-R24.2 → lsp + DLL 2023; R25.0+ → lsp + DLL 2025): cada AutoCAD carga solo lo suyo. **El cuix ya NO se instala** (la pestaña la dibuja el DLL; si el cuix quedara, saldría duplicada por el registro de parciales del perfil) — el instalador lo borra del bundle instalado; el fuente cui/cuix sigue en el repo como respaldo.
- **Verificado en 2023 (esta máquina)**: log del DLL tras arranque limpio: "Initialize" → "Tab construida: 5 paneles" ✓. Pendiente: verificación visual del usuario (reiniciar Civil 3D 2023) y primera verificación de la variante 2025 en el otro computador (pull + INSTALAR.bat; si la pestaña no aparece, revisar `%TEMP%\urbcant_ribbon.log`).
- Diferencias operativas de la capa .NET (documentadas al usuario): cambios de la CINTA requieren recompilar (script de 1 comando) y reiniciar AutoCAD; el motor LISP sigue recargándose al instante como siempre. `CARGARCINTA` quedó obsoleto (cuix retirado).

### 2026-08-11 (parte 13) — PESTAÑA FUNCIONANDO (confirmada por el usuario) + íconos de los 27 botones

- **CONFIRMADO EN VIVO**: la pestaña CANTIDADES apareció con sus 6 grupos y 27 botones tras `CARGARCINTA` ("Customization file loaded successfully. Customization Group: CANTIDADES"). El camino ganador: cuix empaquetado a mano + CUILOAD por comando.
- **Íconos**: `bundle/generar_iconos.ps1` dibuja los 27 íconos (PNG 32x32 + 16x16, transparentes, paleta legible en tema oscuro) con GDI+ — reproducible, sin binarios a mano. Los 54 PNG viven en `bundle/iconos/` y se EMBEBEN dentro del cuix (`armar_cuix.ps1` los agrega al zip + declara png en Content_Types). Cada macro del `.cui` los referencia con `<SmallImage Name="cant_x_16.png" />` / `<LargeImage Name="cant_x_32.png" />` (formato confirmado contra acetmain.cuix).
- Trampa de PowerShell 5.1 anotada: `New-Object Tipo(args)` con expresiones dentro se parsea mal — usar `[Tipo]::new(...)`.
- Flujo completo de edición de interfaz desde ahora: editar `cantidades.cui` (o `generar_iconos.ps1`) → `armar_cuix.ps1` → `INSTALAR.bat` → `CARGARCINTA` en la sesión abierta (o reiniciar).
- Pendiente: confirmación visual de los íconos por el usuario (CARGARCINTA en su sesión).

### 2026-08-11 (parte 12) — Ribbon round 3: la pestaña la fusiona el AUTOLOADER y TRUSTEDPATHS se auto-repara

El usuario reportó que seguían el diálogo de seguridad y la pestaña ausente. Dos causas de fondo encontradas:

1. **TRUSTEDPATHS se pierde**: AutoCAD REESCRIBE esa variable al cerrar con lo que tenía en memoria — agregarla por registro desde afuera se borra si había una sesión abierta (exactamente lo que pasó). Fix definitivo: `urb:ensure-trusted-path` — el propio lsp, al cargar (ya ADENTRO de AutoCAD), agrega la carpeta del bundle a la variable viva con `setvar`; AutoCAD la persiste al cerrar. Tras el primer "Always Load" del usuario, ninguna sesión vuelve a preguntar. (El instalador conserva además el ajuste por registro para el caso sin sesiones abiertas.)
2. **La pestaña no se fusionaba al workspace**: cargar el cuix por COM (`MenuGroups.Load`) registra el menugroup pero NO muestra la pestaña. Quien sí la fusiona automáticamente es el **Autoloader** cuando el cuix está declarado en `PackageContents.xml` — se agregó el `ComponentEntry` de `./Contents/cantidades.cuix` (la pieza que faltaba). `urb:ensure-ribbon` queda como respaldo.
- Nota de verificación: la corrida headless quedó bloqueada por el MISMO diálogo de seguridad pero para el helper `_claude_verify_tmp.lsp` en CANTIDADES (la confianza de BLOQUES PPTOS no cubre subcarpetas) — diagnosticado trayendo la ventana al frente y capturando pantalla. Se intentó cerrar por automatización, pero el usuario estaba usando el computador y se abortó la interacción de escritorio por respeto (instancia de prueba cerrada). **La verificación visual final queda en manos del usuario**: reiniciar Civil 3D, "Always Load" si pregunta (1 vez), y buscar la pestaña CANTIDADES.
- Lección para futuras verificaciones headless: los helpers temporales en CANTIDADES pueden disparar el diálogo de seguridad si TRUSTEDPATHS fue reescrito — colocar el helper en la carpeta del bundle instalado (que el lsp auto-repara como confiable) o dar "Always Load" una vez.

### 2026-08-11 (parte 11) — Ribbon round 2: diálogo de seguridad resuelto y CUIX empaquetado a mano

El usuario probó y reportó: (a) diálogo "Unsigned Executable File" al cargar el lsp del bundle, (b) la pestaña no aparecía (abrió el CUI buscándola).

- **Diálogo de seguridad**: la carpeta del bundle no estaba en TRUSTEDPATHS (BLOQUES PPTOS sí lo estaba de antes, por eso el load directo nunca molestó). El instalador ahora agrega `%AppData%\...\UrbanismoCantidades.bundle\Contents` a TRUSTEDPATHS de TODOS los perfiles de AutoCAD del usuario vía registro (5 perfiles actualizados en esta máquina). `INSTALAR.bat` quedó como envoltorio delgado de `instalar_bundle.ps1` (una sola base de código de instalación).
- **HALLAZGO CLAVE — por qué no aparecía la pestaña**: el `.cui` monolítico se cargó bien (menugroup + macros), pero al convertirlo a `.cuix` AutoCAD **descartó el RibbonRoot completo en silencio** — el convertidor de `.cui` monolíticos es de la era pre-ribbon (2006-2009) y no migra ribbon SIN IMPORTAR el esquema. Se comprobó dos veces (RibbonRoot.cui de 479 bytes = `<RibbonRoot />`), incluso con el esquema correcto copiado de acetmain.cuix (`MenuMacroID`, `Id="AcRibbonCommandButton"`, `Name`, `ModifiedRev` — el primer intento además usaba `MacroID`, que no existe).
- **Solución definitiva**: empaquetar el `.cuix` DIRECTAMENTE (es un zip OPC): `bundle/armar_cuix.ps1` extrae las secciones MacroGroup y RibbonRoot de `cantidades.cui` (que queda como FUENTE legible), arma las 6 partes (Header.cui, MenuGroup.cui, RibbonRoot.cui, [Content_Types].xml, _rels/.rels, Menu_Package_Info.xml — estructura copiada de acetmain.cuix de Express Tools, que muestra su pestaña sin sección de workspace) y las zipea con nombres de entrada con `/`. Flujo tras editar la interfaz: editar `cantidades.cui` → `armar_cuix.ps1` → `INSTALAR.bat`.
- `urb:ensure-ribbon` carga el `.cuix` (nunca el `.cui`); el instalador limpia residuos de intentos anteriores (`cantidades.cui`, `.bak.cuix`, `.mnr` viejos) del bundle instalado.
- **Verificado headless**: AutoCAD limpio → lsp autocargado → menugroup CANTIDADES OK → y el `.cuix` instalado conserva **6 paneles / 27 botones** después de la carga (sin conversión destructiva; AutoCAD solo generó sus `.mnr` de recursos, normal). Pendiente SOLO la confirmación visual del usuario tras reiniciar. Si la pestaña no aparece sola: clic derecho sobre el ribbon → Show Tabs → CANTIDADES (2 clics), o CUI → workspace.

### 2026-08-11 (parte 10) — Pestaña CANTIDADES en el ribbon

El usuario aprobó el esquema (mockup en sesión) y pidió la pestaña llamada CANTIDADES (no URBANISMO). Arquitectura: el ribbon depende del lsp, nunca al revés — cada botón solo dispara un comando público; toda la lógica sigue en el lsp y funciona igual sin ribbon.

- **Comandos públicos nuevos** (bloque "COMANDOS PUBLICOS DEL RIBBON" al final del lsp, envoltorios de 1 línea): Crear `VIA ANDEN RAMPA ZONAVERDE PREFABRICADO`; Redes `TSANITARIO TPLUVIAL TACUEDUCTO POZOSAN POZOPLU SUMIDERO CAMARA ACCESORIO LUMINARIA`; Editar `EDITAR ETAPAS`; Cantidades `QCUADRO QMEMORIA QVERIFICACION QALCANCE QCSV`; Excel `QEXCEL QVINCULAR QACTUALIZAR QDESVINCULAR`; Config `PERFILES AJUSTES`. También sirven escritos a mano. `urb:remove-legacy-commands` dejó de borrar los nombres que ahora son oficiales (c:VIA, c:ANDEN, c:PREFABRICADO, c:SUMIDERO, c:LUMINARIA salieron de su lista).
- **`bundle/cantidades.cui`**: CUI parcial XML escrito a mano (MenuGroup CANTIDADES: 27 macros + RibbonRoot con 6 paneles — Crear, Redes, Editar, Cantidades, Excel, Configuracion — y la RibbonTabSource; botones sin ícono por ahora, solo texto). Los instaladores copian el .cui a Contents del bundle.
- **`urb:ensure-ribbon`** (corre al cargar el lsp): si el menugroup CANTIDADES no está, carga el .cui vía COM (`MenuGroups.Load` — no necesita contexto de comando, funciona durante el autoload del bundle). Busca primero la copia instalada del bundle (`%AppData%...\Contents\cantidades.cui`) y de respaldo `findfile`.
- **Verificado headless de punta a punta**: AutoCAD limpio sin cargas manuales → lsp autocargado, todos los comandos definidos, y `(menugroup "CANTIDADES")` registrado (el XML pasó el cargador). **Pendiente de verificación visual del usuario**: que la PESTAÑA aparezca en la cinta (el merge al workspace no se puede ver headless). Si no aparece sola: CUI → Partial Customization Files → CANTIDADES → arrastrar la pestaña al workspace actual, una sola vez.
- Botones sin íconos propios en esta v1 (texto solo); diseñar íconos BMP/PNG queda como pulido posterior.

### 2026-08-14 — Migración al esquema CLAUDE: el proyecto vive en `CLAUDE\proyectos\URBANISMO EXTERNO\`

Parte de la reorganización general del usuario (centro de control `VARIOS\CLAUDE\` en Drive, compartido entre sus 2 PCs):

- **Nueva ruta**: `VARIOS\CLAUDE\proyectos\URBANISMO EXTERNO\` — se movió TODO el contenido de `BLOQUES PPTOS\CANTIDADES\` sin excepción. En `BLOQUES PPTOS\` solo queda el `.lsp` viejo de MAIPORE (fuera del repo, igual que antes).
- **Git consolidado**: el `.git` que vivía aparte en `REPOSITORIO CODIGOS\urbanismo-cantidades\` ahora está DENTRO del proyecto como repo normal (se eliminó el puntero `gitdir:` y el `core.worktree`). Verificado: historial intacto (HEAD v4.23.18), árbol limpio, remoto GitHub OK. La carpeta de REPOSITORIO CODIGOS quedó eliminada.
- **Memoria de Claude propia**: banco en `CLAUDE\memoria\URBANISMO EXTERNO\` (junction por PC). Las memorias de urbanismo que vivían en el banco de SINCO se movieron aquí.
- **Civil 3D no se tocó**: el bundle instalado en `%AppData%` sigue igual. Tras el próximo cambio de código, correr `INSTALAR.bat` desde la ruta nueva.
- **OJO en el otro computador**: (1) correr el bloque de junctions de `CLAUDE\README.md`, (2) correr `INSTALAR.bat` desde la ruta nueva, (3) si el Startup Suite referenciaba `BLOQUES PPTOS\CANTIDADES\urbanismo_cantidades.lsp`, quitar esa entrada y depender solo del bundle.

### 2026-08-11 (parte 9) — Reorganización: todo el proyecto vive en `BLOQUES PPTOS\CANTIDADES\`

A pedido del usuario ("organices mejor esa carpeta... crees otra carpeta que se llame cantidades y dentro metas todo lo que necesites"):

- **Nueva estructura**: `BLOQUES PPTOS\CANTIDADES\` contiene TODO el proyecto — `urbanismo_cantidades.lsp`, `PROGRESS.md`, `TESTING_CIVIL3D.md`, `bundle/`, `INSTALAR.bat`, `instalar_bundle.ps1`, `.gitignore`, el puntero `.git`, y `backups/` (adentro quedaron también los 20 `urbanismo_cantidades_backup_*.lsp` que estaban sueltos en la raíz). En la raíz de BLOQUES PPTOS solo quedó el `.lsp` viejo de MAIPORE (fuera del repo desde ahora — sus funciones ya están integradas al principal; se dejó en el disco por si el Startup Suite lo referencia, borrable cuando el usuario confirme).
- **Git**: el worktree pasó a ser `CANTIDADES` — puntero `.git` relativo (`gitdir: ../../REPOSITORIO CODIGOS/urbanismo-cantidades/.git`) y `core.worktree = ../../../BLOQUES PPTOS/CANTIDADES`. Como los archivos se movieron JUNTO con la raíz del worktree, git no ve cambios de rutas (historial limpio, sin renames). Verificado desde la carpeta nueva.
- **Verificado headless**: el bundle sigue cargando solo, el `load` directo desde `CANTIDADES` funciona sin diálogo de seguridad (la subcarpeta hereda la confianza), e `INSTALAR.bat` corre desde la nueva ubicación (exit 0, instalación recreada desde cero).
- **Política de PDFs** (pedido del usuario: "nos estamos llenando de pdfs"): verificación numérica primero; los PDFs visuales van SOLO a la carpeta temporal de la sesión de Claude, nunca a Drive. Se borraron los `_tmp_*.pdf` que sesiones anteriores dejaron en BLOQUES PPTOS. Documentado en TESTING_CIVIL3D.md sección 3b.
- **OJO en el otro computador**: la ruta del `.lsp` cambió a `...\BLOQUES PPTOS\CANTIDADES\urbanismo_cantidades.lsp` — si el Startup Suite o algún atajo apuntaba a la ruta vieja, actualizarlo (o mejor: correr `INSTALAR.bat` y depender solo del bundle).

### 2026-08-11 (parte 8) — Bundle de Autodesk Autoloader: instalación en 1 paso, base para comercializar

El usuario decidió el rumbo de producto: esto es el primer desarrollo, más adelante quiere ampliarlo (incluso a Revit) y comercializarlo. Decisión de arquitectura conversada: el LISP sigue siendo el motor de AutoCAD/Civil 3D para siempre (Revit no ejecuta LISP — el día que toque, se hace un núcleo C# compartido y adaptadores por plataforma; el conocimiento de negocio ya documentado se transfiere, no se pierde nada).

- **Nuevo `bundle/PackageContents.xml`**: manifiesto del formato Autodesk Autoloader (`ApplicationPackage`, Platform AutoCAD*, Series R23.0-R25.1, `LoadOnAutoCADStartup`). Es también el formato que exige la Autodesk App Store para vender.
- **Nuevo `instalar_bundle.ps1`**: copia el `.lsp` + manifiesto a `%AppData%\Autodesk\ApplicationPlugins\UrbanismoCantidades.bundle\` (carpeta confiable por defecto → carga automática al abrir AutoCAD/Civil 3D, sin APPLOAD ni carpetas confiables). **Reinstalar tras editar = correr el script y reiniciar AutoCAD.** En el otro computador: `git pull` + script. Para clientes futuros: se entrega la carpeta .bundle (o un zip/instalador) y se copia — sin git.
- En la máquina de desarrollo ambos caminos conviven: `(load ...)` directo para probar al instante, bundle para "publicar" (si ambos cargan, los comandos solo se redefinen — inofensivo).
- **Verificado headless**: AutoCAD lanzado SIN cargar el lsp manualmente → `c:URBANISMO` y `c:EDITAR` quedaron definidos solos por el autoloader, versión 4.17.7. Bundle instalado y funcionando en esta máquina.
- Pendientes de esta línea (fase 2): pestaña en el ribbon (CUIx parcial dentro del mismo bundle), compilación a VLX para proteger el código antes de distribuir a terceros, y estructura de monorepo (`autocad/`, `core/`, `revit/`) cuando llegue la expansión.

### 2026-08-11 (parte 7) — Round 5: rampa desde el bordillo, eje sin zigzag y sin clics de extremos

Cuarto reporte en vivo (la rampa salió "súper mal" — doble de larga, porque el punto inicial se marcó en el borde equivocado y la extensión de 3.86 m estiró todo el módulo; y el eje automático de una vía con cruces salió "súper torcido"):

1. **Rampa rediseñada — flujo DESDE EL BORDILLO**: 1) seleccionás el bordillo como entidad, 2) clic del punto inicial (se PROYECTA sobre el bordillo), 3) la dirección sale sola de la tangente del bordillo (un clic decide hacia dónde avanza), 4) ancho/fondo, 5) lado del andén. El módulo arranca EXACTO en el bordillo (v=0) por construcción — se eliminó toda la lógica de extensión (`ext` siempre 0; el parámetro queda por compatibilidad) y ya no hay manera de dejarlo corto ni de marcar el borde equivocado. Respaldo manual (puntos a mano) si se da Enter.
2. **Eje sin zigzag**: el emparejamiento de las 2 cadenas laterales era por fracción de longitud — con cadenas asimétricas (jogs de bocas de cruce, esquinas) las parejas se desalineaban y el eje salía en zigzag. Ahora cada punto de la cadena A se proyecta PERPENDICULAR (punto más cercano) sobre la cadena B, más un suavizado de promedio móvil de 3. Verificado con un contorno de 8 vértices con boca de cruce: eje recto de extremo a extremo (y ∈ [3.5, 4.5], la excursión local es el reflejo suavizado del jog real).
3. **Extremos AUTOMÁTICOS, sin clics** ("quiero que sea más fácil"): los 2 bordes extremos ahora se detectan solos para CUALQUIER forma — el par de bordes no adyacentes cuyos puntos medios quedan más lejos entre sí (los jogs de cruce quedan descartados porque sus puntos medios son interiores). e1 = el más cercano al primer vértice dibujado. Los 2 clics de extremos desaparecieron del flujo.
4. **Cerco final al "consp nil"**: el rastro dijo "areas", pero todas las expresiones de esa ventana son a prueba de nil — marcadores afinados por campo (areas-17/18/14/15/aritmetica) y el aviso ahora también vuelca los primeros 180 caracteres de `data`: la próxima aparición lo entrega sin escapatoria.

### 2026-08-11 (parte 6) — Round 4: tope de rampa, flujo de vía reordenado y cerco al "consp nil"

Tercer reporte en vivo, con registro de comandos que resolvió el misterio de la rampa:

1. **Rampa**: el registro mostró "El bordillo quedo a 3.85 m del arranque; se ignora (tope 3.00 m)" — la selección del bordillo YA funcionaba perfecto, pero el tope arbitrario de 3 m descartaba una distancia real de 3.85 m. Tope subido a 10 m (con el bordillo como entidad la distancia es real; el tope solo protege de selecciones absurdas) y mensajes unificados (antes salían dos contradictorios). Verificado: rampa con ext=3.85 construida, AREA_M2=10.30 exacta.
2. **Flujo de vía reordenado** (queja: "está largo y no tiene orden"): ahora 1) contorno, 2) eje, 3) sentido del abscisado, 4) superficie y cotas. Antes el sentido y la referencia de cotas se preguntaban ANTES de dibujar nada. Nota al usuario: para cotas en cualquier capa/xref sin seleccionar capa, el modo de cota del diálogo debe ser "Pendiente" (el picker de N cotas lee la etiqueta clickeada sin importar capa ni xref — es exactamente lo que pidió); "Textos por capa" queda para quien sí tenga una capa uniforme.
3. **"consp nil" de la memoria**: el blindaje de la parte 5 funcionó (la vía quedó creada y salió el aviso). Sigue sin reproducirse headless (probado también con datos de 23 campos sin movimiento). Se instaló un rastro fino `*urb-memoria-stage*` (areas/abscisas/perfil/geometria/movimiento/fin) que el aviso imprime — la próxima corrida en vivo dirá la sección exacta. Huella descubierta: "consp X" viene de car/cdr/nth sobre un valor no-lista; ninguna de 14 funciones nativas candidatas produce "consp nil" con nil, así que el valor ofensor no es nil directo (misterio pendiente, ya sin costo para el usuario).
4. Del registro también se confirmó que YA funcionan en vivo: eje automático con arcos (2 clics en extremos), sardineles por cadenas con huecos y Si/No por costado (4 tramos creados), y la migración de tablas.

### 2026-08-11 (parte 5) — Round 3 tras segunda prueba en vivo: arcos, tablas legadas y blindaje

Segundo reporte en vivo (con registro de comandos completo, clave para el diagnóstico):

1. **Rampa aún corta tras "seleccionar el bordillo"**: causa probable definitiva — con `getpoint`, un clic sin osnap cae en cualquier parte y la distancia sale mal. Ahora el bordillo se **SELECCIONA como entidad** (`entsel`): si es una curva, la extensión es la distancia perpendicular real desde el arranque de la rampa hasta esa curva (da igual dónde se toque); si no es curva (xref), se usa el punto del clic. Tope 3 m y mensaje siempre.
2. **Migración de tablas solo borró 1 de varias**: las más viejas no tienen xdata (se creaban sin etiquetar). Barrido extra por CAPA: todo `ACAD_TABLE` suelto en `URB-VIA-TABLA` se retira (esa capa solo la usan las tablas generadas). Verificado: tabla sin xdata en esa capa → la migración la borra.
3. **Eje automático con contornos de arcos/N vértices** (el fallback a dibujar a mano molestaba): nueva infraestructura de **cadenas laterales** (`urb:lwpoly-vertex-bulges`/`urb:road-end-edges`/`urb:road-side-chains`/`urb:road-axis-from-chains`): el contorno se parte en 2 bordes extremos + 2 cadenas (conservando bulges); 4 vértices rectos = extremos automáticos, si no el usuario **toca los 2 bordes extremos** (2 clics); el eje = promedio punto a punto de las cadenas (muestreo ~2 m), arrancando junto al primer vértice dibujado. Verificado headless: contorno con arcos en ambos costados → eje exacto por el centro.
4. **Sardineles generalizados a las cadenas** (ya no solo cuadriláteros): por costado pregunta **[Si/No]** (por si un costado ya tiene sardinel de otra vía — pedido explícito), resalta la cadena, huecos por pares de clics proyectados sobre la cadena (`vlax-curve`), tramos construidos muestreando la cadena cada 0.25 m (sigue arcos). Espesor fijo 0.20 (pregunta eliminada). Reutiliza los extremos del eje (`*urb-road-end-edges*`) sin repreguntar. Verificado headless: sardinel sobre cadena con arco → bloque OK.
5. **Cotas de pozos que no se dejaban leer**: el picker usaba `entget`/assoc 1, que devuelve nil en MLeaders/etiquetas Civil 3D — ahora lee `vla-get-TextString` (como el picker de tramos de red) con fallback a entget.
6. **Crash "bad argument type: consp nil"** al final de crear la vía (tras "Regenerating model"): no se pudo reproducir headless con datos completos sintéticos, así que la memoria final quedó **blindada** (`vl-catch-all`): si falla, la vía queda creada igual, sale un aviso con el mensaje real del error (para cazarlo la próxima vez) y un alert básico. Además el `*error*` de crear-vía ahora limpia los globales del flujo (cotas/estaciones/extremos) para que un error no contamine la siguiente vía.

### 2026-08-11 (parte 4) — Round 2 tras prueba en vivo: 3 correcciones

El usuario probó la parte 3 en vivo y reportó: (1) la extensión de la rampa al bordillo NO funcionó (seleccionó el bordillo y quedó corta; su imagen de referencia no llegó al chat); (2) quitar la pregunta del espesor del sardinel (siempre es 20 cm); (3) las tablas de verificación siguen en las vías viejas.

1. **Rampa-bordillo robusta**: el cálculo anterior solo aceptaba el clic hacia el lado de la vía según `side-sign`, y un clic con el signo "equivocado" se descartaba **en silencio** (ext=0 sin mensaje) — causa más probable del reporte. Ahora la distancia perpendicular se toma en **valor absoluto** (da igual el lado), con tope de 3 m (un clic lejano se ignora con aviso) y **mensaje SIEMPRE**: "Modulo extendido X m..." o "Sin extension...". Verificado matemáticamente a 52° por ambos lados (0.35 y 0.42 exactos) + rampa rotada construida con ext.
2. **Espesor del sardinel fijo en 0.20** — pregunta eliminada.
3. **Tablas viejas: la causa real era que están EMPACADAS dentro del bloque de cada vía** (`urb:package-road` recoge todo lo etiquetado `URB_VIA_GEN`, tabla incluida) — un `ssget` de primer nivel no las ve, por eso la migración de la parte 3 no borró nada. Fixes: (a) `urb:purge-road-block-tables` purga las ACAD_TABLE de las definiciones de bloques `URB_VIA_*` (la única tabla posible ahí es la de verificación) y la migración la llama + regen; (b) la tabla nueva bajo demanda ya NO se etiqueta `URB_VIA_GEN` sino `URB_VIA_TABLA` (propia), para que el próximo EDITAR de la vía no la vuelva a tragar al bloque; (c) `urb:delete-road-audit-tables` reconoce ambos tags. Verificado headless reproduciendo el escenario exacto: tabla etiquetada empacada en un bloque URB_VIA_* → la migración la saca (1→0); borrado por handle propio/ajeno correcto.
- Nota operativa: esta corrida headless convivió sin problema con la sesión abierta del usuario (RESIDUAL.dwg) — confirma que los "cuelgues" nunca fueron de licencia, solo el `/b` roto de Git Bash.

### 2026-08-11 (parte 3) — 6 pedidos del usuario: rampa hasta el bordillo + 5 ajustes de vía

1. **Rampa hasta el bordillo**: nuevo clic OPCIONAL al crear la rampa ("Punto sobre el BORDE DEL BORDILLO de la via, Enter si arranca aqui"): si el punto inicial se marcó sobre el borde del andén pero el bordillo de la vía queda más allá, TODO el módulo (rampa, A81, toperoles, bordillos verticales) se extiende esa distancia (`urb:build-ramp` ganó el parámetro `ext`; v0=-ext reemplaza los arranques v=0). TOPEROL_ML/BORDILLO_ML/AREA_M2 incluyen la extensión. Verificado: con ext=0.40, AREA_M2=5.10 (3×1.70) y TOPEROL_ML=8.80 (2×4.40) exactos + PDF visual.
2. **Sardineles automáticos al crear la vía** (`urb:create-road-sardineles`, corre justo antes de empaquetar): pregunta [Si/No], espesor (<0.20>), y recorre los 2 costados LARGOS del contorno (4 vértices); en cada costado (resaltado en verde con grdraw) el usuario marca pares INICIO/FIN de los tramos SIN sardinel (bocas de cruce con otras vías) y Enter sigue; cada tramo restante se construye con `urb:build-prefab-from-reference` ("Sardinel", modo Exterior, hacia afuera de la vía — mismo bloque del comando Prefabricado, con etapa/subetapa de la vía). Verificado headless: un segmento de 18 m generó su bloque sardinel OK (la parte interactiva de marcar huecos queda para prueba en vivo).
3. **Eje automático central** (`urb:road-axis-from-boundary`): con alineamiento "Nuevo" ya NO se dibuja el eje antes — se dibuja el contorno primero y el eje se calcula solo: contornos de 4 vértices rectos, los 2 lados opuestos de menor suma son los extremos, el eje une sus puntos medios (LWPOLYLINE en URB-VIA), y arranca en el extremo más cercano al PRIMER vértice dibujado (dirección predecible para el abscisado). Contornos con más vértices o arcos → mensaje y se dibuja a mano como antes. Verificado: quad 40×7 en las dos orientaciones → eje exacto por el centro con la dirección correcta; pentágono → nil (fallback).
4. **Rasante con N cotas (pozos sobre la vía)**: el modo Pendiente ya no se limita a 2 cotas — `urb:pick-road-cotas` pide INICIAL, FINAL y luego "OTRA cota (Enter termina)"; con 2 se mantiene la pendiente lineal de antes; con 3+ cada clic se proyecta sobre el eje (`urb:picked-cotas-to-stations` → global `*urb-road-picked-stations*`) y la rasante queda POR TRAMOS (mismo mecanismo `urb:cota-at-axis-distance` del modo "Textos por capa", con `coverage=T`); el método queda "rasante por tramos (N cotas seleccionadas)". Verificado headless: 3 cotas proyectadas a d=2/20/40 exactos y las interpolaciones a mano cuadran (100.111 y 100.815).
5. **Tabla de verificación BAJO DEMANDA**: ya no se crea sola al crear/editar la vía (aparecía lejos del contorno). Nuevo botón en Cantidades: "Tabla de verificacion de via (desplegar)" (`urb:road-audit-table-command`): seleccionás la vía y el PUNTO donde la querés; recalcula con los datos guardados (mismo camino que EDITAR), borra la tabla anterior de esa vía (`urb:delete-road-audit-tables`, solo toca tablas etiquetadas URB_VIA_GEN) y la inserta ahí. Internamente `*urb-road-audit-point*` es el interruptor: nil = no se crea tabla.
6. **Migración de vías existentes (tablas)**: `urb:migrate-current-drawing` ganó la migración 2: retira TODAS las tablas de verificación generadas (URB_VIA_GEN) del dibujo al cargar el .lsp — las vías viejas quedan como las nuevas (sin tabla pegada) y cualquier tabla se re-despliega desde Cantidades. Verificado: con 0 tablas devuelve 0 sin tocar nada.

Pendiente de prueba EN VIVO del usuario (partes interactivas imposibles headless): el clic del bordillo en la rampa, el flujo completo de sardineles con huecos, el picker de N cotas, y el botón de tabla bajo demanda.

### 2026-08-11 (parte 2) — Rampa: superficie RECTANGULAR con modelación completa del andén, A81 limpios

El usuario marcó sobre el PDF de la parte 1 dos problemas: (rojo) los A81 seguían "modelándose mal" — la textura de la rampa les pintaba encima, porque la superficie era un TRAPECIO que llegaba hasta el borde exterior (su arista inclinada era la diagonal del A81, así que el triángulo inferior de cada A81 quedaba DENTRO del trapecio y recibía bandas/retícula); (verde) la superficie de la rampa debía llevar la modelación completa del andén como el fondo que "ya quedó bien" (losetas grises con retícula + adoquines en las blancas), no la retícula tenue uniforme sin sólidos.

- La superficie de rampa pasó de trapecio a **RECTÁNGULO entre los dos A81** (u=0.6→W+0.6, v=0→1.3): ya no toca los A81, que quedan como rectángulos limpios 0.30×1.30 con su diagonal (geometría intacta de la parte 13).
- El bucle de bandas ahora aplica **la misma textura del andén a rampa y fondo** (un solo `foreach` sobre las dos regiones): gris = sólido + retícula 0.20 doble; blanco = sólido + adoquín 0.10×0.20. Misma fase de bandas (bucle de u compartido) y mismo origen en u (0.3) → columnas de adoquín alineadas de corrido entre las dos zonas.
- `AREA_M2` ajustada: rectángulo W×1.30 (antes ½(W+0.6+W)×1.30 del trapecio).
- Verificado headless + PDF: censo de hatches exacto (4 sólidos blancos, 8 retículas de adoquín, 4 retículas de loseta, 6 sólidos grises, 3 de bordillo, 0 inesperados) y visualmente el PDF coincide con el marcado del usuario: A81 blancos limpios con diagonal, bandas de rampa gemelas y alineadas con las del fondo.

### 2026-08-11 — Pendientes 1 y 2 de la parte 14/15: bug de tipos en vía "Pendiente" + textura real del fondo de rampa

De vuelta en la primera máquina (todo sincronizado vía GitHub, archivo local idéntico al último push; los punteros de git quedaron con rutas relativas — ver "Estado del repo"). El usuario pidió trabajar los pendientes 1 y 2 para poderlos probar:

1. **Vía "Pendiente" con 2 cotas — BUG de tipos cazado por inspección (habría tronado en la primera prueba en vivo)**: `urb:pick-cota-value` guardaba lo que devuelve `mp:last-decimal-number`, que es un **STRING** ("2557.83"), y ese valor viajaba vía `*urb-road-picked-cotas*` hasta `urb:road-apply-linear-grade`, que hace aritmética directa (`(- cota-final cota0)`) → "bad argument type: numberp". Corregido con `atof` dentro del propio picker + eco en pantalla del valor leído ("Cota leida de la etiqueta: 2557.830") para que en la prueba en vivo se vea qué número tomó. También se corrigió la etiqueta del método: decía "conservada de la edicion anterior" aunque las cotas vinieran del picker — ahora distingue "cotas seleccionadas en el dibujo". Verificado por inspección que el resto de la cadena es sana: los samples usan estación relativa desde 0 (la interpolación `cota0 + pendiente×s` es correcta), en modo Pendiente `urb:road-cota-reference` devuelve capa vacía → 0 textos → `cota-coverage` nil → sí entra la rama de las cotas seleccionadas, y el global se limpia al final de `urb:create-road` pase lo que pase.
2. **Fondo de rampa con la textura REAL del andén**: la zona posterior (v=1.50→fondo) ya no lleva la retícula 0.20 uniforme sobre todo — ahora se recorta banda por banda (mismo bucle de fase que ya existía, bandas alineadas de corrido con la rampa) y cada banda recibe su textura de andén: **gris** = sólido gris + retícula 0.20 doble (como `urb:decorate-gray-stripe`), **blanco** = sólido blanco + juntas de adoquín 0.10 al eje y 0.20 perpendicular (como `urb:decorate-white-stripe`). El trapecio de la rampa se queda como estaba (retícula 0.20 + bandas grises), que es lo aprobado en la parte 13. Todo sigue en capa URB-RAMPA dentro del mismo bloque.
- **Verificación headless COMPLETA (mismo día, tras cerrar el usuario su sesión)**: (a) cadena del picker: MTEXT crudo `\pxt6;{\Fsimplex|c0;2559.63\P2557.83}` → 2557.830 REAL; (b) `urb:road-apply-linear-grade` con las cotas del proyecto (2557.83→2556.31 en 20 m): pendiente -7.60% y rasantes 2557.83 / 2557.07 / 2556.31 — coinciden con la mano; (c) `urb:road-resolve-grade` con `*urb-road-picked-cotas*` activo entra por la rama correcta y el método dice "cotas seleccionadas en el dibujo"; (d) rampa T2-3.00 fondo 4.00: 685 entidades y el censo de hatches dio EXACTO lo previsto (2 sólidos blancos + 4 retículas de adoquín color 8 en las 2 bandas blancas del fondo, 2 sólidos grises + 2 retículas 0.20 color 9 en las grises, 1 retícula del trapecio, 6 sólidos grises totales con toperoles, 3 sólidos del bordillo, 0 inesperados); (e) ploteado a PDF e inspeccionado visualmente: bandas del fondo alineadas de corrido con las de la rampa, adoquín visible en las blancas, toperoles punteados, A81 con diagonal, bordillo entre rampa y fondo. Nota de lectura: el sólido "blanco" (color 7) plotea NEGRO en papel — en pantalla se ve blanco, igual que el andén real.
- **CORRECCIÓN de diagnóstico (importante para futuras sesiones)**: el "cuelgue en la pantalla Start" de las instancias headless en esta máquina (2026-08-04 y hoy) NO era contención de licencia — era **Git Bash convirtiendo el switch `/b` en una ruta** (`C:/Program Files/Git/b`, conversión MSYS de argumentos que parecen rutas POSIX): AutoCAD lo interpretaba como un dibujo a abrir, sacaba un diálogo modal "Cannot find the specified drawing file" (el usuario lo vio en pantalla) y se quedaba esperando un clic para siempre. **Solución: lanzar acad.exe con script SIEMPRE desde PowerShell** (`Start-Process -ArgumentList '/b','"ruta.scr"'`), nunca desde bash. Con eso la instancia corre y cierra sola en ~2.5 min.

### 2026-08-09 (parte 15) — Empaquetado NATIVO del andén, vía "Pendiente" con 2 cotas tras el polígono, y migraciones automáticas

1. **Empaquetado del andén con `-BLOCK` nativo** (ataca "no queda en bloque / se demora"): `urb:package-anden` ahora arma el bloque con el comando nativo `-BLOCK` (mueve TODAS las entidades a la definición en una operación) en vez de `vla-CopyObjects` + borrado objeto-por-objeto vía COM — los dos costos de minutos en andenes grandes. Con fallback automático al camino COM si el comando falla (mensaje "Empaquetado nativo no disponible..."). En el fast-path se omite el bucle de borrado (los originales ya fueron movidos). Verificado: corredor 60×4 curvo con franjas offset → bloque de 10,901 objetos, 0 sueltas, atributos OK, 16.8s total (build 9.5s); en andenes de 100k+ piezas la diferencia vs COM debe ser de minutos.
2. **Vía modo "Pendiente" (a pedido, con corrección del usuario)**: PRIMERO se delimita el polígono de la vía (contorno) y DESPUÉS se seleccionan DOS cotas, una por costado/extremo (`urb:pick-two-road-cotas`/`urb:pick-cota-value`, parser `mp:last-decimal-number`, con getreal de respaldo si el texto no se puede leer) → pendiente lineal entre ambas vía global `*urb-road-picked-cotas*` que `urb:compute-road-earthworks` toma con prioridad. Se limpia al terminar la creación. No probado interactivamente (nentsel) — pendiente de prueba del usuario.
3. **Migraciones automáticas** (`urb:migrate-current-drawing`): corre al cargar el .lsp y al abrir el menú URBANISMO, idempotente. Primera migración: tablas de verificación `ACAD_TABLE` en URB-VIA → URB-VIA-TABLA. Patrón establecido: cada cambio de capas futuro agrega aquí su migración para que lo ya creado se actualice solo al actualizar la versión.

### 2026-08-09 (parte 14) — PENDIENTES para la próxima sesión (feedback del usuario con capturas)

1. **Vía con alineamiento "Nuevo" + rasante "Pendiente"**: simplificar el flujo a (1º) dibujar el eje de la vía y (2º) seleccionar DOS cotas, una en cada costado/extremo, para calcular la pendiente lineal entre ambas (hoy el modo Pendiente pide los datos de otra forma). Revisar `urb:create-road` / flujo de cotas.
2. **Migración de tablas existentes**: botón (en Configuración) que busque las tablas de verificación ya creadas (`ACAD_TABLE` en capa URB-VIA con título "VERIFICACION MOVIMIENTO DE TIERRAS") y las mueva a `URB-VIA-TABLA`.
3. **Rampa**: la captura del usuario muestra los síntomas de la versión ANTERIOR (retroceso 0.20 contra el bordillo + A81 triangular) — se le pidió recargar el .lsp y reprobar antes de tocar nada. Mejora pendiente sí real: la textura del FONDO del módulo debe igualar al andén de verdad (bandas blancas con retícula de adoquín 0.10×0.20 como `urb:decorate-white-stripe`, no solo la retícula 0.20 doble uniforme) — comparar contra la foto del andén real que envió.

### 2026-08-09 (parte 13) — 4 ajustes de rampa tras prueba real del usuario

1. **A81 = cuadrado con diagonal** (no triángulo relleno): rectángulo de 0.30×1.30 en `URB-RAMPA-A81` + la línea diagonal (el borde inclinado de la rampa) dentro.
2. **La rampa llega hasta el bordillo** ("el rojo"): el trapecio arranca en v=0 (antes había un retroceso de 0.20 con línea de sardinel, eliminado); desarrollo v=0→1.30.
3. **El fondo del módulo lleva la modelación del andén**: zona posterior (v=1.50→fondo) con bandas gris 0.80/blanco 1.00 + retícula 0.20, con la MISMA fase en u que la superficie de la rampa (bandas alineadas de corrido entre rampa y fondo).
4. **"Viga de confinamiento" era en realidad BORDILLO**: las 2 verticales de 0.10 y la horizontal de 0.20 van en la capa existente `URB-BORDILLO` (solo se crea si no existe, para no pisar el color del proyecto); capa URB-RAMPA-VIGA eliminada; atributo `VIGA_ML` renombrado a `BORDILLO_ML`.
- Verificado por PDF (horizontal + rotada espejada): los 4 ajustes coinciden con el marcado del usuario.
- Nota de proceso: un `sed` sin archivo de entrada en un heredoc de bash se queda leyendo stdin para siempre — colgó una llamada; cuidado al encadenar.

### 2026-08-09 (parte 12) — Rampa por COMPONENTES según el marcado del usuario + respuesta sobre vía sin cotas propias

El usuario marcó sobre la foto del plano las 4 partes de la rampa y pidió subdividirlas por capas pero unidas en un solo bloque:

- **AMARILLO — superficie de rampa**: el trapecio lleva el MISMO patrón del andén (bandas gris 0.80 / blanco 1.00 a lo largo + retícula 0.20), partido con `urb:clip-stripe` sobre la región del trapecio. Capa URB-RAMPA.
- **NARANJA — toperol en los costados**: las franjas laterales de 0.20 a todo el fondo ahora van en capa `URB-ANDEN-LOSETA-TOPEROL-20X20` con relleno gris y PUNTOS reales (círculos 4 columnas por tableta, tono blanco).
- **VERDE — vigas de confinamiento**: nueva capa `URB-RAMPA-VIGA` (color 9): 2 verticales de 0.10 junto a cada toperol (todo el fondo, en el hueco de 0.10 que ya mostraba la disección del plano) + 1 horizontal de 0.20 entre rampa y andén (v=1.30-1.50).
- **MORADO — prefabricado A81**: nueva capa `URB-RAMPA-A81` (color 8): las 2 cuñas triangulares inclinadas que flanquean la rampa (entre el borde inclinado del trapecio y la viga vertical).
- Atributos nuevos del bloque: `TOPEROL_ML` (2×fondo), `VIGA_ML` (2×fondo + ancho+0.6), `A81_UND` (2). Nueva `urb:ramp-frame-uv` (local→marco rotado, para clip-stripe y símbolos).
- **Verificado por PDF**: T2-3.00 horizontal y T1-2.00 rotada 30° espejada — los 4 componentes coinciden con el marcado del usuario sobre la foto.

**Vía sin alineamiento ni cotas propias (pregunta del usuario)**: confirmado en `urb:road-resolve-grade` que la vía soporta rasante por **pendiente lineal entre cota inicial y cota final** ("cota X → cota Y (pendiente Z)"). Flujo recomendado: dibujar el eje por el corredor, crear la vía con rasante "Alineamiento + cotas" y seleccionar las etiquetas de cota de las DOS vías existentes en cada empalme — el programa interpola linealmente entre ambas y calcula el movimiento de tierras contra la superficie. Si se necesita quiebre intermedio, agregar un texto de cota en ese punto y seleccionarlo también.

### 2026-08-09 (parte 11) — Rampa peatonal según la composición REAL de U-201 + click de dirección

El usuario confirmó que la curva quedó bien y pidió 2 ajustes de rampa. Se disecó la composición interna de los 5 bloques `B RAMPA T1/T2` de U-201 (el espécimen sin rotar `T2 - 3.00MT - Andén 4.00MT` dio las medidas exactas):

- **Geometría real del plano** (reemplaza la inventada de central+aletas 0.65 a todo el fondo): franjas laterales de **0.20 m a todo el fondo** con relleno sólido; superficie de rampa **TRAPEZOIDAL** de W+0.60 contra la vía (T2-3.00 → 3.60, la medida que señaló el usuario) cerrando a W al fondo de rampa con **1.10 m de desarrollo** (v=0.20→1.30); banda inferior 1.30–1.50 y junta a 1.70; el resto del fondo es andén normal (la rampa NO ocupa todo el fondo). Ancho total del módulo = W+1.20. Nueva `urb:ramp-poly-pts` (polilínea cerrada desde puntos locales) para el trapecio. `urb:build-ramp` reescrita; ahora ancla en u=0 desde el punto inicial (ya no centrada).
- **Flujo**: punto inicial → eje → ancho [2.00/3.00/Fondo] → **click del lado hacia donde va la rampa** (como el lado del toperol; reemplaza la palabra clave "Lado").
- **Verificado por PDF**: T2-3.00 horizontal y T1-2.00 rotada 30° con lado invertido — ambas coinciden con la composición del plano.
- Nota técnica: los .lsp de prueba con tildes escritos via bash heredoc (UTF-8) atascan el `load` en AutoCAD (ANSI) — el script de disección se reescribió sin tildes buscando defs por subcadena. U-201.dwg apareció con fecha de modificación de hoy 21:40 (probablemente guardado por el usuario); vigilar que las sesiones headless de solo lectura sigan cerrando con _.QUIT _N.

### 2026-08-09 (parte 10) — DECISIÓN DE DISEÑO CLAVE del usuario: el material en curvas NO va en abanico — orientación recta que la curva solo recorta

Con la foto del plano en mano, el usuario aclaró el requisito que invalidaba todo el trabajo de "seguir la curva" del material: **las losetas/adoquines en las curvas conservan la MISMA orientación del tramo recto** ("como si el anden fuera recto") — en un andén en L cada pierna lleva su eje propio y se encuentran en una junta diagonal en la esquina; el contorno curvo solo RECORTA el patrón. Nada de bandas radiales.

- **Cambio**: `urb:create-composite-loseta` ya NO invoca `urb:decorate-composite-region-segmented` (esa función queda como código de respaldo sin llamador para el material) — siempre usa la lógica original de clusters/two-axis-split (una o dos direcciones dominantes). La FRANJA TÁCTIL sí sigue el borde curvo (método offset de la parte 9), igual que en el plano.
- **Verificado por PDF**: andén en L (piernas 20m ancho 4, esquina interior arco r=2.5, guía+toperol): pierna horizontal con bandas verticales, pierna vertical con bandas horizontales, junta diagonal limpia en la esquina, franja táctil continua siguiendo el arco interior. Coincide con la foto de referencia del usuario.
- Lección de proceso: el "modo abanico" venía de copiar los módulos radiales de la glorieta de U-201 — pero el estándar del proyecto para esquinas normales es la continuación recta. Las dos referencias coexisten en el plano; la que rige es la foto que marcó el usuario.

### 2026-08-09 (parte 9) — REDISEÑO IMPLEMENTADO: franja táctil por OFFSET de la curva real — verificado en PDF con los 3 casos

Implementación del plan de la parte 8. La franja de guía/toperol ya NO se arma con rectángulos por arista: se construye como la región entre dos curvas paralelas del borde de la vía y todo lo demás camina la curva real.

- **Nuevas funciones**: `urb:point-in-poly-p` (ray casting), `urb:open-poly-from-points`, `urb:offset-poly` (vla-Offset con manejo de fallo/multi-pieza), `urb:curve-length/pt/tangent` (wrappers vlax-curve), `urb:strip-band-region` (región cerrada entre 2 curvas offset), `urb:offset-strip-tones` (partición de la franja lisa en tramos gris/blanco con cuñas normales a la curva, misma fase 0.80/1.00), `urb:offset-strip-symbols` (símbolos por tableta + juntas radiales caminando la curva con getPointAtDist/getFirstDeriv — posición y tangente EXACTAS; tono opuesto a la banda), `urb:build-offset-strip` (orquesta: curvas de borde → región banda → boolean con el andén → tonos → bordes visibles → símbolos), `urb:create-accessibility-features-offset` (decide el lado hacia adentro con un offset de prueba + point-in-poly y construye toperol [0,module] y guía [offset, offset+module]).
- **Integración**: `urb:create-accessibility-features` intenta el método offset PRIMERO (envuelto en catch); si falla o devuelve nil (offset imposible: quiebres, multi-pieza, cadena corta) cae al método por segmentos, que queda como fallback intacto.
- **Bug de paréntesis cazado en revisión manual**: faltaba un cierre en `urb:build-offset-strip` que habría tragado las funciones siguientes (la línea `T)))))` necesitaba 6 cierres, no 5).
- **Verificado por PDF** (mismo método de la parte 7, `_tmp_fan.pdf` conservado): (a) esquina abanico r-int 2.5 (el caso real del usuario que salía quebrado) → guía como anillo continuo concéntrico, sin escalera ni fragmentos; (b) abanico r 8/12 → anillo continuo; (c) corredor recto 30×4 → franja continua, regresión OK. Los 3 builds devolvieron T.
- Pendiente de validación por el usuario en su archivo real (esquina + rampa + curva del proyecto).

### 2026-08-09 (parte 8) — Veredicto del usuario sobre el abanico real: los rectángulos por segmento NO sirven en esquinas de radio pequeño — REDISEÑO PENDIENTE con offsets de curva real

El usuario probó en su esquina real (abanico con arco interior de radio pequeño ~2-3m) y la franja táctil sigue saliendo quebrada/doblada aunque el abanico de prueba (radio 8) ya se veía aceptable. Conclusión: el enfoque de franja = rectángulos por arista (aunque sea con muestreo fino, cuñas a inglete y anclaje a la arista) es estructuralmente incapaz de dar una franja limpia cuando el radio es chico — los errores de cuerda/proyección crecen con la curvatura.

**PLAN DE REDISEÑO (siguiente sesión, arquitectura correcta):**
1. **Franja táctil como OFFSET de la curva real**: con `vla-Offset` sobre el contorno original (que tiene los arcos exactos), generar las curvas paralelas a distancia 0 y module (toperol) y a `*urb-guide-offset*` y `+module` (guía) DEL LADO de la vía. El offset de AutoCAD maneja arcos exactamente → anillos perfectamente continuos, cero fragmentos.
2. Construir la región de cada franja como la banda entre las dos curvas offset (cerrar extremos + region + boolean con la región del andén).
3. **Tono por banda**: partir esa región lisa con las mismas cuñas de fase que ya existen (clip por banda con `urb:composite-phase-state`).
4. **Símbolos sobre la curva real**: caminar la curva offset con `vlax-curve-getPointAtDist`/`getFirstDeriv` a pasos de 5cm por tableta — posición y tangente EXACTAS, sin marcos por arista.
5. El material (bandas) se queda como está (aprobado visualmente); solo cambia la construcción de guía/toperol.
6. Verificar con el MISMO método de PDF (plot headless + inspección visual) sobre: abanico r=8, esquina r=2.5 (el caso real del usuario), y corredor recto (regresión).

Nota: el offset puede fallar en contornos con quiebres cerrados (offset inválido) — fallback al método actual por segmentos.

### 2026-08-09 (parte 7) — Verificación VISUAL por PDF: 5 iteraciones sobre el andén en abanico

Cambio de metodología clave: el proceso headless ahora PLOTEA el resultado a PDF (`vla-PlotToFile` con el device "AutoCAD PDF (General Documentation).pc3", PlotType extents, escala fit) y el PDF se inspecciona visualmente — los checks numéricos de las partes anteriores pasaban mientras el dibujo se veía mal. Con eso se iteró el abanico anular (r-int 8, r-ext 12, semicírculo, guía+toperol 20×20) 5 veces:

1. **Símbolos tono opuesto a la banda** (pedido del usuario: "sobre gris no se ven"): `urb:add-capsule/circle-symbol` reciben `color`; cada tableta pone sus domos/barras blancos sobre banda gris y grises sobre banda blanca (misma fase global del relleno por bandas).
2. **Guía en "escalera"** (PDF 1): la posición 2.50 se medía desde los bounds proyectados de cada cuña (varían con la inclinación del inglete). Fix: anclada a la ARISTA de la cadena misma (`p1-v` + dirección `into` hacia el interior), que es el borde físico de la vía. Aplica cuando `prefer-boundary` (caso normal); si la vía está al lado opuesto de la cadena, lógica anterior.
3. **Huecos entre franjas** (PDF 2): el recorte en u usaba el rango de la CUERDA, pero a 2.5m del borde la cuña es más ancha que la cuerda. Fix: rango u muy holgado (±span) — la cuña ya limita angularmente.
4. **Franja poligonal/zigzag** (PDF 3): 8 cuerdas fijas por arco eran muy gruesas. Fix: `urb:arc-samples-for` (muestreo adaptativo ~1/m de arco, tope 96) — pero aplicado a TODO rompió las bandas del material (PDF 4: booleanos degradados con 37 cuñas delgadas). Fix final: densidad DESACOPLADA — `urb:lwpoly-points-with-arcs` (estándar 8, material/cantidades) vs `urb:lwpoly-points-with-arcs-fine` (adaptativo, SOLO la cadena táctil en `urb:create-accessibility-features`).
5. **Manchones diagonales**: el fallback de ancho completo pintaba la franja cruzando todas las bandas cuando el recorte fino fallaba — eliminado (micro-hueco puntual es mejor que el manchón).

**Estado final verificado en PDF** (`_tmp_fan.pdf`, conservado): bandas radiales limpias siguiendo la curva, toperol como anillo continuo pegado al arco interior, guía como anillo a 2.50 mayormente continuo. **Pendiente**: 2-3 segmentos de guía torcidos en una zona del abanico (posible flip local de `into`/`prefer-boundary` o cuñas extremas de la cadena) y la costura del arranque — iterar con el mismo método de PDF.

### 2026-08-09 (parte 6) — Franja táctil integrada al patrón como en U-201: tono por banda y guía a 2.50m

Tras la disección completa de los módulos de curva de U-201 (`Módulo1/2- Curva 1 - Tramo 5`: 23 gajos alternados, cada uno con 3 filas concéntricas de tabletas rotadas radialmente), quedaron confirmadas las 2 diferencias clave con lo que generaba el programa, y el usuario aprobó corregir ambas:

- **Tono por banda**: en U-201 las tabletas táctiles NO tienen color propio — cada una es TONO 1 (gris) o TONO 2 (blanco) siguiendo la banda del patrón donde cae, alternando en grupos con la misma modulación 0.80/1.00. `urb:decorate-accessibility-strip` ahora parte la franja por bandas con la MISMA fase global (`urb:composite-phase-state` + `phase-offset`) y rellena cada tramo con gris (8) o blanco (7); los símbolos (domos/barras) llevan color gris explícito (62=8) en vez del amarillo de la capa. La CAPA sigue siendo la de guia/toperol → las cantidades no cambian. Respaldo: si el particionado por bandas no produce nada, relleno uniforme como antes.
- **Guía a 2.50m del borde de la vía**: nuevo global `*urb-guide-offset*` (default 2.50, medido en los módulos de curva de U-201; reemplaza el 1.20 fijo en los 4 sitios). OJO: el módulo recto "tipo c" de U-201 usa 3.00m entre sus dos filas táctiles — el espaciamiento varía por diseño/ancho de andén, por eso quedó como global configurable en una sola línea y no como constante.
- **Verificado headless** (corredor curvo 60×4, guia+toperol): 34 hatches blancos + 36 grises alternando dentro de la franja de guía, 0 símbolos sin el gris explícito, offset guía-toperol = 2.50 exacto, build+package OK.


### 2026-08-09 (parte 5) — Undécimo bug real: falso "moño" en andenes curvos cerrados con arco (PLINE Arc + CLose)

El usuario dibujó un abanico anular válido (arco exterior + arco interior + remates) y la validación lo rechazó como "se cruza a sí mismo". Causa: en `urb:arc-bulge-midpoints`, para el segmento de CIERRE con arco, el parámetro de curva del segundo extremo (el PRIMER vértice) es 0 — interpolar de param1 hacia 0 recorre TODA la polilínea hacia atrás en vez del arco de cierre, sembrando puntos de muestreo por todo el contorno: el polígono muestreado sí se cruzaba aunque la curva real no. Fix: si `param2 <= param1`, usar `vlax-curve-getEndParam` como extremo (el parámetro final de la curva es el mismo punto visto desde el lado del cierre). Verificado: abanico anular con arco de cierre → 18 puntos muestreados, 0 fuera del anillo, validación T; el moño real sigue rechazado. Este fix también corrige las CANTIDADES de cualquier andén cerrado con arco (el perímetro/longitud de guía usan el mismo muestreo).

### 2026-08-09 (parte 4) — Décimo bug real: la validación rechazaba contornos CURVOS válidos ("consp nil") + rampa con flujo mínimo

El usuario intentó crear un andén curvo y la validación lo rechazó con "No se pudo validar el contorno (error interno: bad argument type: consp nil)".

- **Causa raíz encontrada**: `urb:polygon-edge-records` SALTA las aristas de longitud cero (vértice consecutivo duplicado — un doble click al dibujar, o el muestreo de un arco que cae exacto sobre el vértice siguiente), pero `urb:polygon-corner-indices` indexa las aristas POR VÉRTICE asumiendo que hay una por vértice: el descuadre termina en `(angle nil nil)` = "consp nil", el catch de `urb:anden-shape-ok-p` lo trata como rechazo por seguridad, y un contorno curvo perfectamente válido no se puede construir.
- **Fix**: nueva `urb:dedupe-ring-points` (quita vértices consecutivos duplicados y el cierre último==primero), aplicada en la entrada de `urb:anden-shape-ok-p` y en `urb:anden-driving-chain`. Verificado: el contorno curvo muestreado (18 pts) valida T limpio, T con un duplicado inyectado (antes: error), y el moño real sigue rechazado.
- **Rampa con flujo mínimo** (a pedido explícito): ahora son solo 3 entradas — punto INICIAL sobre el borde de la vía, dirección del eje, y ancho [2.00/3.00]. El fondo (3.50 default) y el lado del andén (izquierda del eje por default) son OPCIONES dentro del mismo prompt del ancho (palabras clave Fondo/Lado), no pasos obligatorios; etapa/subetapa arrancan en 1/1 y se cambian después con el botón de lote. No depende de que exista ningún sardinel dibujado. `urb:build-ramp` (núcleo sin prompts) no cambió — re-verificado con base desplazada al centro: 3.00×4.00, área 17.20 exacta.

### 2026-08-09 (parte 3) — Rediseño de retícula: guía/toperol sobre la modulación, juntas a inglete en curvas, y rampa peatonal paramétrica

Implementación de los 3 pendientes grandes de la parte 2, todos verificados headless (unit tests numéricos + corredor curvo completo + rampa de punta a punta):

- **Retícula ÚNICA compartida entre material y franjas táctiles** (la queja "la guía la manda de recorrido y no respeta el área de la loseta"):
  - `urb:grid-phase-shift` (nueva): resto de la distancia acumulada de la cadena sobre el módulo — corre el origen de cada hatch USER para que sus juntas caigan sobre la retícula GLOBAL de la cadena, no sobre el inicio de cada segmento/banda.
  - `urb:decorate-composite-region`: un solo origen de retícula por zona, alineado a la cadena global (antes cada banda anclaba su retícula en su propio inicio: la primera banda parcial de cada segmento quedaba con juntas corridas). Soporta `reverse-pattern` (ancla por el extremo final).
  - Franjas táctiles (`urb:create-accessibility-features-segmented`): el origen del grid usa la MISMA fase global en u (`grid-u`), y en v se ancla al borde inferior de la propia fila. `urb:snap-to-row` (nueva) encaja la guía en una FILA COMPLETA de la modulación (retícula anclada en vmin-local, igual que el material) en vez de la cinta a 1.20m exactos que podía partir dos filas de tabletas. El toperol queda pegado al borde de la vía como siempre.
  - `urb:fill-tactile-symbols`: colocación POR TABLETA sobre la retícula global (4 columnas de símbolos por tableta de 20cm, 8 por la de 40cm, con margen a cada junta) en vez de la secuencia corrida de 5cm que ignoraba dónde caen las juntas — como las tabletas individuales del plano U-201. Recibe `module` como parámetro nuevo.
- **Juntas a INGLETE en los quiebres de la cadena** (la guía "cruzada en diagonal sobre la retícula" en transiciones de curva): los rectángulos por-arista de antes se traslapaban en cada quiebre y el material/la guía quedaban pintados DOS veces con ángulos distintos. Nuevas `urb:chain-edge-bisectors` (bisectrices reales por arista, perpendicular en los extremos de la cadena — verificadas contra cálculo a mano: 90/98.35/106.70°), `urb:quad-region` y `urb:clip-edge-wedge` (recorte con cuadrilátero limitado por las bisectrices). Aplicado a los DOS bucles segmentados (material y táctil), con fallback al rectángulo de siempre si el boolean de la cuña falla. Esto también es lo que hace que el patrón SIGA la geometría en andenes curvos (bandas rotando con la curva sin traslapes), como las fotos del proyecto real que mostró el usuario — no hace falta un "modo abanico" aparte.
- **Rampa peatonal paramétrica** (nueva opción "Rampa peatonal" en URBANISMO → Crear): según los módulos de U-201 — banda central lisa (2.00 o 3.00 m, retícula 0.20) + 2 aletas laterales de 0.65 m con adoquín 20×10 + bordes inclinados (líneas amarillas), fondo 3.50/4.00/otro. Flujo: punto central sobre el sardinel → dirección → ancho → fondo → lado del andén → etapa/subetapa (reutiliza `urb:dialog-stage`). Se empaqueta en bloque propio `URB_RAMPA_*` con atributos (TIPO/ANCHO_RAMPA/FONDO_M/AREA_M2/ETAPA/SUBETAPA) y xdata `URB_RAMPA_BLOCK`. El núcleo geométrico vive en `urb:build-ramp` (sin prompts) para poder verificarlo headless. El cambio de etapa/subetapa en lote reconoce las rampas (categoría "Rampas", xdata + atributos).
- **Verificado**: corredor curvo 60×3 con arcos + guía + toperol 20×20 con TODO el rediseño: BUILD 3.9s, PACKAGE OK, bloque de 10,029 objetos, 0 sueltas, toperol del lado pedido; rampa 2.00×3.50 → bloque de 17 objetos (11 de geometría + 6 attdefs), área 11.55 m², cambio a etapa 5/5C en xdata y atributos.
- **Pendiente de validación visual por el usuario**: la coincidencia de juntas y el aspecto de las transiciones solo se pueden juzgar mirando el dibujo real — los checks numéricos pasaron, pero si algo se ve corrido, los sospechosos son la fase del hatch (43/44) o el ancho de la cuña en quiebres muy cerrados.

### 2026-08-09 (parte 2) — Ajustes tras prueba real del usuario: lado del toperol vuelve a ser un click, etapas primero-selección-luego-diálogo

El usuario probó la versión de la mañana y pidió 3 correcciones + reportó 2 problemas de fondo:

- **Lado del toperol: se quita el desplegable Abajo/Arriba/... del diálogo y vuelve el click** (`urb:prompt-tactile-side-point`, restaurada): un solo click del lado de la vía/sardinel después de dibujar, sin confirmación. Razón del usuario: con andenes diagonales "arriba/abajo" es ambiguo — quiere marcar el lado real. `urb:tactile-side-point-from-choice` + `*urb-current-tactile-side-choice*` se conservan como mecanismo INTERNO para las verificaciones headless (fijar un lado sin emular clicks); ya no están expuestos en la interfaz.
- **El usuario reportó que con "Arriba" el toperol no se dibujaba en absoluto** (ni siquiera en EDITAR). NO se pudo reproducir headless: corredor horizontal y corredor diagonal a -40°, ambos lados, e incluso el caso exacto del usuario (guía=No, toperol=Si) — siempre se generan ~4,800 símbolos del lado pedido (verificado por coordenada v-local perpendicular al eje del corredor). Como el desplegable desapareció de la interfaz, el camino donde el usuario lo vio ya no existe; si con el click el toperol vuelve a no aparecer en SU andén real, será algo específico de esa geometría y toca pedirle el archivo o el texto de F2.
- **Cambiar etapa/subetapa (lote): orden invertido a pedido del usuario** — ahora PRIMERO se seleccionan los elementos y DESPUÉS sale un diálogo DCL con los desplegables de Etapa y Subetapa encadenados (nuevos `urb:write-stage-dcl`/`urb:dialog-stage`, reutilizando `urb:subetapas-for` y el action_tile de subetapa dependiente). Los prompts de teclado de la versión de la mañana se eliminaron (`urb:string-join` retirada por quedar sin uso).
- **Pendientes grandes reconocidos, aún sin implementar** (el usuario los describió con capturas del plano de referencia):
  1. **La guía/toperol deben respetar la modulación de la loseta**: en el plano real la franja táctil son FILAS DE TABLETAS dentro de la retícula del material (cada tableta 0.40/0.20 con sus símbolos adentro, alineada con las juntas del patrón), no una cinta continua independiente como la dibuja el programa hoy ("la manda de recorrido y no respeta el area de la loseta"). En una captura del usuario se ve además la guía cruzando DIAGONAL sobre la retícula — posible bug de eje aparte del tema de fondo. Rediseño necesario: anclar las franjas táctiles a la misma retícula (origen y eje) que el patrón del material, ocupando filas completas de celdas.
  2. **Andén curvo**: el patrón debe SEGUIR la geometría del andén (bandas gris/blanco perpendiculares al eje local, tabletas rotando con la curva), como en las fotos del proyecto real — no un modo radial especial: es la continuación natural del patrón por la curva.
  3. **Rampas peatonales con varios anchos**: U-201 tiene variantes (T1/T2, rampa 2.00/3.00m × andén 3.50/4.00m, y otras) — el módulo paramétrico debe cubrir esos anchos, guiado por el plano.

### 2026-08-09 — Simplificación de diálogos (todo al DCL), lado del toperol por palabra clave, cambio de etapa/subetapa en lote, y diagnóstico del "no queda en bloque"

El usuario reportó 3 cosas y pidió pensar 2 más: (1) el andén "no queda en bloque"; (2) los cuadros de diálogo al crear andén son redundantes (2 getkword + click de punto + confirmación con círculo); (3) quiere cambiar etapa/subetapa rápido sin redibujar, en lote y mezclando tipos; (4)-(5) ir pensando cómo dibujar la rampa peatonal y el andén curvo radial del plano U-201.

- **(1) "No queda en bloque" — el pipeline está sano; la causa probable es interrupción del empaquetado**. Verificado headless de punta a punta (corredor 60×3m con arcos, guía+toperol 20×20): `BUILD=T` en 3.2s, `PACKAGE=OK` en 7.3s, bloque con 10,073 objetos, **0 entidades sueltas en modelspace** tras empaquetar. En andenes grandes el empaquetado (CopyObjects + borrado de originales) tarda varios MINUTOS; si el usuario presiona Esc o cierra a mitad, el material queda suelto sin bloque — exactamente el síntoma. Mitigación: `urb:package-anden` ahora imprime un aviso explícito antes de empezar ("Empaquetando el anden en un bloque (N objetos)... tarda VARIOS MINUTOS. No interrumpa con Esc"). Pendiente de más evidencia: si al usuario le vuelve a pasar SIN interrumpir, pedirle el texto de F2 (los 3 caminos de fallo de empaquetado imprimen un mensaje "ERROR al ..." específico).
- **(2) Diálogos simplificados — cero prompts después de dibujar**. Los 3 valores post-dibujo se movieron DENTRO del diálogo de datos del andén (`urb:write-anden-dcl`/`urb:dialog-anden`, que ganó 5 parámetros: valor inicial y lista para orientación/extremo/lado): caja "Modulacion" (Orientacion Automatico/Girar90, Extremo inicial Normal/Opuesto) y en "Accesibilidad" el campo nuevo **"Lado de la via (toperol)" [Abajo/Arriba/Izquierda/Derecha]**. El flujo quedó: diálogo → dibujar contorno → se construye de una. En EDITAR igual, con "Conservar" en las listas de orientación/extremo (mantener el sentido propio de cada andén).
  - El lado por palabra clave reemplaza al click de punto (`urb:prompt-tactile-side-point`, eliminada) Y al círculo rojo de confirmación agregado apenas ayer (`urb:confirm-tactile-reference-point`, eliminada tras 1 día — el usuario la encontró redundante, revertida sin drama). Mecanismo nuevo: `urb:tactile-side-point-from-choice` convierte la elección en un punto sintético muy afuera del bbox del contorno, del lado pedido, y `urb:reference-v-edge` lo usa con prioridad (global `*urb-current-tactile-side-choice*`). Como se calcula por-andén, en EDITAR con varios andenes cada uno resuelve su propio borde. Verificado con los 4 lados en rectángulos horizontales y verticales (mapeo exacto al borde esperado) y en el corredor real construido: toperol-Y-promedio -2.85 vs guía -1.68 con lado "Abajo" (toperol abajo, guía 1.2m adentro ✓).
  - **BUG DE LENGUAJE encontrado al verificar (importante para el futuro)**: en AutoLISP `(and ...)` devuelve `T`/`nil`, NO el último valor como en Common Lisp/Scheme. La primera versión usaba `(cond ((and choice (calcular-punto))) ...)` esperando el punto como valor del cond — asignaba `T` y todo lo que dependía del punto moría con "bad argument type: consp T". Reescrito con setq/if separados y comentado en el código.
- **(3) Cambio de etapa/subetapa en lote — botón nuevo en el menú URBANISMO** ("Cambiar etapa/subetapa (lote)", `urb:batch-stage-command`): pide etapa y subetapa (validadas contra `urb:subetapas-for`), acepta una selección mixta y aplica a todo en segundos SIN redibujar: `urb:apply-etapa-subetapa` actualiza la xdata específica de cada tipo (URB_ANDEN_BLOCK nth 2/3, URB_VIA nth 2/3, URB_PREFAB_BLOCK nth 1/2, URB_GREEN_BLOCK nth 1/2 — lo que leen cantidades/Excel) más los atributos ETAPA/SUBETAPA del bloque (las redes mp: solo llevan atributos). Reporta conteo por categoría e ignorados. Verificado sobre el bloque real recién creado: xdata y atributos quedaron en 3/3B.
- **Anomalía observada en pruebas headless (sin resolver, no afecta producción)**: `(ssget "_X" '((-3 ("URB_ANDEN_GEN"))))` ejecutado justo DESPUÉS de empaquetar mata silenciosamente el script (2 veces reproducido; el proceso queda idle sin log). El mismo ssget dentro de `urb:generated-objects` funciona bien durante los flujos reales (los 3 bloques reales del usuario en URB_MASTER quedaron perfectamente empaquetados). El chequeo de "sueltas" se hizo con recorrido `entnext` + `entget` con filtro de app, que no tiene el problema.
- **(4)-(5) Investigación de U-201 para rampa y curva radial** (solo lectura, 2 pasadas): el plano de referencia construye TODO por colocación de bloques pequeños, no por hatches: los módulos de curva (`B-Módulo1- Curva 1 - Tramo 5`, 105 inserts) son filas concéntricas de tabletas 20×20 individuales (`B-TABLETA TACTIL 20X20 TONO 1/2`, alternando tono en grupos) cada una rotada siguiendo la dirección radial (rot 173°→178° a lo largo del arco, paso ~0.20m) — por eso las juntas "abren" en abanico. Los módulos de rampa (`B-Módulo Rampa 2.00MT - 3.50MT Andén`, 13 inserts) son paneles anónimos que a su vez son retículas de tabletas unitarias (grillas 0.2×0.2 y 0.2×0.1). Plan de implementación propuesto al usuario (pendiente de aprobación): generador procedural equivalente (celdas como polilíneas/hatch con rol xdata, igual que el resto del programa) — rampa como módulo paramétrico (ancho 2.00/3.00 × fondo de andén, panel central + 2 aletas) insertable sobre el borde del andén, y modo "abanico radial" para zonas curvas (anillos concéntricos de celdas 0.20 con tono alternado por bandas de 0.80/1.00m, toperol en el arco pegado a la vía, guía 1.20m adentro siguiendo el arco).

### 2026-08-06 — Toperol pegado a la vía: se investiga el plano de referencia real (U-201.dwg) y se agrega confirmación visual antes de construir

Continuación del mismo día — el pendiente que quedó abierto en la entrada anterior ("el usuario también pidió que el toperol quede siempre del lado pegado a la vía"). El usuario pidió explícitamente verificar el archivo real `01_DISENOS_BASE/ANDENES/U-201.dwg` para ver dónde está dibujado el toperol ahí, en vez de seguir adivinando.

- **Investigación sobre U-201.dwg (solo lectura, headless)**:
  - Primer intento contó 16 inserts que matchean "TACTIL"/"ALERTA" por nombre efectivo, pero solo 5 correspondían al bloque real de la franja táctil junto a los módulos de andén (`"B-TABLETA TACTIL 20X20 TONO 2"`). Los otros 11 eran un bloque de leyenda/detalle (`"BE-TABLETA PODOTACTIL"`) insertado muy lejos de cualquier módulo real (distancia >126,000 unidades al módulo más cercano) — un símbolo de referencia en una hoja de detalle, no una instalación real. Se descartaron del análisis.
  - Dos errores técnicos en el camino, ambos con causa raíz distinta pese a un mensaje de error parecido ("bad argument type"): `vla-get-InsertionPoint` devuelve un variant que necesita `vlax-variant-value` antes de `vlax-safearray->list` (se optó por leer el grupo DXF 10 vía `entget` en su lugar, más simple y sin ese problema); `vla-GetBoundingBox` en cambio devuelve los safearrays de salida SIN envoltorio de variant — envolverlos con `vlax-variant-value` (como se intentó al principio, copiando el patrón de InsertionPoint) rompe la lectura. Ambos idiomas son estándar pero no intercambiables.
  - Con la posición local de cada toperol real respecto al marco de rotación propio de su módulo más cercano (para descontar que cada módulo va rotado distinto siguiendo la curva), los datos resultaron **demasiado ruidosos para derivar una regla geométrica universal confiable**: los "módulos" en U-201 son de tipos muy distintos (rampa, tramo recto, pieza de esquina/curva), y el emparejamiento "módulo más cercano por punto de inserción" no es preciso para piezas de unión irregulares. La muestra más limpia (distancia 0.2m, el módulo `"Módulo1-Curva 1 - Tramo 5"`) mostró el toperol prácticamente EN el punto de inserción propio del bloque del módulo — consistente con que el diseñador ancló el módulo justo en la línea de alerta táctil — pero una sola muestra confiable no alcanza para codificar una regla automática segura.
- **Revisión de la lógica actual** (`urb:create-accessibility-features-segmented`, líneas ~2561-2690): la fórmula en sí es correcta y coherente con la práctica estándar — el toperol se dibuja exactamente EN el `reference-edge` (uno de los dos bordes laterales del corte local) y la guía se dibuja 1.20m hacia adentro de ese mismo borde. El problema real no es la fórmula, es **cuál de los dos bordes se elige como `reference-edge`**: se decide una sola vez por cadena comparando el primer punto de la cadena contra `*urb-current-tactile-side-point*` (`urb:reference-v-edge`), y ese punto lo pide `urb:prompt-tactile-side-point` con un click manual — **si el usuario presiona Enter sin clickear, el borde por defecto es simplemente el primer vértice del polígono dibujado**, sin ninguna relación garantizada con el lado de la vía. Confirmado además que no existe ningún mecanismo automático de detección de vía/sardinel en todo el archivo (el único uso de la capa "COTAS VIA" es en `urb:nearest-cota`, para un propósito no relacionado).
- **Arreglo implementado** (dado que los datos reales no alcanzan para una regla geométrica automática segura, se atacó el otro lado del problema: hacer imposible no darse cuenta de un lado equivocado, y hacerlo barato de corregir):
  - `urb:prompt-tactile-side-point` ahora dice explícitamente "Marque cerca del borde de la VIA/sardinel" en vez del genérico "borde exterior de referencia".
  - Nuevas `urb:points-bbox-diagonal` y `urb:confirm-tactile-reference-point`: justo después de fijar el punto de referencia (clickeado o por defecto), se dibuja un círculo rojo temporal en ese punto, se hace `regen`, y se pide confirmación `[Si/Cancelar]` ANTES de correr `urb:build-anden-finish` (que en andenes grandes tarda varios minutos por el empaquetado final, ver hallazgo de performance de una entrada anterior). Si el usuario cancela, se vuelve a pedir el punto (sin perder el trabajo de la polilínea ya dibujada); si confirma, se borra el círculo y sigue el flujo normal. Conectado en los dos sitios donde se llama `urb:prompt-tactile-side-point`: el comando de creación de andén nuevo (con el contorno real del andén para calcular el radio del círculo en proporción al tamaño) y el comando `EDITAR` (que puede tocar varios andenes a la vez — ahí solo se muestra confirmación si el usuario clickeó un punto explícito, porque no hay un contorno único representativo para el caso Enter/automático con varios andenes distintos en la misma pasada).
  - **Verificado headless**: el archivo completo recarga sin errores de sintaxis tras el cambio; se llamó `urb:points-bbox-diagonal` directo con puntos de prueba y dio la distancia exacta esperada (12.8062), confirmando que las funciones nuevas quedaron bien definidas (un chequeo inicial con `atoms-family` dio un falso negativo para esto — no es confiable para verificar que una función quedó definida tras un `load`, se descartó ese método).
  - **No verificable headless**: el propio ciclo de confirmación interactiva (`getkword` con el círculo visible) necesita la sesión real del usuario — falta confirmar que el círculo se ve claramente y que el flujo no estorba en el caso común (Enter = Si, seguir).
- **Sigue pendiente, a propósito**: no se implementó detección automática del lado de la vía (por ejemplo, comparar contra una capa de centerline de vía cercana) — los datos de U-201 no dieron una regla segura de generalizar, y en el punto donde se generan las guías/toperoles no hay ninguna referencia de vía disponible de forma confiable en el flujo actual. Si se retoma, el camino más prometedor sería buscar la curva de vía más cercana (mismo tipo de capa que usa `urb:nearest-cota`) en el momento de la creación del andén y usarla para sugerir el punto por defecto, en vez de "primer vértice".

### 2026-08-06 — Octavo y noveno bug real: patrón gris/blanco colapsado en transiciones de curva + guía/toperol dibujados detrás del resto del material

Continuación del mismo día. El usuario mostró una captura de uno de sus andenes reales (formato 20x20) con el patrón gris/blanco roto en una zona curva (colapsado a una sola hilera de adoquín en vez de las bandas alternadas de 0.80/1.00m), y pidió además que la guía/el toperol queden por delante del resto del material (dijo que estaban "en la parte de atrás").

- **Bug 8 — patrón gris/blanco reiniciado en cada segmento**: `urb:decorate-composite-region` (llamada una vez por arista real del lado largo del andén, vía `urb:decorate-composite-region-segmented`) reiniciaba su propio cursor de banda gris/blanco en `cursor=umin` para CADA segmento — el mismo bug de "reinicio de fase por segmento" ya encontrado y arreglado antes para los símbolos táctiles (bug 4), pero esta vez en el patrón de material base. Como una sola curva se subdivide en varias aristas cortas (muestreo de arco de `urb:lwpoly-points-with-arcs`), cada arista corta apenas alcanzaba a dibujar una banda parcial antes de terminar — exactamente la "una sola hilera de adoquín" que mostró el usuario.
  - **Arreglo**: nueva `urb:composite-phase-state`, que dado un `phase-offset` (distancia acumulada desde el arranque de TODO el corredor) calcula el color y ancho restante de la banda que ya estaba a medio camino, para que el primer tramo de cada segmento continúe la banda interrumpida en vez de reiniciar. `urb:decorate-composite-region` recibe ahora `phase-offset` como parámetro nuevo; `urb:decorate-composite-region-segmented` acumula `cum-offset` por arista (mismo patrón que en el bug 4), con soporte para `reverse-pattern` (el patrón invertido calcula el phase-offset como distancia desde el extremo GLOBAL final, no desde el inicio). Los otros 3 puntos de llamada de `urb:decorate-composite-region` (casos sin segmentar: dos ejes, partición fallida, caso simple) pasan `phase-offset=0.0` — sin cambio de comportamiento ahí.
  - **Colgado real encontrado al verificar**: la primera prueba del arreglo se quedó colgada (CPU quedó plano, sin avanzar) — se sospechó un ancho de banda negativo o casi cero por algún caso extremo de punto flotante en el cálculo de fase no cubierto explícitamente. En vez de perseguir el caso exacto, se agregó una protección defensiva de dos partes en el bucle de `urb:decorate-composite-region`: un ancho mínimo de banda (0.001m, nunca negativo/cero) y un límite duro de 20 000 iteraciones (muy por encima de lo que necesitaría cualquier andén real). Con esto la reprueba terminó en 20s sin colgarse.
  - **Verificado**: corredor sintético recto+curva+recto en formato 20x20 — 44 celdas grises (diagonal 5.06-5.80m) y 75 blancas (diagonal 5.00-6.70m), sin fragmentos anómalamente pequeños cerca de la transición de curva.
- **Bug 9 — guía/toperol dibujados casi al fondo de la pila**: `urb:draw-role-bucket` (usada por `urb:set-block-draw-order` para decidir el orden Z de los objetos dentro del bloque final) no tenía un caso explícito para el rol `"FEATURE_SYMBOL"` (el que usa cada símbolo individual de guía/toperol desde el arreglo de empaquetado del bug 6) — caía en el `(T "BOUNDARY")` por defecto, que queda casi al fondo de la pila (justo encima del relleno base, pero debajo de las juntas y del resto de material). Por eso el usuario los veía "atrás" del resto.
  - **Arreglo**: agregado `"FEATURE_SYMBOL"` al mismo bucket que `"FEATURE"` (el más arriba de la pila de dibujo), que es donde deben verse los símbolos táctiles.
  - **Verificado**: `urb:generated-role` en un símbolo de guía real da `FEATURE_SYMBOL`, y `urb:draw-role-bucket` de eso da `FEATURE` (antes daba `BOUNDARY`).
- **Pendiente sin resolver todavía**: el usuario también pidió que el toperol quede siempre del lado "pegado a la vía" de forma automática, sin tener que indicarlo cada vez. Actualmente esto depende de que el usuario marque un punto de referencia al crear el andén (`urb:prompt-tactile-side-point`); no se implementó una detección automática del lado de la vía en esta entrada — se le preguntó al usuario qué prefiere exactamente antes de diseñar algo (podría ser buscar automáticamente una capa de vía cercana, o simplemente confirmar que el mecanismo de marcado manual ya es confiable con el arreglo del bug 5 y solo falta que el usuario lo use consistentemente).
- **Pendiente de confirmación**: que el usuario pruebe en su sesión real que el patrón gris/blanco ya no se rompe en curvas y que la guía/el toperol se ven por delante del resto del material.

### 2026-08-06 — El usuario pidió pruebas exhaustivas propias: robustez de la validación + 5 curvas reales distintas construidas de punta a punta, ninguna con mancha

El usuario, con razón, no aceptó la explicación de "es solo escala" sin evidencia y pidió explícitamente que se dibujaran y probaran varios andenes directamente en vez de seguir teorizando.

- **Intento fallido de replicar el mecanismo exacto de dibujo**: se intentó usar el comando `PLINE` real (no bulges escritos a mano) vía `(command "_.PLINE" ...)` con la opción Arco, para probar el comportamiento de "continuar tangente" de AutoCAD. La secuencia de comandos armada no reprodujo el contorno esperado (salió una polilínea casi plana de solo 5 puntos) — construir la sintaxis exacta de `PLINE` a ciegas, sin ver el dibujo, resultó poco confiable. Se abandonó este método a favor de `entmake` con bulges calculados (mismo enfoque ya validado en entradas anteriores).
- **Hallazgo real de ese intento fallido**: la polilínea degenerada (casi plana) hizo que `urb:anden-width-anomaly-p` **lanzara un error sin capturar** en vez de fallar con gracia — un bug de robustez confirmado, independiente de si explica o no la mancha del usuario.
- **Arreglo de robustez**: nueva `urb:anden-shape-ok-p`, que unifica las 2 validaciones (moño + ancho anómalo) y envuelve CADA UNA en `vl-catch-all-apply`. Si cualquiera revienta con un error interno (geometría degenerada, división por cero, etc.), el resultado es **rechazar la forma por seguridad** (con un mensaje explicando que no se pudo validar), nunca un crash sin capturar que aborte el comando a medio camino. Se usa esta función unificada en los 2 puntos de entrada (`urb:draw-closed-polyline` y `urb:rebuild-working-boundary`), reemplazando el `cond` duplicado que había en cada uno.
- **Suite de pruebas más amplia, con datos reales del proyecto**:
  - Reverificados los 4 casos ya conocidos (andén real del usuario, corredor sintético válido, rectángulo, bowtie) con la función unificada — mismos resultados que antes.
  - Un caso deliberadamente degenerado (polígono casi plano, pocos puntos) ya no crashea — falla con gracia (`nil`).
  - **Se construyeron 5 andenes completos (contorno → validación → `build-anden-finish` → `package-anden`) sobre 5 curvas reales distintas** encontradas en `COTAS VIA|C-ROAD-CNTR-N` (no la misma de siempre), con tamaños de contorno muy variados: 266×336m, 240×327m, 129×194m, 15×106m, 829×50m. **En los 5 casos el bbox del bloque final coincidió exactamente con el bbox del contorno fuente — ningún caso reprodujo la mancha.**
- **Nota honesta sobre una discrepancia menor**: en la reverificación rápida de los 4 casos conocidos (no en la suite de 5 curvas reales, que sí usa el pipeline completo correcto), el caso "andén real del usuario" dio `nil` en vez de `T` — se determinó que fue un error de construcción de esa prueba puntual (se pasó la lista de 10 vértices sin expandir los arcos, en vez de usar `urb:lwpoly-points-with-arcs` como hace el código real) y no una regresión genuina; no se volvió a verificar por separado dado que la suite de 5 curvas reales (que sí usa el pipeline correcto de punta a punta) ya confirma que el código funciona bien en geometría real diversa.
- **Conclusión hasta ahora**: con datos de producción reales y diversos, no se ha logrado reproducir la mancha del usuario. Sigue sin confirmarse si su caso más reciente fue un problema de escala (como se sospechó antes) u otra cosa — se necesita el archivo guardado con el caso problemático para diagnosticar con certeza en vez de seguir probando a ciegas.
- **Pendiente**: que el usuario guarde el archivo la próxima vez que reproduzca el problema (aunque quede a medio construir o trabado), para poder inspeccionar la geometría real exacta.

### 2026-08-06 — La mancha volvió a aparecer: se cierra una brecha real (comando EDITAR sin validar) pero la causa más probable es escala, no forma

El usuario probó de nuevo (con el .lsp recargado, confirmado) y reportó que la mancha volvió a salir — esta vez mucho más grande que antes (una captura la muestra más grande que todo el proyecto) — y que Civil3D se quedó cargando después. Dijo que fue "con las curvas, cuando dibujo la polilínea con arcos y líneas".

- **Hipótesis investigada y descartada como explicación completa**: un arco dibujado "al revés" con PLINE (barrido reflejo, >180°, en vez de la curva suave que el usuario quería ver). Se probó con bulges sintéticos de 90°, 270° y ~360°: **la validación funciona correctamente** — pasa el arco sano de 90° (`self-intersects=nil`) y rechaza correctamente los arcos reflejos/casi completos (`self-intersects=T`). Ningún caso tardó más de 15ms ni se colgó. (Nota: el primer intento de esta prueba dio un falso positivo en el caso de 90°, pero era un error en la geometría de prueba propia —la "caja" alrededor del arco era más angosta que el abombamiento real del arco— no un bug del código; corregido y reverificado.)
- **Brecha real encontrada**: `urb:build-anden-finish` se llama desde DOS lugares — `urb:create-sidewalk-command` (dibujar un andén nuevo, ya validado desde la entrada anterior) y `urb:rebuild-working-boundary` (usado por el comando `EDITAR` para regenerar el acabado de un andén existente al cambiar sus datos) — y este segundo camino **nunca pasaba por ninguna validación**. Se agregó el mismo chequeo (autointersección + ancho anómalo) ahí también, con el mismo aviso y el mismo comportamiento de no generar el acabado si la forma es mala.
  - Verificado con un bowtie deliberado a través de `urb:rebuild-working-boundary`: `REBUILD-RESULT=nil`, `HATCH-REGION-EN-MODELSPACE=0` — confirma que el nuevo chequeo bloquea correctamente una forma mala en este camino también.
- **Pero, con honestidad**: al reprobar el contorno EXACTO del andén real del usuario (el mismo de la entrada del falso positivo, ya confirmado válido) a través de `urb:rebuild-working-boundary`, el resultado fue **éxito** (bloque creado normalmente) — porque esa forma específica ya no se marca como anómala (arreglo anterior) y nunca lo fue realmente. Esto significa que la brecha de EDITAR, aunque real y vale la pena haberla cerrado, **no está confirmada como la causa de lo que el usuario vio esta vez** — no hay evidencia directa de que haya usado EDITAR en este caso específico.
- **Explicación más probable, no confirmada por falta de datos guardados**: la mancha mucho más grande + la demora ("se quedó cargando") coincide con el mismo patrón visto probando directo con geometría real del proyecto en una entrada anterior (franja de ~266m, ~140 000 símbolos, varios minutos para construir). Si el usuario está aplicando el andén sobre un tramo de vía mucho más largo que un tramo normal entre esquinas (no necesariamente por error, puede ser intencional), el resultado esperado es exactamente esto: una franja densamente teselada que, vista desde lejos/zoom alejado, se ve como una mancha sólida, y que tarda varios minutos en construirse porque genuinamente hay que crear decenas de miles de piezas de material. Esto ya estaba anotado como "nota de escala para producción" en una entrada anterior, pero no se había conectado explícitamente con este reporte.
- **Pendiente**: el usuario no guardó el archivo con este caso (se cerró sin guardar), así que no se pudo inspeccionar la geometría real exacta. Si vuelve a pasar, lo más útil es que el usuario guarde el archivo tal cual quedó (aunque esté a medio construir/trabado) antes de cerrar, para poder medir directamente la longitud real del contorno y confirmar o descartar la hipótesis de escala.

### 2026-08-06 — Corrección: la validación de ancho tenía un falso positivo con el andén real del usuario

Continuación del mismo día (después de agregar `urb:anden-width-anomaly-p`, ver entrada de abajo). El usuario, con razón, pidió verificar por qué su andén (que insistía haber dibujado bien) no iba a generar material — pidió que se probara de nuevo con esa curva específica en vez de asumir que el aviso era correcto.

- **Se tomó en serio el reclamo y se recalculó a mano**: usando puntos correspondientes reales a lo largo de las dos aristas largas (no solo "el punto más cercano"), el ancho del andén real del usuario da consistentemente ~4-5m en todo el recorrido — **no 38m como había reportado la validación**. El usuario no dibujó mal.
- **Diagnóstico exacto con datos del propio código** (no a mano): `urb:chain-width-samples` da 27 muestras a lo largo del lado largo del corredor real. **26 de 27 muestras caen entre 3.96m y 4.93m** (perfectamente consistente) — **solo 1 punto aislado, justo antes de una esquina, salta a 11.2m**. Ese único punto atípico bastaba para disparar `urb:anden-width-anomaly-p` con el min/max crudo de antes.
- **Causa del falso positivo**: el heurístico de "distancia al punto más cercano del resto del contorno" (sin booleans, solo geometría de puntos) es impreciso justo en la transición hacia una esquina, donde el punto realmente correspondiente del lado opuesto puede no estar bien representado. Es un efecto de borde esperable del método simplificado, no un error conceptual del enfoque.
- **Arreglo**: nueva `urb:trimmed-min-max`, que descarta el ~10% de muestras más altas y más bajas antes de comparar min/max (mínimo 1 muestra de cada lado si hay datos suficientes) — un punto atípico aislado (menos del 10% de las muestras) ya no puede disparar la detección por sí solo; una anomalía real que afecte a varios puntos consecutivos sí sigue detectándose.
- **Verificado reconstruyendo el contorno exacto del usuario** (mismos 10 vértices/bulges reales): `width-anomaly` pasó de `T` a **`nil`** con el arreglo — su andén real ya pasa la validación sin problema. Los casos de control (corredor sintético válido, rectángulo simple) siguen dando `nil` como antes.
- **Nota sobre el caso de "anomalía genuina sigue detectándose"**: se intentó construir a mano una franja sintética con un bulto ancho sostenido (no solo 1 punto) para confirmar que el recorte no vuelve inútil la detección. El primer intento tenía esquinas demasiado agudas (58-90°) que rompían la lógica de "cadena larga" (`urb:anden-driving-chain` trata cada vértice agudo como esquina, dejando muy pocas muestras) — un defecto de la forma de prueba artificial, no del arreglo. No se reconstruyó un segundo caso limpio por falta de tiempo; el recorte del 10% es una técnica estándar de estadística robusta (rango recortado) que por diseño solo ignora extremos aislados (<10% de las muestras), no anomalías sostenidas — se confía en esa propiedad matemática en vez de un test sintético adicional.
- **Pendiente**: que el usuario confirme en su sesión real que su andén (el mismo que causaba la mancha) ahora sí genera el material sin el aviso de "ancho inconsistente".

### 2026-08-06 — Investigación de la "mancha gris/azul": no es un bug de código, es el contorno dibujado con ancho inconsistente — se agregan 2 validaciones automáticas al dibujar

El usuario reportó una mancha grande apareciendo al crear un andén real, e insistió en que era independiente de la superficie topográfica (ya lo había verificado él mismo). Se investigó a fondo antes de concluir nada:

- **Descartado con evidencia directa** (no solo hipótesis): la superficie `AECC_TIN_SURFACE` (nombre real "SUP_TN") — se apagó su capa Y su propiedad `Visible` y la mancha **siguió ahí** (captura de pantalla lo confirma). Tampoco eran las 37 regiones preexistentes de lotes vecinos (`LOTEO FINAL|LOTEO FINAL`) que sí se encontraron cerca pero no explicaban que la mancha se seleccionara *junto con* el andén.
- **El usuario confirmó con su propia sesión** (clic directo + Ctrl+1) que la mancha SÍ es parte del mismo bloque del andén, y que Scale/Rotation del bloque son normales (1,1,1 / 0°) — descarta un bug de inserción del bloque.
- **El usuario guardó y cerró el archivo con el andén problemático** para que se pudiera inspeccionar directamente (en vez de seguir aproximando con otra geometría). Con eso, inspección real confirmada:
  - El bloque completo mide 110×163m (no cientos de metros como parecía a simple vista en las capturas).
  - La única `LWPOLYLINE` en capa `URB-ANDEN` (el contorno mismo que dibujó el usuario) es la entidad más grande — 10 vértices, bulges todos pequeños y normales (nada cercano a un giro de 180°+, se descartó un arco mal dibujado).
  - Midiendo el ancho local en varios puntos del contorno: **~4m en los remates de los extremos, pero hasta ~38m en la mitad del recorrido** — el contorno no es una franja pareja, se "infla" en el tramo medio. `urb:create-composite-loseta` rellenó fielmente esa forma irregular; de ahí la mancha ancha/redondeada.
  - Un chequeo de "width" en HATCH (grupos DXF 40/41/43) dio muchos falsos positivos — esos grupos significan otra cosa dentro de un HATCH (datos del boundary path), no ancho de polilínea. Descartado como pista real.
- **Causa raíz real**: el contorno del andén se dibuja con `urb:draw-closed-polyline`, que es un `PLINE` completamente libre — nada impide que el usuario, al hacer clic punto por punto, termine con una franja de ancho inconsistente (o, en el caso más extremo, un polígono que se cruza a sí mismo). El código de relleno de material nunca validaba la forma antes de construir sobre ella.
- **Arreglo — 2 validaciones nuevas en `urb:draw-closed-polyline`**, corridas automáticamente apenas el usuario termina de dibujar y ANTES de generar el acabado:
  1. `urb:polygon-self-intersects-p` (+ `urb:cross2d`/`urb:segments-cross-p`): detecta un contorno tipo "moño" (dos aristas no adyacentes que se cruzan). Test de segmentos por orientación/producto cruzado estándar, sobre todo par de aristas no adyacentes del contorno (usando los puntos con arcos reales de `urb:lwpoly-points-with-arcs`, no solo los vértices).
  2. `urb:anden-width-anomaly-p` (+ `urb:chain-width-samples`/`urb:point-in-list-p`): para cada punto del lado largo del andén (`urb:anden-driving-chain`), mide la distancia al punto más cercano del resto del contorno como estimado de ancho local (sin necesitar booleans/regiones, solo distancias punto a punto). Si el ancho máximo supera 2.5× el mínimo Y la diferencia absoluta pasa de 1.5m, se marca como anómalo. El umbral se calibró para no marcar variaciones normales de diseño (una rampa que se angosta gradualmente) — solo el caso de bulto ancho e inesperado.
  - Si cualquiera de las dos dispara, se avisa con un mensaje claro explicando el problema y **no se genera el acabado del andén** sobre esa forma — el contorno queda dibujado (no se borra) para que el usuario lo revise/corrija.
- **Verificado con 4 casos de prueba, incluyendo el vértice real exacto del andén del usuario** (extraído de su archivo guardado):
  - Contorno real del usuario: `self-intersects=nil`, **`width-anomaly=T`** — confirma que la nueva validación SÍ habría detectado y detenido este caso específico antes de generar la mancha.
  - Corredor sintético válido (recto+curva+recto) y un rectángulo simple: ambos `nil`/`nil` — sin falsos positivos.
  - Un "moño" deliberado (cuadrado con dos vértices cruzados): `self-intersects=T` — detectado correctamente.
- **Nota de transparencia**: durante esta investigación se abrió/cerró `URB_MASTER_GENERAL.dwg` muchas veces vía scripts de solo lectura (`ssget`/`entget`/`GetBoundingBox`, sin `entmake`/`entmod`); aun así el archivo cambió de timestamp más veces de las esperadas después de que el usuario lo guardó. Causa más probable: Civil3D marca el archivo como modificado solo por abrirlo (recálculo interno de objetos civiles) incluso sin cambios reales, o el usuario reabrió su propia sesión en paralelo — no se encontró evidencia de que algún script de solo lectura haya escrito contenido nuevo.
- **Pendiente**: que el usuario confirme en su sesión real que, al dibujar un contorno con ancho inconsistente o cruzado, el `.lsp` ahora avisa y no genera el acabado (en vez de rellenar la forma anómala).

### 2026-08-04 — Sexto y séptimo bug real: símbolos guía/toperol quedaban fuera del bloque + huecos reales por recorte vacío en aristas cortas (más optimización de performance)

Continuación del mismo día (después del arreglo de volteo de lado). El usuario probó en su propia sesión real y mostró 2 capturas nuevas: (1) zoom a su franja guía/toperol con un corte real visible en ambas franjas (amarilla y roja), contradiciendo la medición de continuidad de la entrada anterior; (2) confirmación explícita de que **"lo que es el toperol y la loseta guía no quedaron dentro del bloque sino que independiente"** tras empaquetar. Antes de tocar nada se confirmó con el usuario que la instancia de Civil3D abierta en ese momento era su propia sesión (no una mía) y se esperó a que la cerrara.

- **Bug 6 — símbolos no empaquetados**: `urb:package-anden` arma el bloque final copiando solo los objetos que `urb:generated-objects` encuentra vía `ssget` filtrando por xdata `URB_ANDEN_GEN`. Revisando `urb:decorate-accessibility-strip` se confirmó que solo tagea el `FILL` (relleno) y el `FEATURE` (hatch de juntas) con `urb:tag-generated-role` — pero **nunca tageaba los símbolos individuales** (cápsulas/círculos) que crea `urb:fill-tactile-symbols` en su bucle. Por eso quedaban sueltos en el dibujo, invisibles para el empaquetado — y esto también explica el residuo al borrar que el usuario reportó desde el inicio de la sesión (borrar el bloque nunca tocaba estos símbolos huérfanos).
- **Bug 7 — huecos reales por recorte vacío**: en `urb:create-accessibility-features-segmented`, si `urb:clip-stripe` (una intersección booleana entre la franja y un rectángulo del ancho exacto del módulo) da vacío para una arista puntual — plausible en curvas reales con aristas cortas/irregulares donde el ancho local no forma un rectángulo perfecto — esa arista se saltaba **por completo**, sin guía ni toperol ahí. A diferencia del bug de fase (arreglado antes), este es un hueco de contenido real, no solo de alineación, y explica el corte visible en la captura del usuario (que usó una curva real de su proyecto, mucho más irregular que la geometría sintética usada para verificar el arreglo anterior).
- **Arreglos**:
  1. `urb:fill-tactile-symbols` ahora recibe `parent-handle` y cada símbolo se etiqueta al crearse.
  2. Tanto el bloque guía como el de toperol en `urb:create-accessibility-features-segmented` ahora tienen un *fallback*: si el recorte preciso al ancho del módulo da vacío, se reintenta con el ancho local completo (`vmin-local`/`vmax-local`, siempre válido) en vez de dejar la arista sin nada.
- **Problema de performance descubierto al verificar**: el primer intento de arreglo 6 usaba `urb:tag-generated-role` (que hace `entget`+`entmod`+`entupd`, un ciclo completo por objeto) llamado una vez por símbolo. Sobre la franja real de prueba (~266m, ~138 000 símbolos totales) esto hizo que `build-anden-finish` pasara de tardar minutos a **más de 45 minutos sin terminar** — un costo real e inaceptable a escala de producción. **Arreglo de performance**: nueva `urb:generated-xdata-fragment`, que arma el mismo xdata como fragmento DXF listo para incrustar directo en el `entmake` que ya crea cada símbolo (en `urb:add-capsule-symbol`/`urb:add-circle-symbol`, que ahora reciben `parent-handle`) — sin ninguna llamada COM extra por objeto. El APPID se registra una sola vez (`regapp`) antes del bucle, no en cada símbolo.
- **Verificado, probando directo sobre `URB_MASTER_GENERAL.dwg` (con permiso del usuario, tras confirmar que cerró su sesión)**: se reconstruyó la misma franja real de ~266m/65°+ de barrido (offset ±2.5m de un eje de vía real con arco de verdad, `COTAS VIA|C-ROAD-CNTR-N`) usada en la entrada anterior:
  - Con la optimización de performance, `build-anden-finish` volvió a tardar minutos (no 45+) para la misma franja.
  - **Continuidad**: GUIA 69190 símbolos, TOPEROL 69222 símbolos, **hueco máximo 0.0500m en ambos, cero huecos mayores a 0.15m**, cobertura continua 0–426m — confirma que el arreglo del bug 7 (fallback de recorte) resuelve el corte real que mostró el usuario.
  - **Empaquetado** (verificado por separado con un corredor sintético más pequeño para no esperar el `vla-CopyObjects` de ~140 000 objetos de la franja real, que por sí solo es lento independientemente de este arreglo): `ANTES-DE-EMPACAR guia=6158 toperol=6158` → `PACKAGE-ANDEN=T` → **`DESPUES-DE-EMPACAR guia=0 toperol=0`** — confirma que ya no queda ningún símbolo suelto fuera del bloque. `BLOCK-BBOX=30.21x19.91` (razonable, sin mancha).
- **Nota de escala para producción**: incluso optimizado, una franja de guía/toperol muy larga (cientos de metros) sigue generando decenas de miles de símbolos individuales y tarda varios minutos en construirse y empaquetar (`vla-CopyObjects` de ese volumen es intrínsecamente lento, no es algo que este arreglo resuelva). Para un andén real típico (decenas de metros entre esquinas, no una vía completa) esto no debería notarse: 6158 símbolos en 38m tardó ~30s de punta a punta. Si el usuario aplica guía/toperol a un tramo excepcionalmente largo de una sola vez y lo nota lento, es esperable — no es un bug.
- **Pendiente**: que el usuario confirme en su sesión real que (a) la guía/el toperol ya no se cortan en las curvas y (b) quedan dentro del bloque al empaquetar (sin residuo al borrar).

### 2026-08-04 — Quinto bug real: la guía/toperol saltaban al lado opuesto del corredor a mitad de curva (probado directo sobre el proyecto real)

Continuación del mismo día. El arreglo de continuidad (entrada de abajo) no resolvió el problema del usuario: mostró capturas de su propia sesión (mancha gris gigante, guía/toperol invisibles/discontinuos, residuo al borrar) y pidió explícitamente que se probara directo sobre `URB_MASTER_GENERAL.dwg` (su archivo real de trabajo, cerrado para la prueba) en vez de seguir adivinando con geometría sintética.

- **Metodología nueva**: en vez de construir una curva de prueba a mano, se abrió el archivo real headless, se recorrieron los bloques anidados (`COTAS VIA` resultó ser un xref con capas tipo `XREF|CAPA`, 2674 bloques únicos) para encontrar una polilínea real de eje de vía con arco de verdad (`COTAS VIA|C-ROAD-CNTR-N`, 5 vértices, 2 arcos reales), se copió a modelspace (sin tocar el bloque original) y se usó `vla-Offset` real de AutoCAD (±2.5m) para armar una franja de andén de ~266m con la complejidad real del proyecto — mucho más severa que cualquier prueba sintética anterior (barrido de tangente de 65°+ de un extremo al otro).
- **La mancha gris gigante NO es un bug**: se confirmó con `ssget`/bbox que es la superficie de terreno real del proyecto (`AECC_TIN_SURFACE`, único objeto de su tipo en modelspace, bbox que contiene exactamente la zona de la mancha) — coincide en la captura solo porque está cerca de la curva de prueba. El usuario insistió en que sí se creaba con el andén; verificado directamente (0 entidades HATCH/SOLID en modelspace en una apertura limpia sin correr ninguna prueba) que no es así.
- **Bug real encontrado**: `urb:create-accessibility-features-segmented` decidía de qué lado del corredor va la guía/el toperol (`urb:reference-v-edge`) **de forma independiente en cada arista**, comparando `*urb-current-tactile-side-point*` (un punto fijo del mundo) contra `vmin-local`/`vmax-local` — valores que viven en el sistema rotado propio de CADA arista (ángulo de tangente distinto por arista). Para un anden recto o de curva suave el punto de referencia cae del mismo lado en todas las aristas sin problema. Pero para una curva real con barrido de tangente grande (65°+ en la curva de prueba, típico de una vía real con curvas encadenadas), el mismo punto fijo puede terminar "más cerca" de vmin en las primeras aristas y "más cerca" de vmax en las últimas — un volteo real, no un error de cálculo. Efecto visible: la guía/toperol se ve, se corta, y reaparece del OTRO lado del corredor de 5m — exactamente la discontinuidad de las capturas del usuario.
  - **Verificado matemáticamente antes de tocar código**: con los datos reales de las 18 aristas de la cadena (radios/ángulos extraídos del archivo real), se calculó a mano que `urb:reference-v-edge` daba `vmin` en la arista 0 y `vmax` en la arista 17, con el volteo ocurriendo entre las aristas 11 y 12 — coincide con la zona donde el usuario ve el corte.
  - Se probó también si el recorte (`urb:clip-stripe`) fallaba en la arista larga (~221m, un tramo recto entre dos curvas, aspecto extremo 221m×5m) — **no era eso**: las 18 aristas, incluida la de 221m, dieron un ancho local correcto (~5.00-5.01m) sin ninguna región nula o degenerada.
- **Arreglo**: la decisión de lado ahora se toma **una sola vez** (con la primera arista, usando el método viejo de comparación contra el punto lejano) y de ahí en adelante se propaga usando el vértice propio de cada arista (`p1` de la arista, que SIEMPRE cae casi exacto en uno de los dos bordes del recorte local — sin la ambigüedad de comparar contra un punto lejano). `urb:create-accessibility-features-segmented` ahora tiene variables locales `p1-v`/`boundary-side`/`side-decided`/`prefer-boundary` para esto.
- **Verificado con el mismo punto de referencia problemático** (el que causaba el volteo): las 18 aristas ahora dan el mismo lado (`MIN`) de punta a punta, sin ningún cambio — confirmado por script, no solo visualmente.
- **Nota de método para la próxima sesión**: `vla-ZoomWindow` es un método de `AcadApplication`, NO de `AcadDocument` (`(vla-ZoomWindow (urb:doc) ...)` falla con "unknown name: ZoomWindow" y aborta el resto del script sin avisar) — usar `(vla-ZoomWindow (vlax-get-acad-object) ...)` o mejor `(command "_.ZOOM" "_W" pt1 pt2)`. Para screenshots reales de una sesión headless: **`PNGOUT`/captura de pantalla vía PowerShell (`System.Drawing.Graphics.CopyFromScreen` + `GetWindowRect`) requiere que la ventana esté en PRIMER PLANO** (`SetForegroundWindow`/`ShowWindow`) — si el usuario tiene otra ventana encima (le pasó al usuario estar jugando mientras esto corría), la captura sale de lo que esté tapando AutoCAD, no del dibujo. `SendKeys` para controlar una ventana de otro proceso es poco confiable (fue a parar a una pestaña de Edge en vez de AutoCAD) — evitar, usar siempre comandos dentro del propio `.lsp`/`.scr`.
- **Seguridad del archivo real confirmada**: se abrió/modificó/cerró `URB_MASTER_GENERAL.dwg` más de 10 veces en esta sesión sin guardar nunca — verificado en cada paso comparando timestamps de `.dwg`/`.bak` (sin cambios, siempre 2026-08-03). Cuando un script crea entidades de prueba, **no usar `_.QUIT`/`_Y`** en el `.scr` (con cambios sin guardar puede disparar un dialogo de "guardar cambios" ambiguo) — mejor terminar el script sin QUIT y matar el proceso por PID (`Stop-Process -Force`) desde afuera, que no pasa por ningún flujo de guardado.
- **Pendiente**: que el usuario confirme en su sesión real que la guía/el toperol ya no saltan de lado en un andén curvo real.

### 2026-08-04 — Cuarto bug real: guía/toperol se veían partidos en cada segmento de la curva, no continuos

El usuario probó el arreglo del bulge (entrada de abajo) en su proyecto real y mostró una captura: el toperol y la guía seguían viéndose partidos en trozos con huecos visibles, no como una sola franja continua.

- **Causa real**: `urb:create-accessibility-features-segmented` procesa la franja guía/toperol **arista por arista** de la cadena real del andén (cada arco real, tras `urb:lwpoly-points-with-arcs`, queda subdividido en ~8 cuerdas cortas — o sea que una sola curva de 60° genera ~8-9 "segmentos" independientes). El problema: `urb:fill-tactile-symbols` (la función que reparte los círculos/cápsulas táctiles cada 5cm) **reiniciaba su propia retícula desde cero en cada segmento** (`u = umin + margen` local), en vez de continuar la secuencia global de 5cm arrancada al inicio de todo el corredor. Resultado visual: cada segmento (¡8-9 solo en la curva!) dejaba su propio margen de inicio/fin sin símbolos, sembrando una costura visible en cada unión — exactamente el patrón "partido" de la captura del usuario.
- **Arreglo**: nuevo parámetro `phase-offset` (distancia acumulada desde el arranque de toda la cadena hasta el inicio del segmento actual), agregado a `urb:fill-tactile-symbols`, `urb:decorate-accessibility-strip` y calculado/acumulado en `urb:create-accessibility-features-segmented` (variable `cum-offset`, suma `(- umax umin)` de cada arista tras procesarla). Con esto la retícula de 5cm es **una sola progresión aritmética continua** a lo largo de todo el corredor — el margen de inicio/fin solo se respeta en los dos extremos de TODO el andén, no en cada costura interna entre segmentos. La versión no-segmentada (`urb:create-accessibility-features`, para andenes rectos simples) pasa `phase-offset=0.0` fijo — comportamiento idéntico al de antes, sin regresión ahí.
- **Verificado con corredor sintético recto(10m)+curva real de 60°/R=15m(bulge, no facetas)+recto(10m), guía y toperol "Sí"**: se midió la posición de cada símbolo (cápsula/círculo) a lo largo del borde real de referencia (`vlax-curve-getDistAtPoint`) y se buscaron huecos > 0.15m entre símbolos consecutivos ordenados.
  - Primer intento de medición (proyectando contra el polígono cerrado completo, 4 lados): reportó huecos falsos de ~40m — **descartado como artefacto de medición**, no un bug real: cerca de las esquinas la proyección al punto más cercano puede saltar ambiguamente al lado opuesto del polígono cerrado (el conteo de símbolos, 6158, ya era matemáticamente incompatible con un hueco real de 40m en un corredor de 38.3m de largo).
  - Medición correcta (proyectando solo contra el borde exterior real, polilínea abierta, sin esquinas): **hueco máximo 0.0538m (guía) y 0.0501m (toperol) — prácticamente el espaciado nominal de 5cm, cero huecos mayores a 0.15m**, cobertura continua en todo el rango 0.025–38.288m del corredor. Conteo de símbolos (6158 guía, 6158 toperol) consistente con retícula completa de 8 filas × 0.05m sin desperdicio en las costuras internas.
- **Pendiente**: que el usuario confirme visualmente en su sesión real (recargar el `.lsp`) que la guía y el toperol ahora se ven como una sola franja continua en su andén curvo+recto.

### 2026-08-04 — Tercer bug real: metros lineales de guía/toperol subestimados en curvas cerradas (proyección sobre un eje, no arco real)

Continuación del mismo día. El usuario pidió verificar explícitamente si las cantidades (no solo el dibujo) cambian con las curvas, y correr varias pruebas.

- **Hallazgo**: `AREA_M2` siempre estuvo bien (viene de `vla-get-Area`, consulta nativa de AutoCAD que ya entiende arcos). Pero `urb:anden-finish-quantities` calculaba `corridor-length` (la base de `LOSETA_GUIA_ML`/`LOSETA_TOPEROL_ML`, y del reparto gris/blanco en formato 20x20) proyectando los puntos del contorno sobre UN solo eje (`urb:project-bounds`) — un método que estructuralmente no puede converger a la longitud real de un arco por más puntos que se le den (proyectar sobre una recta un punto que se aleja de esa recta siempre acorta la medida).
- **Prueba con curva cerrada (radio ~10m, giro de 90°, como una entrada vehicular)**: `GUIA_ML` daba 18.30m contra un arco real de 20.42m — **~10% de menos material** del que corresponde. Con curva suave (radio ~250m, la real del proyecto) el error era insignificante (40.45 vs 40.49m, ~0.1%) porque a esa escala la proyección casi coincide con el arco.
- **Arreglo**: `urb:anden-finish-quantities` ahora usa `urb:anden-driving-chain`/`urb:chain-total-length` (la misma cadena de segmentos reales del arreglo de hoy) para sumar la longitud real del lado guía cuando hay 2 o más aristas reales (anden curvo); si no, conserva la proyección de siempre (da exactamente lo mismo en un anden recto/simple, sin cambio de comportamiento ahí).
- **Verificado con las mismas 3 pruebas**: curva suave 40.4911 (vs 40.49 calculado a mano), curva cerrada 20.3876 (vs 20.42 calculado a mano, error residual ~0.15% por el muestreo de 8 puntos por arco), recto 25.0000 exacto sin cambio. `AREA_M2` identica en los 3 casos antes/despues (como se esperaba, no dependia de este calculo).
- **No revisado a fondo**: el reparto gris/blanco dentro del área de acabado en formato 20x20 (`length-value`, usado solo para la proporción loseta-gris/adoquin-blanco) sigue usando la proyección de un eje — se evaluó que el impacto es mucho menor (es una proporción de patrón repetitivo, poco sensible a la longitud exacta) y se dejó así por ahora; si se necesita revisar con precisión, aplicar el mismo patrón de `urb:chain-total-length`.

### 2026-08-04 — Segundo bug real: los arcos dibujados con PLINE opción Arc (bulge) no se seguían en absoluto

Continuación del mismo día. El usuario probó el arreglo anterior en su sesión real creando un andén sobre un tramo curvo + uno recto, y mostró capturas: el resultado quedaba partido en pocos paneles rectos con costuras marcadas, nada suave.

- **Causa real**: `urb:lwpoly-points` (usada en toda la base de código, incluida la nueva `urb:anden-driving-chain`) solo lee los vértices de la polilínea (grupo DXF 10) e **ignora por completo el bulge** (grupo 42, el arco real que guarda `PLINE` cuando se usa la opción `Arc`). El usuario dibuja la curva como un arco real de verdad, no como muchos segmentos rectos cortos — así que todo el arco se leía como una sola cuerda recta de esquina a esquina, con la única esquina real detectada en sus dos extremos. Esto es una limitación preexistente de todo el módulo de andenes, no algo introducido hoy.
- **Arreglo**: nueva `urb:lwpoly-points-with-arcs` (usada solo en `urb:create-composite-loseta` y `urb:create-accessibility-features`, sin tocar `urb:lwpoly-points` original ni sus demás usos en el archivo) que detecta segmentos con bulge≠0 y los subdivide en 8 puntos intermedios siguiendo el arco real.
  - **Primer intento con trigonometría propia (bulge→círculo) — bug de signo**: al probarlo con un andén de 4 vértices con arco real (igual a como lo dibuja el usuario), 14 de 18 puntos calculados caían fuera del radio esperado. En vez de seguir depurando la fórmula a mano, se reemplazó por `vlax-curve-getParamAtPoint`/`getPointAtParam` sobre la polilínea real — la curva ya la interpreta AutoCAD correctamente, no hay que re-derivarla. Con esto: 0 de 18 puntos fuera de rango, ajuste exacto.
- **Verificado**: recreando el escenario exacto del usuario (andén de 4 vértices, radio real ~250m confirmado el día anterior, arco de verdad vía bulge) el resultado visual queda igual de suave que la referencia — sin huecos, sin costuras, la reticula sigue el arco real completo.
- **Pendiente**: que el usuario confirme en su sesión real (recargar el `.lsp`) que el andén curvo+recto que mostró en las capturas ahora se ve bien.

### 2026-08-04 — Se resuelve la curva: bug real encontrado (colapso de ángulo por eje) + confirmado que la librería de bloques no es reutilizable

Continuación del mismo día (después de la entrada de abajo, "se descarta el enfoque procedural"). El usuario pidió: (1) que se sacaran las medidas reales de todos modos, (2) explicación clara de qué se estaba haciendo, (3) confirmar si las cantidades ya salen bien sin esto, (4) confirmar si estos bloques pesados explican la lentitud que ha sentido al coordinar/abrir el proyecto completo.

- **Cantidades**: confirmado que ya son correctas independientemente del patrón visual — dependen solo de área y tamaño de baldosa (aritmética simple), no de qué tan bien se vea el dibujo. Este hallazgo no cambia código, solo tranquiliza sobre el alcance real del problema.
- **Riesgo de lentitud**: confirmado como sospecha razonable — cada módulo de curva trae ~105 bloques anidados (baldosa + hatch cada uno); replicar la librería completa en todo el proyecto probablemente heredaría el mismo problema de lentitud que ya vivió el usuario. El usuario aclaró que **solo le preocupa la curva y la rampa**, no el tramo recto (que es la mayoría del largo del proyecto) — esto acota mucho el riesgo si se llegara a usar bloques reales solo ahí.
- **Medición de Curva N / Tramo M — 2 intentos fallidos, 1 exitoso**:
  1. Ajustar un círculo a las 105 baldosas de un módulo (intento anterior): residuo grande, no sirve.
  2. Separar la fila recta de entrada antes de ajustar (usando que las primeras baldosas caen en una secuencia lineal de exactamente 0.20m): tampoco sirvió — el residuo seguía siendo grande porque cada módulo tiene **varias hileras de baldosas a lo ancho del andén**, cada una a un radio distinto; mezclarlas todas en un solo ajuste nunca converge bien (el "error" que se veía era en realidad el ancho del andén disfrazado).
  3. **Enfoque que sí funcionó**: en vez de ajustar círculo a las baldosas DENTRO de un módulo, se buscaron todas las **inserciones reales** de cada tipo de módulo de curva en el dibujo completo (`ssget` + `wcmatch` sobre nombre de bloque) y se ajustó el círculo a esos puntos de inserción (varias decenas por tipo, ej. 33-34 para "Curva 2 - Tramo 8"). Resultado: **residuo de 0.0001-0.0013m** (prácticamente perfecto) — **radio real ≈ 250m**, mismo centro para varias combinaciones Curva/Tramo distintas.
- **Hallazgo clave que cambia el diagnóstico completo**: un radio de 250m es una curva de vía muy suave (casi recta a la escala de un andén de 7m de ancho). La curva de prueba sintética usada en el intento anterior (radio 8-13m, como una entrada de garaje) era **muchísimo más cerrada que cualquier curva real del proyecto** — exageró el efecto de abanico y llevó a la conclusión equivocada de que hacía falta la librería de bloques.
- **Bug real encontrado al reprobar con radio realista**: con una curva de 250m de radio, `urb:create-composite-loseta` (el arreglo del commit `68e3476`) solo rellenaba la mitad del andén, dejando la otra mitad en blanco. Causa: `urb:polygon-corner-indices` reutilizaba el ángulo de arista ya calculado por `urb:polygon-edge-records`, que pasa por `urb:normalize-axis-angle` (colapsa un ángulo y su opuesto a 180° al mismo valor — correcto para agrupar por eje, pero no para medir giros direccionales). Como la tangente de la curva de prueba pasaba cerca de 0°/180°, el colapso generaba un salto falso de ~180° justo ahí, partiendo el lado guía en dos cadenas de 5 aristas en vez de una de 10 — dejando la mitad del andén sin procesar (`ESQUINAS=(0 5 10 11 16 21)` en vez de `(0 10 11 21)`). **Corregido**: `urb:polygon-corner-indices` ahora recalcula el ángulo direccional completo (`urb:normalize-full-angle`) desde los extremos de cada arista en vez de reusar el campo ya colapsado.
- **Verificado tras el arreglo**: con la misma curva de 250m, el andén se rellena completo y la retícula sigue la curva de forma suave y natural — visualmente muy parecido a como se ve la referencia real en `U-201.dwg`.
- **Conclusión**: el enfoque procedural del commit `68e3476` era correcto desde el principio; lo que hacía falta era este bug fix, no una librería de bloques. **No se trajo la librería de bloques al programa** — se descarta esa dirección dado que (a) no es reutilizable (bloques hechos a la medida para las curvas específicas de este proyecto, no un catálogo genérico), (b) las cantidades ya funcionan sin ella, y (c) replicarla arriesgaba reintroducir el problema de lentitud. Queda como posibilidad futura solo si el usuario decide que vale la pena el costo de lentitud a cambio de fidelidad visual exacta con el plano de detalle — no se cerró la puerta, pero no se sigue por ahora.
- **Pendiente**: probar en la sesión real del usuario un andén curvo real del proyecto (no la curva sintética de prueba) para confirmar que el resultado visual final es satisfactorio.

### 2026-08-04 — Modulación de andenes en curvas: se descarta el enfoque procedural, la referencia usa una librería de bloques estándar

Continuación del mismo día del commit `68e3476` (ver entrada de abajo). El usuario comparó el resultado del arreglo de curvas contra capturas reales de `U-201.dwg` a mayor detalle y confirmó que **seguía sin parecerse**. Se investigó a fondo antes de seguir tocando código:

1. **Se probó una segunda hipótesis** (paneles discretos con costura visible, agrupando aristas hasta acumular un giro de 20°, con toperol automático en cada quiebre real) como función de comparación aparte (`demo:create-composite-loseta-panels`, solo de prueba, no se guardó en el archivo principal) — tampoco coincidió con la referencia. El usuario pidió verificar el plano directamente en vez de seguir adivinando visualmente.
2. **Hallazgo real, con el archivo abierto e inspeccionado directamente** (`entget`/`tblnext` sobre `U-201.dwg`, no solo visual): la franja de modulación de la referencia **no es geometría calculada por fórmula en absoluto** — es una librería de bloques estándar dibujados a mano, insertados y rotados a lo largo del andén. Jerarquía de 3 niveles encontrada:
   - **Nivel 0 (baldosa individual)**: `B-TABLETA 20X20 TONO 1/2`, `B-TABLETA 20X10 TONO 2`, `B-TABLETA 20X20 TÁCTIL ALERTA` (9 círculos reales = toperol, confirma que usar círculos era el camino correcto — solo que van organizados 3×3 por baldosa, no repartidos libremente como se había hecho).
   - **Nivel 1 (módulo armado, 20 a 105 baldosas)**: `B-Módulo 1/7/8/9` (tramos rectos), `B-Módulo1/2/3 - Curva N - Tramo M` (paneles curvos por radio de curva "Curva 1/2/3" y ancho de andén "Tramo 5/6/7/8"), `B-Módulo P.C. CURVA` / `B-Módulo P.C. CURVA BLANCA` (pieza de transición en el Punto de Curvatura — donde probablemente ya viene el cierre con toperol que mencionó el usuario), `B-Módulo Rampa AxB` (rampas por combinación de anchos).
   - **Nivel 2 (ensamble completo)**: `B RAMPA T1/T2` (rampa + bordillo + accesorios en un solo bloque, referencia otros bloques vía `INSERT`).
   - Catálogo completo: 61 bloques con nombre `B-*`/`B *` en este único archivo (puede haber más variantes en `U-202` a `U-207`, no revisados aún).
3. **Se buscó un índice acotado** de qué ancho/radio real corresponde a cada "Tramo N"/"Curva N": la carpeta `PLANOS\VERSION 2\PDF\Cartilla detalles de andenes` (14 PDFs) resultó ser sobre la composición general de la sección urbana (franjas de circulación/paisajismo/mobiliario, "Módulo 1A/2A/1C/2C" ahí es otra cosa), no el catálogo de curvas. **No se encontró un índice documentado** — el mapeo Tramo/Curva → dimensión real probablemente hay que sacarlo midiendo la geometría de cada bloque directamente.

**Decisión con el usuario**: en vez de seguir con generación procedural (abanico continuo o paneles discretos, ninguno coincide), traer la librería de bloques real al programa. Plan en 3 pasos:
1. ~~Catalogar qué bloques existen y su jerarquía~~ (hecho arriba).
2. **Medir cada variante real** (Curva 1/2/3, Tramo 5/6/7/8, anchos de rampa) — **intentado, resultado no confiable todavía**:
   - `vla-GetBoundingBox` sobre una instancia insertada da un ancho "cuadrado" (~7.8×7.0m) para los tramos rectos — el panel no está dibujado alineado a los ejes X/Y internos del bloque, así que el bbox en ejes del mundo sobreestima ambas dimensiones. Hay que rotar al eje real antes de medir.
   - Se extrajeron las posiciones y rotaciones de las 105 baldosas de cada módulo de curva directamente de la definición del bloque (`entnext`/`tblobjname`, sin insertar ni explotar nada — técnica confiable, sin diálogos ni cuelgues) a CSV, y se intentó ajustar un círculo (Python, mínimos cuadrados) para sacar el radio real. **Resultado no confiable**: el residuo del ajuste es demasiado grande (0.6-0.8m promedio, hasta 1.4m) porque las 105 baldosas cubren TODA el área 2D del panel (varias hileras a radios distintos), no una sola fila sobre un arco — ajustar un único círculo a todas mezcladas no tiene sentido. Además las rotaciones de las baldosas casi no varían (2.4°-3.1° en todo el módulo), lo que sugiere que la curva se logra con baldosas en forma de cuña (no cuadradas rotando), no con el mecanismo que se había asumido.
   - **Pendiente**: separar las baldosas por "hilera" (radio aproximado) antes de ajustar circulo por hilera, o mejor, leer las cotas/textos ya dibujados en el plano (labels con las medidas) en vez de reconstruir la geometria por fuerza bruta.
3. Construir la lógica de selección + inserción/rotación en la herramienta, y extraer las definiciones de bloque a un archivo de soporte que la herramienta pueda insertar. No iniciado.

**No se modificó el archivo principal en esta parte de la sesión** (el commit `68e3476` de curva-por-segmento + tactil-geométrico sigue siendo lo último subido; queda pendiente decidir si ese enfoque procedural se conserva como alternativa cuando no hay bloque de catálogo disponible, o se descarta del todo una vez lista la inserción de bloques reales).

**Nota para retomar**: esta sesión se volvió muy larga (decenas de aperturas de Civil 3D headless). El paso 2 (medir Curva/Tramo reales) conviene retomarlo con la cabeza fresca, probablemente separando baldosas por hilera antes de ajustar círculo, o pidiéndole al usuario que confirme las dimensiones reales si las tiene documentadas en otro lado (no se encontraron en la Cartilla de detalles de andenes revisada).

### 2026-08-04 — Modulación de andenes: sigue el contorno real en curvas + tactil real (guía/toperol)

El usuario pidió revisar visualmente cómo deben verse los andenes contra un plano de referencia real (`U-201.dwg`, carpeta `MEMORIAS\V3\PROYECTO_URBANISMO_GENERAL\01_DISENOS_BASE\ANDENES`). Se abrió ese DWG con Civil 3D headless (ver [TESTING_CIVIL3D.md](TESTING_CIVIL3D.md)) y se exportó a PNG para comparar. Dos hallazgos reales, ambos corregidos:

1. **En tramos curvos la modulación no seguía la curva**: `urb:decorate-composite-region` calculaba un único ángulo para todo el andén (o como mucho 2, para una esquina). En un andén curvo la reticula quedaba recta mientras el borde se curva, desviándose segun uno se aleja del punto de referencia. Corregido con segmentación por el contorno real (no por longitud fija, a pedido explícito del usuario): nuevas `urb:polygon-corner-indices`/`urb:polygon-chains-at-corners`/`urb:anden-driving-chain` identifican el lado largo del andén como una cadena de vertices reales entre esquinas (giros > 45°), y `urb:decorate-composite-region-segmented` modula cada arista de esa cadena con su propio ángulo local, reutilizando `urb:clip-stripe`/`urb:decorate-composite-region` sin modificarlos. `urb:create-composite-loseta` usa este camino solo cuando el lado guía tiene 2+ aristas reales; un andén simple (4 vértices) sigue exactamente por el código anterior sin cambios (0 riesgo de regresión ahí).
2. **Guía y toperol no se parecían nada a la loseta táctil real**: el código usaba patrones `.pat` (rayas rectas para guía, puntos de longitud cero para toperol) — el formato `.pat` de AutoCAD solo puede construir familias de líneas rectas, nunca iba a lograr los círculos huecos (toperol) ni las cápsulas de extremo redondeado (guía) que se ven en la referencia. Reemplazado por geometría real: `urb:add-circle-symbol` (CIRCLE real) y `urb:add-capsule-symbol` (LWPOLYLINE de 4 vértices con bulge=1 en 2, forma cápsula), repartidos cada 5cm por `urb:fill-tactile-symbols`. `urb:create-accessibility-features` también necesitó el mismo arreglo de segmentación por curva (`urb:create-accessibility-features-segmented`) — si no, el ancho de la franja se seguía calculando proyectando TODO el andén sobre un solo ángulo, dando un ancho falso e inflado en curvas (primera prueba: 16821 cápsulas en una franja de prueba, un error real que se encontró y corrigió antes de dar esto por bueno).
3. Quedó pendiente **sin tocar**: el usuario mencionó "guía vs toperol no se parecen en nada" como 2 de 2 hallazgos — el segundo (patrones `.pat`) ya está resuelto arriba; no se identificó un tercer punto ("otra cosa") en esta sesión.
4. **Verificado**: balance de paréntesis de todo el archivo (2 rondas, se encontraron y corrigieron 2 errores propios de comentarios con corchete/paréntesis desbalanceado, no del código real). Prueba headless con `entmake` (sin pasar por el diálogo interactivo): un andén curvo sintético (giro de 90°, radio 8-13m, 10 segmentos por lado) y un andén rectangular simple. Confirmado por conteo de entidades (1572 círculos toperol = 1572 cápsulas guía, coincide con la geometría esperada de la franja) y visualmente por captura PNG: la reticula ahora abre en abanico siguiendo la curva (igual que la referencia real), el rectángulo simple da exactamente el mismo resultado que antes del cambio, y la franja táctil muestra símbolos individuales reales, no un hatch.
5. **No verificado** (requiere la sesión real del usuario): el flujo completo desde el diálogo interactivo (`URBANISMO → Crear → Andén`, `Si`/`Si` en guía/toperol) sobre un andén curvo real de su proyecto, y que el resultado visual final coincida a satisfacción del usuario con `U-201.dwg`.

### 2026-08-04 — Recálculo en lote de tramos existentes contra la referencia de relleno actual

El usuario verificó a mano (contra los datos reales del tramo 32-33: profundidades, cama, pendiente, volúmenes de excavación/relleno/sobrante, todo cuadró con la tolerancia esperada por muestreo de perfil real) y preguntó si el cálculo estaba yendo hasta terreno natural o subrasante de vía, y si cambiar la configuración `MP_TRAMO_RELLENO_MODO` actualizaba solos los tramos ya creados. Respuesta encontrada leyendo el código: **no** — ese modo solo se lee una vez, al crear el tramo (`mp:insert-tramo-forced`), y queda "horneado" en los atributos del bloque; ni mover un extremo ni editar el tramo (`mp:sync-tramo-values`, usada por ambos flujos) lo vuelve a consultar.

Se agregó `mp:recalc-tramos-earthworks-command`, nuevo botón "Recalcular tramos existentes con la referencia actual" en `URBANISMO -> Configuración -> Movimiento de tierras` (junto al botón que ya cambiaba `MP_TRAMO_RELLENO_MODO`), no un comando nuevo aparte:

- Recorre con `ssget "X"` todos los bloques `TRAMO_ARESIDUAL`/`TRAMO_ALLUVIAS` del dibujo (tramos a gravedad; acueducto no aplica, el modo de relleno no lo afecta) y para cada uno llama `mp:update-block-after-edit` (mismo mecanismo que ya usa "Diagnosticar y migrar redes"), que dispara `mp:sync-tramo-values` → `mp:derive-tramo-values` con los valores actuales del bloque.
- Se le preguntó al usuario cómo resolver la vía de referencia en modo "Subrasante" para un lote (no hay garantía geométrica de una sola vía "obvia" sobre cada tramo — cruces, tramos bajo zona verde, etc.). Eligió la opción segura: pedir la vía con `entsel` tramo por tramo (igual que al crear uno nuevo), en vez de detección automática por cercanía. Si el usuario cancela la selección de un tramo puntual, ese tramo se deja sin tocar (no se sobreescribe con un cálculo a terreno natural sin pedirlo) y queda contado como "omitido" en el resumen final.
- En modo "Terreno" no pregunta nada: recalcula todos los tramos a gravedad directo contra terreno natural.
- Todo dentro de un solo `vla-StartUndoMark`/`vla-EndUndoMark` para poder deshacer el lote completo de una vez si algo sale mal.
- **Verificación**: no se pudo probar cargando en una segunda instancia headless de Civil 3D porque el usuario tenía su propia sesión abierta (`URB_MASTER_GENERAL.dwg`) y una segunda instancia de `acad.exe` se quedó colgada en la pantalla "Start" — probablemente contención de licencia de un solo puesto, no un bug del código; se cerró esa instancia de prueba sin tocar la sesión real del usuario. En su lugar se verificó el balance de paréntesis de **todo** el archivo con un script externo (PowerShell, respeta strings `"..."` y comentarios `;`), que dio profundidad final 0 y ningún cierre de paréntesis de más en ningún punto del archivo — confirma que la función nueva y el DCL quedaron bien formados. Pendiente: probar el botón en vivo en la sesión real del usuario (recalcular en modo Subrasante pidiendo la vía tramo por tramo).

### 2026-08-03 — Tramos: cota clave por selección + referencia de relleno configurable

A partir de una pregunta del usuario sobre si el relleno de una zanja bajo una vía debería topar en el terreno natural o en la subrasante de la vía (dos secuencias constructivas distintas, ver diagrama discutido en sesión), se agregaron dos prompts nuevos después del diálogo de tramo (`mp:insert-tramo-forced`), sin tocar el DCL:

- **Cota clave [Digitar/Seleccionar]**: `mp:prompt-clave-from-label` usa `nentsel` (no `entsel`, porque las etiquetas de cota viven dentro de xrefs como "RESIDUAL") para leer el número directo de una etiqueta ya dibujada, evitando transcribir a mano (motivado por un error real de transcripción en esta sesión: 2559.63 leído en pantalla vs 2559.47 en el atributo `RASANTE` del bloque `PzProyMaip`, nunca resuelto — el usuario dio los valores correctos a mano).
- **Referencia de relleno [Terreno/Subrasante_via]** (solo aplica a tramos a gravedad, sanitario/pluvial): si se elige Subrasante, `mp:select-road-subrasante-reference` reutiliza el mismo mecanismo de vinculación que ya usa el andén (`urb:select-anden-road-grade`) para tomar la rasante guardada de una vía ya creada, le resta la profundidad de su perfil (`urb:road-profile-depth`) para llegar a la subrasante, y `mp:tramo-depth-profile` usa `min(terreno,subrasante)` en cada uno de los 10 puntos muestreados en vez de solo terreno. Con esto el relleno del tramo ya no cuenta la franja que la vía va a volver a cortar por separado hasta su subrasante.
- Se agregó `*mp-tramo-road-ref*` (global, se pone y se quita alrededor de cada llamada, nunca queda encendido entre comandos) para pasar la referencia sin cambiar la firma de `mp:derive-tramo-values`/`mp:insert-cant-tramo`.
- `METODO_CANTIDADES` del tramo queda con el sufijo " (ref. subrasante via)" cuando se usó esa opción, para que quede trazable en el atributo sin tener que agregar un campo nuevo al esquema del bloque.
- Verificado con datos sintéticos controlados (terreno inventado, sin depender de ninguna superficie real): con subrasante, la profundidad en la zona de corte de vía bajó de 7.3 a 4.3 (el efecto esperado); sin cambios en la zona donde el terreno ya está por debajo de la subrasante. Lectura de etiqueta también verificada (texto "2557.83" se lee y parsea igual).
- **No verificable de punta a punta sin el usuario**: los 2 prompts nuevos usan `getkword`/`nentsel`/`entsel`, todos interactivos — no se pueden probar en modo headless, solo la lógica interna que llaman.
- **Ajuste posterior el mismo día**: el usuario pidió que la referencia de relleno (Terreno/Subrasante) no se preguntara en cada tramo, sino que se configurara una sola vez. Se movió a `URBANISMO -> Configuración -> Referencia de relleno de tramos de red` (`mp:network-fill-reference-command`, nuevo botón en el DCL del menú principal), persistido en el dibujo con `urb:config-write`/`urb:config-read` bajo la clave `MP_TRAMO_RELLENO_MODO` (mismo mecanismo que `URB_DRAWING_ID`). `mp:insert-tramo-forced` ahora lee esa configuración en vez de preguntar; si el modo es "Subrasante" sigue pidiendo seleccionar la vía específica de referencia (eso sí es por tramo, no se puede generalizar). Verificado: ida y vuelta de la configuración (`write`/`read`) y que el DCL del menú con el botón nuevo carga sin errores de sintaxis.
- **Segundo ajuste**: el usuario probó el diálogo real y pidió 2 cambios más sobre `maipore_tramo_red` (DCL de `mp:write-dcl`, funcion `mp:dialog-tramo-red`):
  - El prompt de cota clave (Digitar/Seleccionar) SÍ se movió, a pedido explícito, DENTRO del diálogo como `radio_row` (`cc_dig`/`cc_sel`) con `action_tile` que hace `mode_tile` en vivo sobre los 2 `edit_box` de cota clave (habilitados si Digitar, deshabilitados si Seleccionar) — antes se preguntaba con `getkword` después de cerrar el diálogo, y los campos quedaban editables sin importar la eleccion. El resultado de la eleccion viaja en el alist devuelto por el diálogo como `"MODO_CLAVE"`.
  - Se sacó el campo "Pendiente %" del diálogo (edit_box `"pend"`) porque el usuario no quería digitarla manualmente — pero **se dejó intacto el cálculo automático**: `mp:dialog-tramo-red` ahora siempre devuelve `PENDIENTE=""`, que es exactamente la rama que ya existía en `mp:derive-tramo-values` para autocompletar desde las cotas clave cuando el campo viene vacío (mismo camino confirmado en la verificación del tramo 32-33: dio 1.996% sin digitar nada). El campo equivalente en el diálogo de EDITAR un tramo ya creado (`edit_tramo_red`, `mp:edit-dialog-tramo-red`) es una función y un DCL distintos — no se tocó, sigue con su propio campo "pend".
  - Verificado leyendo el texto del `.dcl` generado (sin abrir el diálogo en sí — abrir un dialogo con `new_dialog` sin `start_dialog` dejó el proceso de prueba colgado una vez en esta sesión, mejor evitarlo): el radio_row y los 2 edit_box de cota clave quedan bien formados, y "Pendiente %" ya no aparece.
- **BUG real encontrado por el usuario al probar en su sesión** (no relacionado con los cambios de arriba, preexistente): `mp:validate-tramo-values` comparaba `ANCHO_ZANJA` (guardado redondeado a 2 decimales via `rtos`) contra un `minimum-width` recalculado SIN redondear en el momento — para tramos que caen en la formula generica `max(0.60, diametro+0.40)` (no gravedad, o sin profundidad conocida) casi nunca da un numero limpio a 2 decimales (8" -> 0.6032), así que el ancho guardado (0.60) siempre quedaba "por debajo" del mínimo recién calculado (0.6032), aunque fueran el mismo valor. Se corrigió redondeando `minimum-width` a la misma precisión antes de comparar. Verificado: con cotas clave vacías el mensaje de ancho ya no aparece (solo quedan los mensajes legítimos de "faltan cotas"); con cotas clave completas da `CONTROL_ESTADO: OK` limpio.
- **2 bugs más encontrados en vivo probando "Seleccionar en dibujo" con el usuario:**
  1. `mp:gettile "cc_sel"` (para leer que radio quedó marcado, DESPUÉS de cerrar el diálogo) intentaba leer `get_tile` directo sobre un diálogo ya cerrado porque `"cc_dig"`/`"cc_sel"` nunca se agregaron a la lista fija de claves que `mp:capture-dialog-values` guarda ANTES de cerrar (`mp:dialog-tramo-red`, línea ~5487) — por eso el radio se veía bien deshabilitando los campos en vivo, pero después de aceptar siempre se comportaba como si hubiera quedado en "Digitar". Corregido agregando ambas claves a esa lista.
  2. `mp:prompt-clave-from-label` parseaba `vla-get-TextString` del objeto seleccionado directo con `mp:numeric-real` — pero las etiquetas reales (MLeader) traen la cota pozo Y la cota clave apiladas en el MISMO objeto, con códigos de formato MTEXT crudos (`\pxt6;{\Fsimplex|c0;2559.63\P2557.83}`, donde `\P` separa las 2 líneas). El parser mezclaba dígitos sueltos de esos códigos (el "6" de "pxt6", el "0" de "c0") con la cota real, dando basura como "62556.310" en vez de "2556.31". Se agregó `mp:last-decimal-number`, que busca específicamente el ÚLTIMO número con punto decimal en el texto (los códigos de formato solo tienen dígitos sueltos sin punto, así que no se confunden) — la cota clave es siempre la línea de abajo en la etiqueta apilada. Verificado con el texto crudo exacto de los pozos 32 y 33 del usuario: da 2557.83 y 2556.31 exactos; el caso de un TEXT plano sin formato sigue funcionando igual.

### 2026-08-03 — Movimiento de tierras de redes: se resuelve la cimentación (Figura 4) y se activa

El usuario aportó la Figura 4 (tuberías flexibles, K=0.083): la cama bajo el tubo es `Bc/4` con mínimo 100mm y máximo 150mm — resuelve el punto que había quedado pendiente el 2026-08-02.

- **`mp:pipe-bedding-thickness`** (nueva): `min(0.15, max(0.10, diametro_m/4))`. `mp:derive-tramo-values` la usa como valor por defecto de `ESPESOR_CAMA` cuando no viene digitado (el diálogo actual no expone ese campo, así que siempre caía en el default — antes fijo en 0.10m para cualquier diámetro, ahora varía con el diámetro real).
- **`*mp-network-construction-enabled*` pasó de `nil` a `T`**: hasta ahora todo el cálculo de movimiento de tierras de redes (excavación/cama/relleno/sobrante/reposición) estaba completo en el código pero apagado por este interruptor — cualquier tramo creado antes de hoy quedaba con esos campos vacíos y `METODO_CANTIDADES = "PENDIENTE_PARAMETROS"`, sin importar qué cotas se digitaran.
- **BUG encontrado y corregido al activarlo** (mismo patrón que `distance`/`type`/`last`, ya documentado antes en este archivo): `mp:integrate-trench-volume` tenía un parámetro llamado literalmente `length`, que tapaba la función nativa justo en la línea `(setq n (length depths))` → `bad function: <valor numerico>`. Nunca se había ejercitado porque el interruptor estaba en `nil`. Renombrado a `total-length`.
- **Verificado contra Civil 3D real** (superficie `SUP_TN` de `URB_MASTER_GENERAL.dwg`, sin guardar cambios en el archivo): 3 tramos sanitarios de 8", 18" y 30" de diámetro, cada uno cruzando un rango distinto de la fórmula de cama (piso 0.10, intermedio 0.11, techo 0.15). Los 3 dieron `CONTROL_ESTADO: OK`. Se recalculó a mano la profundidad, pendiente, ancho por tabla, volumen del tubo, cama y reposición del tramo de 8" contra los valores que escribió el programa — coinciden exactos. El ancho de zanja por tabla también coincidió en los 3 diámetros contra el bracket de profundidad correspondiente.
- Ver también la verificación de andén y vía sobre esa misma superficie real (metodología y hallazgos en la sesión del 2026-08-03, no repetida aquí en detalle).

### 2026-08-03 — Consolidación de capas (Andenes, Vías, Zona Verde, Prefabricados)

A pedido explícito del usuario se redujo drásticamente el número de capas que crea el programa, organizadas primero como Property Filters propuestos y luego implementadas:

- **Andenes**: de ~14 capas a 9 (las 8 de material + `URB-ANDEN` como capa final). Se retiró el material "Adoquín" (capa dedicada + patrón propio sin equivalente en las capas conservadas; el código de cantidades/Excel para andenes Adoquín viejos se dejó intacto por compatibilidad). `URB-ANDEN-AUX` (donde vivían las regiones de recorte antes de hatchear) se fusionó en la capa de material real de cada pieza. `URB-SEL-ANDEN` y `URB-ANDEN-LOSETA-LISA-20X20` eran capas muertas (nada las usaba) — eliminadas sin reemplazo.
- **Vías**: de 6 capas a 1 (`URB-VIA`).
- **Zona verde**: de 3 capas a 1 (`URB-ZONA-VERDE`).
- **Prefabricados**: de 15 capas (5 por tipo × 3 tipos) a 3 (`URB-BORDILLO`, `URB-SARDINEL`, `URB-CANUELA` — sin ñ, convención ANSI del archivo).
- **Mecanismo nuevo**: el orden de dibujo (qué hatch va arriba/abajo) y la identificación interior/exterior de prefabricados (necesaria para poder editar una pieza después) ya no dependen del nombre de la capa — se guardan como xdata (`urb:tag-generated-role`, clave `URB_ANDEN_GEN`) independiente de en qué capa quedó cada pieza. Bloques creados antes de este cambio se siguen reconociendo por su capa vieja como respaldo.
- Verificado contra Civil 3D real (dibujo en blanco): creación completa de andén, vía, tramo de red, prefabricado y zona verde, cada uno cae en la capa esperada. Ver también [TESTING_CIVIL3D.md](TESTING_CIVIL3D.md) — la técnica de verificación se corrigió en el camino (`.scr` corto + `.lsp` de ayuda en carpeta confiable, en vez de una sola línea gigante).

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

1. Probar en la sesión real del usuario (no solo la verificación headless) que un tramo de red creado desde el diálogo normal (`URBANISMO → Crear → Red`) calcula bien el movimiento de tierras ahora que `*mp-network-construction-enabled*` está en `T` — la verificación headless llamó `mp:insert-cant-tramo` directo, saltándose el diálogo `mp:dialog-tramo-red`.
2. El diálogo de tramo no expone `ESPESOR_CAMA` como campo editable — siempre usa el valor por defecto (ahora la fórmula Bc/4). Si en algún proyecto puntual el usuario necesita otro criterio de cama, no hay forma de digitarlo sin agregar el campo al diálogo.
3. Nada más quedó pendiente de las dos limpiezas de código de 2026-08-02 (dead code + duplicados) — verificadas en Civil 3D real.

### Revalidacion 2026-09-07 (Codex)
Motor 4.73.0 sin cambios: suite 50/50, instalador 4/4, estructura LSP y hash instalado correctos. Evidencia y prioridades en diagnosticos/hardening4730/REVALIDACION_20260907.md. ActiveX/Civil/Excel reales siguen pendientes; verify_real.lsp experimental.

### v4.73.1 — optimizacion y validacion nativa Maipore
Agrupacion ordenada con igualdad exacta (5000 filas: 2828 -> 94 ms), handles DXF, relleno lineal TablaAgg y aborto ante fallo de colector. Suite 50/50. Civil 3D/Excel reales en copias: 7658 filas exportadas; cantidad inyectada en J2 repuesta desde DWG; 1658 claves agregadas conciliadas. Pendiente una equivalencia Cabezal de descarga. Informe y limites: diagnosticos/optimizacion4731/README.md. Motor instalado 4.73.1.
