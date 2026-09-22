# v5.7.17 — atasco al crear malla de tierras del anden

Agente: Codex. Equipo: BOG085CD119BDQN. 2026-09-22 08:36 America/Bogota.
Base5812e57; commit final el que incorpora este informe.

## Caso y diagnostico

Maestro guardado08:21:50, copiado fuera de Drive a
`C:/Users/juanbusper/Documents/URBANISMO/work/anden5717/fixture.dwg`.
Anden1B3D3F (area de acabados425.56m2, contorno bruto454.84m2),
huella con sobreancho4392puntos. Rasante real VIA-17 recuperada sin error.
Probe con motor5.7.16 llego a BEFORE SAMPLES, no termino antes del presupuesto
90s del proceso completo; solo se cerro PID10540. El timeout NO mide90s de
muestreo puro. No se reprodujo literalmente Unknown exception/unwind skipped.
La prueba aislada APPLY con100000numeros paso; no se confirma como causa.

## Cambio

El muestreador barria TODAS las aristas en CADA nivel de vertices. Ahora
ordena eventos de inicio/fin y solo consulta las aristas activas. Conserva
los niveles, microarcos densificados, area exacta de cada trapecio y centroides.
No simplifica contorno, no cambia cotas ni profundidades. Mas de250000muestras
devuelve nil y aviso, nunca un volumen parcial. Suma iterativa de pesos y
registros antes/despues de malla/antes de consultaTN facilitan diagnosticos.

## Pruebas

- Core baseline: APPLY1000/10000/40000/100000 completado, sin fallo.
- Core final32.22s total:29PASS/0FAIL/FINISHED. Ocho casos (rectangular,
  concavo, remate fino, coordenadas grandes; CW y CCW): mismo numero de muestras,
  area y momentos de primer orden que algoritmo anterior. Areas contrastadas
  con formula independiente del poligono.
- DXF de huella real en copia, precision original (NO points.lsp redondeado):
  4392vertices ->51224muestras en2000ms. Area ponderada741.34583816m2;
  poligono741.34582853m2, diferencia0.00000963m2.
- Civil2023 final: nuevo harness para calculo COMPLETO, no repeticion del
  probe anterior. Proceso76.564s incluida apertura; calculo30.766s.
  RESULT T, guardado de resultados, cobertura51224/51224=100%.
  Corte476.073314m3, relleno440.494217m3; SUP_TN y VIA-17 reales.
  Estructura0.60m, sobreexcavacion0.50m; coeficientes configurados conservados.
  No certificado independiente del volumen ni ensayo Civil2026.
- Toperol:2HATCH dentro del bloque real. Aviso 'sin relleno/tono' pertenece
  a primer metodo; respaldo posterior deja hatches. NO afirmar ausencia de
  toperol por ese aviso, ni continuidad visual solo por contar hatches.
- Sintaxis balance0, diff --check limpio, manifiesto5.7.17 valido.
- Fuente=instalado SHA256
  `571A13213A63622F37A33E15573385DBB6825C7736F3FF8D19AD37615D9D5E9A`.
  Instalador avisa DLL en uso; DLL2025 sin cambios y hashes iguales
  `E6720351CBA4062BA83438ED7B43E601F9781168EDD487475A72911ADC0F5E08`.

Maestro/Excel intactos. Ningun resultado se guardo en el maestro ni fixture.
No cerrar la excepcion nativa como causalidad exclusiva demostrada; si vuelve
a ocurrir, el log de fases ya distingue malla vs TN/rasante. No hubo cambio
de dibujo de guia/toperol; continuidad visual pendiente.

Reiniciar Civil para cargar5.7.17 y usar EDITAR para recalcular el bloque
existente. No se recalcula automaticamente el maestro al cargar.
