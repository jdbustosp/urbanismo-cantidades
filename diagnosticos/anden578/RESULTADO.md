# Verificación v5.7.8 — continuidad del acabado en curva suave

Agente: Codex. Equipo: BOG085CD119BDQN. Fecha: 2026-09-21.

## Hallazgo en el DWG real

Se trabajó únicamente sobre una copia local de `URB_MASTER_GENERAL.dwg`; el
maestro no se abrió ni se guardó.

El bloque `URB_ANDEN_10110E_8401359`, handle `104A88`, explica la pieza
diagonal mostrada por el usuario:

- Leyendo solamente los vértices, uno de sus lados parece una recta de
  99,596 m seguida por un residuo de 0,032 m a 11,805°. La regla anterior
  interpretaba ese residuo como un segundo tramo.
- Al reconstruir los bulges del contorno se comprueba que el andén completo
  es una curva gradual: 100,339 m, giro acumulado de 23,508° y desviación de
  cuerda de 5,161 m. Por eso no se puede imponer un solo eje a toda la pieza:
  al final volvería a quedar torcida.
- La cuña visible no provenía del arco en sí. Cada zona se recorta con un
  inglete que sobresale unos centímetros antes/después de la cuerda, pero la
  secuencia gris/blanco se continuaba desde el inicio de la cuerda. Ese
  desfase pintaba una franja triangular en la unión.

## Corrección

- Un remate aislado solo produce un cambio de eje cuando la longitud que se
  aparta del rumbo dominante supera simultáneamente 0,50 m y 1 % del costado.
  Así, residuos de centímetros no parten un andén realmente recto.
- En curvas reales se conservan los tramos locales, pero la fase del acabado
  ahora se calcula desde el límite real de cada inglete y teniendo en cuenta
  el sentido de recorrido. No se reinicia ni se corre el gris/blanco en la
  transición.
- No se agregaron piezas ni se cambiaron áreas/cantidades; es una corrección
  de orientación y fase sobre las mismas regiones.

## Evidencia

Civil 3D 2023 completo, ActiveX real, copia local del maestro de 42 MB:

- Regla anterior: reproduce el falso corte en el costado de 99,629 m.
- Regla nueva: ignora sus 0,032488 m fuera de eje.
- Curva control real `F9686`: 179,166 m, giro 18,488°, desviación 11,022 m;
  sigue entrando correctamente a modulación por tramos.
- Reconstrucción de `104A88`: acabado generado, empaquetado como una sola
  referencia de bloque y cero piezas sueltas.
- Suite completa: **60 verificaciones correctas, 0 fallos**.

El tiempo del ensayo completo fue variable entre aperturas de Civil 3D; una
corrida terminó en 46,953 s de acabado + 24,329 s de empaquetado. La última,
con varias aperturas consecutivas del DWG de 42 MB, dio 109,609 s + 50,063 s.
No se atribuye esa variación a la corrección: el algoritmo nuevo es O(1) por
tramo y no aumenta el número de entidades. Este ensayo no incluye tierras ni
guardado.

Harness reproducible: `census.lsp` y `verify.lsp`. Resultado local:
`Documents/URBANISMO/work/anden578_20260921/verify578.txt`.

## Uso

Los bloques ya creados no se redibujan solos. Después de reiniciar Civil 3D,
se debe usar `EDITAR` sobre el andén afectado o recrearlo para aplicar 5.7.8.
