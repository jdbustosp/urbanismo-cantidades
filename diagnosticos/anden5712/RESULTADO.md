# v5.7.12 — continuidad tactil, costado 1/2 y fallo de losetas

Agente: Codex. Equipo: BOG085CD119BDQN.
Fecha/hora local: 2026-09-21 23:33 America/Bogota. Base: 8c8a2e8.

## Hallazgos y cambios

- Log del usuario 23:13:29–35: `losetas SIN RESULTADO`, antes de llamar al
  constructor tactil. `No cupo el toperol` era un diagnostico falso.
- Un punto a 30 cm del centro del costado puede estar dentro de un entrante.
  La prueba antigua entonces invertia la normal de TODA la franja. El sentido
  del anillo ahora determina su interior; el signo de OFFSET se contrasta
  con la tangente local. No depende de contenedores ni de una cota lejana.
- Se retira el clic inicial de via de CREAR/EDITAR. `1` elige el resaltado y
  `2` el opuesto, una sola entrada; ancla persistida. En curvas, el resaltado
  no pasa por el limpiador de entrantes que puede eliminar una curva suave.
- REGION de losetas nueva, sin plano interno/XDATA heredados, conserva bulges.
  Bandas sin area util se distinguen de errores. La cobertura de anillos se
  utiliza SOLO para probar vacio, nunca para rellenar huecos; el respaldo de
  dibujo usa triangulos del contorno neto solo cuando hay un unico anillo.
- Si falla el material se informa esa fase. Si falla el tactil, el mensaje
  ya no asegura que sea por falta de espacio sin haberlo demostrado.

## Evidencia Civil 3D 2023 real

Instancias propias ocultas, fixture LOCAL; maestro intacto. Sin adaptador COM.
Motor SHA256: `DF3AC738774656EB641A30F76B785833752478ED94CBD7B784EA7DE2C05FF489`.

| Caso | Comprobacion |
|---|---|
| Entrante centrado, recorrido CCW y CW | Guia/toperol 52 de 52 estaciones cada 0,5 m por caso; se excluye solo hueco intencional |
| Cuarto de circulo radio interior 30 m, discretizado a 1 grado | Interior 91/91, exterior 103/103, invertido 91/91 estaciones para ambas franjas |
| Cuatro vertices del fallo guardado, aproximadamente 64 m | Material + textura toperol, un INSERT, cero piezas sueltas; 16.156 ms construccion y empaquetado |
| Entrada real getkword por SCR | Un `2` devuelve el costado opuesto; un `1` conserva ese costado, sin repregunta |

Lote geometrico: 17 PASS, sin fallos en las verificaciones ejecutadas.
Lote final reducido: 7 PASS, 0 FAIL, FINISHED. Version se comprueba en ambos.
Resultados en result-curves.txt y result-saved.txt.

## Intentos y limites, sin ocultar fallos

Primera tentativa conservada en result-first.txt: el harness aplicaba por
error el limpiador de entrantes a la curva sintetica y elegia una tapa. Se
corrigio el harness, sin relajar el requisito de cobertura 100%. Tambien
reprodujo un fallo REAL del motor al tratar bandas vacias de una region con
varios anillos como fallo del acabado. Se corrigio esa comprobacion.
El segundo lote paso todos los casos tactiles pero alcanzo 90 s incluyendo
arranque antes de terminar el caso guardado. Se cerro solo su PID. El tercer
lote ejecuto exclusivamente caso guardado y teclado, y termino normalmente.
No se repitio el mismo intento sin cambios. Las demoras de arranque y la
lectura de muchos objetos para comprobar cobertura no son tiempos de crear
un anden; solo el caso guardado mide build+package.

El fixture es anterior a dos recortes nuevos del maestro: se reconstruyeron
sus cuatro vertices, NO toda la escena exacta actual. Las curvas prueban el
constructor tactil; no una generacion completa con tierras. No se validaron
visualmente las transiciones del DWG del usuario ni Civil 2026. La prueba de
teclado no equivale a observar visualmente el resaltado. No se modificaron
formulas de tierras, capas de destino ni cantidades contractuales.

Instalado v5.7.12 en este equipo. Reiniciar Civil y comprobar la version;
los bloques existentes requieren EDITAR para regenerar el acabado corregido.
