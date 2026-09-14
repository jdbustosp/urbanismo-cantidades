# Andenes 5.5.2 — guia en bloque interno, sin simplificar la geometria

Agente: Codex. Equipo: BOG085CD119BDQN.
Fecha/hora: 2026-09-14 03:41 America/Bogota. Base Git: de02ad6 (5.5.1).

## Cambio y causa

La guia del caso de 188 m tenia 4.702 lineas/capsulas. Cada una pasaba
por busquedas XDATA, seleccion, empaquetado y orden de dibujo individual.
Ahora se emiten los mismos DXF directamente en una definicion interna por
franja; una referencia etiquetada se incluye en el bloque final del anden.
No son bloques sueltos por tableta: el usuario selecciona UN bloque exterior.
Las capas, colores, vertices, arcos de capsulas, orientacion y recortes se
conservan. No se reemplazaron las barras por un hatch ni se redujo su cantidad.

El toperol conserva su patron optimizado y su ruta de respaldo anterior.
Las cantidades GUIA_UND/TOPEROL_UND se derivan del area de acabado, no del
numero de capsulas: ver package-anden y measured-finish. Se comprobaron
iguales las 16 cantidades/parametros numericos exportados por los casos A/B.
El cierre ENDBLK queda protegido ante excepcion durante la emision y se
rechaza una definicion incompleta en lugar de declarar terminado el anden.

## Pruebas realizadas

Civil 3D 2023 Metric completo, ActiveX real, instancia propia oculta, sin
tomar el mouse. Dibujo vacio local; curva S de dos arcos, ancho 3,5 m,
coordenadas grandes 82800/102400, guia y toperol activos, formato20x20.
No se abrio ni modifico el maestro ni ningun Excel vigente.

| Caso | Generar | Empaquetar | Regenerar | Total | Objetos a empaquetar |
|---|---:|---:|---:|---:|---:|
| 5.5.1, 188 m | 8,203 s | 9,687 s | 0,078 s | 17,968 s | 5973 |
| 5.5.2, 188 m | 5,969 s | 4,875 s | 0,078 s | 10,922 s | 1274 |
| 5.5.2, 376 m | 10,609 s | 10,282 s | 0,187 s | 21,078 s | 2722 |

188 m: **39,2% menos tiempo total**, 49,7% menos tiempo de empaquetado,
78,7% menos objetos de primer nivel. No se elimina la geometria interna.
Otra corrida registro 15,954s -> 10,844s: los tiempos varian entre corridas.
No comparar estos segundos con los cinco minutos reportados por el usuario
como si fueran mediciones A/B del maestro: ese escenario no se reprodujo.

Resultado final `result.txt`: **31 OK / 0 fallos**.

- Una referencia de bloque final y cero generadas sueltas por barrido
  completo de XDATA (sin limitarse al marcador de inicio).
- Las 4702 geometrías GUIA coinciden entre5.5.1 y5.5.2, comparacion numerica
  de coordenadas/bulges/colores/capas a1e-9; el empaquetado no pierde ninguna.
- Cantidades y sobreancho identicos, incluyendo area neta658,35m2 y
  area con sobreancho1035,605245m2 en188m.
- Guia mediante ruta segmentada de respaldo sobre region interrumpida por
  un hueco transversal: geometria identica a la version anterior.
- Caso376m: bloque valido, cero sueltas, 9406 geometrías GUIA conservadas.

### Error de verificacion corregido, no ocultado

`round1.txt` conserva un FAIL del comparador inicial: ordenar por
vl-princ-to-string redondeaba coordenadas grandes y confundia barras vecinas.
Se corrigio el harness con orden lexicografico NUMERICO, sin aumentar la
tolerancia. La segunda corrida completa, con el motor final, paso31checks.
El tiempo de esos asserts y la carga de Civil se excluyen del tiempo de
generacion; si se incluyo empaquetado y REGEN. No se midieron clics/DCL.

## Repeticion

Laboratorio: C:/Users/juanbusper/Documents/URBANISMO/work/anden552/.
Conservar baseline.lsp de de02ad6 y candidate.lsp del motor entregado;
copiar un DWG VACIO local como fixture.dwg. native.lsp verifica esa ruta
antes de crear nada. Copiar native.lsp y run.scr desde esta carpeta al lab;
lanzar Civil2023 Metric con /b run.scr y el fixture local (ver metodologia).
El script guarda SOLO el fixture. result.txt se agrega: mover el resultado
previo antes de repetir para no mezclar corridas.

## Instalacion y limites

Instalado5.5.2 en este equipo, instalador sin advertencias, manifiesto valido.
SHA256 fuente = candidate probado = bundle instalado:
`10D27FCF85A2675C29727471DC77F13364913783C0CE8EB97755E668A6AE3A80`.
El cargador conserva la ruta compartida de estePC. Reiniciar Civil y crear
un anden nuevo; no se transformaron los andenes existentes del usuario.
PID propios13096 y21536 cerrados; otros procesos no intervenidos.

Pendiente: medir el flujo exacto del usuario sobre su maestro, clics y
apariencia final en su sesion. La igualdad DXF evita una alteracion de forma,
pero no se produjo una captura nueva del render. No se certifican otras
versiones de Civil ni el otro computador con esta prueba. Tampoco es una
validacion universal de todas las curvas ni de movimiento de tierras real.
