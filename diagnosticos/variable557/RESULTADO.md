# Anchos variables — 5.5.7

Agente: Codex. Equipo: BOG085CD119BDQN. Fecha/hora: 2026-09-14 13:42 America/Bogota.
Base: ffe9617. Prueba nativa: Civil 3D 2023, copia local, sin controlar pantalla.

## Causa y cambio

La validacion compartida rechazaba variaciones estimadas >2.5 veces y >1.5 m.
No era una comprobacion de geometria invalida. Se retira ese rechazo al crear
y actualizar andenes, ciclorrutas, senderos y los demas tipos que usan el mismo
validador. Se mantiene el rechazo de cruces y las validaciones de los constructores.
No cambian patrones, formulas, capas, prefabricados ni el formato de almacenamiento.
Senderos/ciclorrutas ya generan un solo hatch por contorno: NET/SOLID respectivamente.
Elegir Ninguno en ambos costados evita generar prefabricados. Su contorno y hatch
siguen agrupados; el anden de losetas sigue empaquetandose en bloque.

## Contorno real del maestro

Origen: `260915_ACTUALIZACION GENERAL PPTO/Memorias/URB_MASTER_GENERAL.dwg`,
copia guardada 2026-09-14 13:34:24, 38,519,152 bytes. El original no se modifico.
Lectura lateral .NET y copia de candidatos a un fixture; no apertura/render del maestro.
Contorno D21E9 en capa 0, 27 vertices, area 519.425238904276 m2,
perimetro 405.798052661529 m; importado F3F. No tiene XDATA de tipo porque fue
rechazado antes del acabado. Es el candidato mas reciente y reproduce el mensaje:
version anterior WIDTH_REJECT=T, OLD_VALID=nil, SELF_CROSS=nil.
No se afirma identificacion visual completa del plano.

## Resultados

46 OK / 0 FAIL. Ver `result.txt`.

| Caso | Constructor | Tiempo | Area m2 |
|---|---|---:|---:|
| Contorno real | Ciclorruta, SOLID | 1.016 s | 519.425238904 |
| Contorno real | Sendero ecologico, NET | 0.156 s | 519.425238904 |
| Ancho 2 a 18 m | Sendero de trote | 0.078 s | 240 |
| Concavo U | Sendero ecologico | 0.062 s | 208 |
| Curvas y ancho variable | Ciclorruta | 0.078 s | 334.771611274 |
| Ancho 2 a 18 m | Anden loseta sin tactiles, build+pack | 0.468 s | 240 |

Cinco casos hatch: uno por contorno, patron/capa correctos, grupo creado, vertices
y bulges intactos y area del hatch igual al contorno a 1e-6 m2. El caso cruzado se
rechaza. Colector real de presupuesto devuelve las areas a su precision habitual
de 0.001 m2 para los cinco casos. No se exporto Excel ni se simulo terreno.
Las entradas interactivas (dibujar/pedir cotas) se sustituyeron por una cola de
contornos y Enter sin terreno; validador y constructor son los del motor real.

## Limites

Sin revision visual nativa del maestro completo ni pruebas Civil 2025/2026.
Estos tiempos miden solo los constructores indicados, sin terreno ni prefabricados;
no prometen tiempos equivalentes para andenes largos con guia y toperol.
El cambio admite anchos variables; no elimina los rechazos por autointerseccion,
fallos ACIS u otras condiciones geometricas invalidas.
Laboratorio y DWG de prueba: `COMPLEMENTO AUTOCAD/work/variable557/fixture.dwg`.

## Entrega

5.5.7 instalada en este equipo, sin avisos de DLL bloqueada. Fuente probada,
fuente del repositorio e instalada coinciden en SHA256:
`4CB9127E05FB1F6E61860447240E62479FE068349920526FE79CA96D171ED6D1`.
Instancia propia 23964 cerrada tras guardar el fixture. Reiniciar Civil 3D
para cargar la version en los documentos de trabajo.
