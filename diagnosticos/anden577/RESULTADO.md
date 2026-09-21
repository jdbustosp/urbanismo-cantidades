# Verificacion v5.7.7 — fluidez, PURGE y lado tactil

Agente: Codex. Equipo: BOG085CD119BDQN. Fecha: 2026-09-21.

## Hallazgos

- El boton anterior mezclaba `PURGE` con el modo liviano. Al pulsar Enter,
  congelaba por defecto las capas de guia y toperol; no borraba entidades ni
  cantidades, pero visualmente parecia que PURGE las hubiera eliminado.
- La captura de AutoCAD 2026 termina cargando el motor 5.7.6 y el DLL
  `UrbCantRibbon2025.dll`, que es el binario correcto para 2025-2026. Sin
  embargo, antes aparece una carga 5.7.3: esa instalacion no esta limpia y
  ejecuta dos motores durante la misma apertura.
- El lado tactil conservaba solo el punto exterior del clic. Entre ese clic y
  la generacion, el contorno puede recortarse contra bordillos y contenedores;
  ahora se guarda tambien la proyeccion exacta sobre el borde seleccionado.

## Ajustes

- `Depurar dibujo` ejecuta solamente PURGE y no cambia visibilidad.
- `Modo fluido` es una accion separada y explicita para congelar/restaurar las
  cuatro capas tactiles 20x20 y 40x40. Las cantidades siguen en los atributos
  y XDATA del bloque.
- La guia/toperol prioriza un ancla geometrica del borde seleccionado, tanto al
  crear como al editar y despues de recortar el contorno.

## Evidencia

Civil 3D 2023 completo sobre copia local del fixture de 42 MB; el maestro no
se abrio, modifico ni guardo.

- Caso control: sin ancla se reprodujo el costado posterior equivocado; con el
  ancla se conservo el borde seleccionado.
- PURGE dejo visibles las cuatro capas tactiles.
- El modo fluido congelo y luego restauro las cuatro capas.
- Anden real de aproximadamente 188 m: acabado con guia y toperol aceptado,
  empaquetado en una sola referencia de bloque y cero piezas generadas sueltas.
- Tiempo medido, sin tierras ni guardado: acabado 38,985 s; empaquetado
  26,843 s; total 65,828 s. Es mucho menor que los cinco minutos reportados,
  pero no se declara instantaneo.

Harness: `verify.lsp`; prueba focal de consola: `core.lsp`. Resultado local:
`Documents/URBANISMO/work/anden577_20260921/verify577.txt`.

## Limites

Este equipo solo tiene Civil 3D 2023. La compatibilidad 2026 se comprobo por el
manifiesto (`R25.0-R25.1`) y por la captura del usuario, no mediante una corrida
local de AutoCAD 2026. La captura pertenece a otro usuario/ruta (`jdbus`), por
lo que la instalacion 5.7.7 en ese computador requiere sincronizar Drive,
ejecutar `INSTALAR.bat` una vez y reiniciar AutoCAD. Los andenes existentes no
cambian de lado automaticamente: deben editarse o recrearse.
