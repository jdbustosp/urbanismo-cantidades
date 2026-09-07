# Regresion v4.73.0

El motor sigue completo en `urbanismo_cantidades.lsp`. Esta carpeta contiene
solo pruebas y evidencia; no es una dependencia del plugin.

Ejecutar en PowerShell con rutas de la instalacion de ese computador:

```powershell
.\diagnosticos\hardening4730\ejecutar.ps1 -CoreConsole 'ruta\accoreconsole.exe' -Template 'ruta\plantilla.dwt'
```

El runner crea una copia local de la plantilla, recupera el motor 4.72.2 del
commit `0ffec47`, copia el motor actual y ejecuta la suite. Los archivos van a
`%USERPROFILE%/Documents/URBANISMO/work/hardening4730`; esa carpeta debe estar
entre las ubicaciones de confianza de AutoCAD. No se guarda ningun DWG de
trabajo. No ejecutar verify.lsp dentro de una sesion de trabajo: redefine
funciones ActiveX y DCL mediante adaptadores EXCLUSIVOS del proceso de prueba.

Resultado verificado: 50 OK, 0 fallos. Incluye dos reproducciones contra la
version anterior, preservacion XDATA real, rollback con fallo inyectado,
idempotencia, cantidades negativas, formulas de cama y volumen, autopruebas
integradas y recorrido del controlador de dialogo con y sin observaciones.

Limites: los adaptadores ActiveX/DCL no prueban COM real, aspecto visual,
clics, terreno Civil 3D real ni exportacion completa a Excel. El diagnostico
no certifica la correspondencia con el presupuesto ni detecta todas las
modificaciones geometricas externas. La consulta de cantidades no recalcula;
abrir URBANISMO conserva las migraciones automaticas historicas existentes.

Validacion manual pendiente en una copia del proyecto:

1. Reiniciar Civil 3D y comprobar Configuracion > Version instalada y sesion:
   motor 4.73.0 en ambos casos y 14/14 autopruebas.
2. Cantidades > Diagnostico de integridad: abrir, ver detalle, seleccionar
   un objeto y cerrar; probar tambien un dibujo sin observaciones.
3. Consultar cantidades de un bloque y contrastarlas con su memoria.
4. Cambiar etapa/subetapa por lote: Cancelar no modifica; Aplicar cambia el
   lote; UNDO deshace el lote completo.
5. Probar una exportacion en una copia del Excel y comparar cantidades y
   campos ocultos antes/despues. No usar el libro vigente como fixture.

DLL 2019–2024: sigue pendiente recompilarla con referencias AutoCAD/AEC 2023
para eliminar el boton Sendero heredado. No se afirma validada esa interfaz.

Revalidacion: ver REVALIDACION_20260907.md. verify_real.lsp es experimental y no ha sido validado con ActiveX nativo.
