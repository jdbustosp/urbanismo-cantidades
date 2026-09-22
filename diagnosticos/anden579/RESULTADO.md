# Verificación v5.7.9 — andenes táctiles y tierras de vía

Agente: Codex. Equipo: BOG085CD119BDQN. Fecha: 2026-09-21.

## Resultado

Civil 3D 2023 real, instancia oculta y copia local de laboratorio
`Documents/URBANISMO/work/anden579_20260921/fixture.dwg`. El DWG maestro no
se abrió ni se modificó. Resultado final: **63 PASS, 0 FAIL**.

- El caso real que antes terminaba en `TOPEROL: 0 domos` ahora genera el
  toperol mediante un único hatch de patrón, conserva una guía recta
  (desviación máxima de la cadena: 0,005163 m), se empaqueta como una sola
  referencia de bloque y deja cero piezas generadas sueltas.
- La decisión del costado táctil queda guardada en `URB_ANDEN_SIDE` y
  sobrevive a empaquetado, extracción y edición. Los recortes de contenedores
  interrumpen localmente la franja, pero no cambian su alineación.
- Causa del cero táctil: Civil construía una REGION temporal con estado
  interno no coplanar después de persistir XDATA. La geometría visible estaba
  en Z=0, pero el booleano devolvía `Automation Error. Non coplanar geometry`.
  La región temporal se reconstruye en WCS/Z=0 desde el contorno neto; el
  contorno fuente y sus cantidades no se alteran.
- Tiempo medido del caso guardado de 74,20 m: construcción 18,172 s,
  empaquetado 5,343 s, total 23,515 s. No incluye tierras ni guardado. Es una
  medición del fixture, no una promesa para cualquier andén de 180 m.

## Corte vial absurdo

La vía real de 571,651 m conserva una rasante guardada con solo dos registros:
`2538,65` en estación 0 (fuente `VIA-15`) y `2569,81` en estación final
(fuente `TEXTO`). Contra `SUP_TN`, la diferencia máxima es 25,5915 m y la
media 21,8621 m; eso explica el corte cercano a 95.000 m³ y confirma que no es
un volumen aceptable.

La v5.7.9 ahora:

- proyecta dos o más selecciones con ubicación a sus estaciones reales; dos
  pozos intermedios de prueba permanecieron en 100 y 300 m, en vez de ser
  forzados a los extremos;
- bloquea el cálculo antes de la integración si rasante y `SUP_TN` difieren
  más de 10 m;
- marca el elemento `PENDIENTE: RASANTE INCONSISTENTE CON SUP_TN` y no guarda
  un volumen parcial ni el valor absurdo.

No se inventó una rasante correcta: el usuario debe editar esa vía y volver a
seleccionar los pozos/cotas reales. La versión corregida conservará las
estaciones de cada selección y entonces recalculará el movimiento de tierras.

## Reproducción

```powershell
.\diagnosticos\anden579\check_parens.ps1 -Path .\urbanismo_cantidades.lsp
.\diagnosticos\anden579\run.ps1 -Case verify
```

El harness comprueba además 43 pruebas unitarias heredadas, contorno con
entrantes, bloque único, cero sueltas, edición de zona verde/sendero, huella
exacta de vía y rechazo temprano de la rasante incompatible.

## Límites

- No se guardó el DWG maestro ni se corrigieron sus cotas.
- La validación es geométrica/numérica en Civil 3D 2023; la revisión visual de
  la sesión abierta del usuario requiere recrear o editar el andén con la
  versión cargada.
- No se ejecutó Civil 3D 2026 en esta prueba.
