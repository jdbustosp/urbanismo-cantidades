# v5.7.11 — bordillo curvo y confirmacion del costado tactil

Agente: Codex. Equipo: BOG085CD119BDQN. Fecha/hora local: 2026-09-21 22:26 America/Bogota.

Pedido focal: bloqueo al construir bordillo de 565,72 m y toperol en costado contrario.

Hallazgo confirmado en codigo y ensayo: el flujo interactivo remuestreaba TODOS
los costados cada 0,25 m y luego descartaba los bulges. Un arco de 565,486678 m
pasaba de dos vertices a mas de 2200. Ahora `chain-slice-exact` conserva vertices
y arcos, incluso al cortar por estaciones. `prefab-split-exact` intersecta los
contenedores y conserva arcos en cada porcion util. Un fallo del recorte se
registra y no permite construir por encima del contenedor como respaldo.

Crear y EDITAR andenes resaltan la cadena real del toperol: 1 acepta, 2 cambia
al otro costado y vuelve a mostrarlo para confirmar. Se guarda un ancla en el
punto medio del costado confirmado para evitar ambiguedad junto a los remates.

Civil 3D 2023 real, copia local `Documents/URBANISMO/work/anden5711/fixture.dwg`:
**13 PASS, 0 FAIL**, una sola apertura con limite de 90 s. Bordillo curvo de
565,486678 m: **1797 ms**, bloque creado y longitud igual al arco dentro de 1e-6 m.
Subarco de 100 a 300 m conserva 200 m dentro de 1e-7 m; contenedor transversal
lo divide en dos arcos; ambos puntos medios utiles quedan fuera del contenedor.
Anclas opuestas eligen cadenas opuestas y el ancla persiste en XDATA.

Limites: no se reprodujo el cierre del proceso en el contorno original del
usuario; la densificacion es un problema comprobado, no una prueba causal del
crash. No se midio el anden completo ni tierras. La previsualizacion y el flujo
de teclado 1/2 requieren comprobacion interactiva, no los cubren los asserts.
El maestro no se modifico. Sintaxis completa y diff sin errores.

Uso: reiniciar Civil para cargar 5.7.11; crear/editar anden; comprobar el costado
resaltado, pulsar 2 si corresponde cambiarlo y confirmar con 1 o Enter.
