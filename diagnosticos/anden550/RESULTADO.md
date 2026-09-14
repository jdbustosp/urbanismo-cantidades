# Andenes 5.5.0: por que no quedan en bloque y por que tardan

Agente: Claude. Equipo: BOG085CD119BDQN. Fecha: 2026-09-14, America/Bogota.
Civil 3D 2023 Metric real, instancia propia oculta. Fixture: copia local de
`fix507/fixture.dwg` (33 MB) y dibujos LIMPIOS con contorno sintetico.
NO se abrio ni se modifico el DWG maestro del usuario.

## Sintoma reportado
"El anden se crea bien pero no queda en bloque, y generarlo se demora
muchisimo." Captura de ETAPA 5A, tramo curvo largo.

## Los dos sintomas son EL MISMO problema
Ya estaba documentado en el motor desde 2026-08-09, dentro de
`urb:package-anden`: hay un camino rapido (`-BLOCK` nativo) y uno lento
(`vla-CopyObjects`). Si el rapido falla, se cae al lento, que avisa
"varios minutos, no interrumpa"; el usuario interrumpe y el material
queda suelto. Lo que faltaba era saber POR QUE fallaba el rapido: el
motor solo decia "Empaquetado nativo no disponible", sin motivo.

## Medicion 1: la carga del motor (comprobado numericamente)

| dibujo | carga del motor |
|---|---|
| limpio | **1.469 ms** |
| copia del maestro, 33 MB | **43.843 ms** (primera corrida) / **24.750 ms** (segunda) |

`urb:repair-anden-hatches` corria en CADA carga del motor -- o sea en cada
apertura de dibujo, porque el motor se carga desde `acaddoc.lsp` -- y
recorre TODOS los bloques del dibujo y TODOS los objetos de cada uno con un
`entget` por objeto.

## Medicion 2: el sello resuelve eso (comprobado numericamente)

Con tres andenes ya empaquetados en el dibujo:

| | ms |
|---|---|
| barrido completo (`urb:repair-anden-hatches`) | **3.282** |
| con sello (`...-si-hace-falta`) | **0** |
| sin sello, vuelve a barrer | **2.906** |

La reparacion es idempotente, asi que el dibujo queda sellado con la
version que ya lo reparo y el barrido se salta mientras coincida. Al subir
de version corre una sola vez mas. En el maestro de 33 MB ese barrido
costaba entre 23 y 42 s POR APERTURA.
LIMITE: el sello vive en el dibujo, asi que el archivo debe guardarse una
vez para que persista.

## Medicion 3: guia y toperol son el 88% del trabajo (comprobado)

Contorno curvo sintetico, ancho 3,5 m, loseta 20x20, dibujo limpio:

| caso | largo | piezas | BUILD | PACK | bloque | sueltas |
|---|---|---|---|---|---|---|
| A sin guia/toperol | 188 m | 774 | 4.360 ms | 3.922 ms | SI | 0 |
| B con guia/toperol | 188 m | **6.285** | 7.437 ms | 7.594 ms | SI | 0 |
| C con guia/toperol | 376 m | **12.389** | 16.578 ms | 19.843 ms | SI | 0 |

- La franja tactil aporta 5.511 de las 6.285 piezas: el **88%**.
- Suma 3.077 ms al build (+71%) y casi DUPLICA el empaquetado.
- Cantidades correctas y completas: GUIA_ML 188,10 y TOPEROL_ML 188,01
  sobre 188 m; 376,20 y 375,87 sobre 376 m.

## Medicion 4: el empaquetado escala PEOR que lineal

De B a C el largo se duplica y las piezas tambien (x1,97), pero:
- BUILD x2,23
- PACK **x2,61**

Extrapolar con cuidado: un anden de ~800 m (orden del tramo de la captura)
daria del orden de 26.000 piezas. No se midio ese caso.

## Lo que SI quedo demostrado sobre el bloque
En los tres casos: `ES_BLOQUE = T` y `SUELTAS = 0` con barrido completo del
dibujo por XDATA. El empaquetado NO esta roto. Se rompe cuando el tiempo
total se dispara y el usuario interrumpe.

## Cambios entregados en 5.5.0
1. `urb:repair-anden-hatches-si-hace-falta`: sello de version, evita el
   barrido completo en cada apertura.
2. (de 5.4.3) En `urb:package-anden` se DESTRABAN las capas de las piezas
   antes de `-BLOCK` y se restauran despues -- una capa bloqueada o
   congelada impide que el comando meta esos objetos en la definicion.
3. (de 5.4.3) Si el camino nativo falla, se imprime el MOTIVO real
   (CMDACTIVE, el mensaje de `-BLOCK`, o que no quedo la definicion), y si
   funciona se imprime cuanto tardo.

## Pendiente
- Medir `urb:set-block-draw-order` dentro de `urb:package-anden`: es el
  candidato a explicar por que el empaquetado escala peor que lineal.
- No se ha reproducido el caso del usuario en el maestro real con un tramo
  de varios cientos de metros.

## Error propio, registrado
Se intento cronometrar la fase tactil envolviendo
`urb:create-accessibility-features`. La metodologia de Codex advierte
"evitar alias de funciones SUBR para instrumentar" y eso fue exactamente
lo que fallo (`bad function: SUBR`), invalidando esa corrida. Se rehizo
comparando el build con guia/toperol apagados contra encendidos, sin
envolver nada.
