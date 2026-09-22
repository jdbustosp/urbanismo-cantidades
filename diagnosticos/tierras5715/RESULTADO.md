# v5.7.15 — tierras automaticas y editables

Agente: Codex. Equipo: BOG085CD119BDQN.
Fecha/hora local: 2026-09-22 06:27 America/Bogota. Base: 150ff33 (5.7.14).

## Implementado

- Un selector compartido en creacion/edicion: Automatico predeterminado,
  Referencia con un clic a VIA/ANDEN completo, Cotas manuales y Sin (creacion)
  o Conservar (edicion). No convierte el perfil seleccionado en un punto plano.
- Auto reutiliza la deteccion geometricamente acotada de vias con rasante;
  si no encuentra via, busca anden cercano con referencia recuperable. Informa
  nombre/handle. Si no encuentra datos validos, permite un clic de referencia;
  no inventa cotas. Una via tiene prioridad sobre el respaldo por anden.
- EDITAR zona verde: Datos/Tierras/Ambos. Tierras evita abrir el dialogo de
  datos. El espesor modifica la subrasante: invalida cifras anteriores por
  cada zona; un fallo de recalculo elimina MT anterior, no publica un parcial.
- Sendero movido/girado: copia de contorno en coordenadas del INSERT real,
  no en las coordenadas viejas de su definicion. Original conservado.
- Una sola funcion calcula senderos nuevos y editados. Sobreancho lateral
  conserva la referencia del borde original para la pendiente transversal.
- mov2 se reinicia en cada sendero: elegir Sin no hereda MT del anterior.

No cambian las recetas/exportaciones de 5.7.13/5.7.14, capas de acabado ni
el algoritmo de cuadratura. Las referencias de andenes reutilizan el modelo
existente basado en una via recuperable; no reconstruyen cotas manuales que
un anden antiguo no haya conservado. No hay reactor de actualizacion en vivo
cuando se modifica otra via: se recalcula al crear o usar EDITAR.

## Verificado y limite

Core Console 2023: **10 PASS, 0 FAIL**, FINISHED, motor 5.7.15 cargado.
Evidencia: core-result.txt. Interpolacion de cota intermedia, perfil por
estaciones, area ponderada 40 m2, signos corte/relleno y entrada real de las
opciones Sin/Conservar. Sin adaptador de las funciones probadas.
Balance de parentesis cero y git diff --check sin errores.

Civil completo NO produjo resultados del harness dentro del limite de 90 s.
La primera apertura de copia de 45 MB quedo en regeneracion/aviso de inicio;
la segunda uso fixture ligero y TIN sintetico, pero tampoco llego a escribir
progreso. Se cerraron solo PID propios. No se continuaron reintentos de Civil.
Esto es limite de infraestructura, no aprobacion de deteccion COM, contorno
transformado, volumenes contra TIN ni interfaz completa.

verify.lsp y run.scr son las pruebas preparadas, NO evidencia de exito.
TestSurface.cs compila un generador de TIN nativo de laboratorio (plano
2600 m), para poder contrastar volumenes analiticos. No se instala en el
producto. API consultada en [documentacion oficial de Autodesk](https://help.autodesk.com/cloudhelp/2022/ENU/Civil3D-DevGuide/files/GUID-1985347E-FC83-479B-B25C-4B381CB1548B.htm).
compile.ps1 genera DLL temporal en la raiz confiable; no cambia SECURELOAD.

## Comprobacion manual pendiente (tres pasos)

1. Reiniciar Civil, confirmar 5.7.15. En una copia, crear una zona/sendero
   junto a una via con rasante; Enter en Automatico. Debe indicar la referencia
   detectada y calcular sin cotas punto por punto.
2. EDITAR zona verde -> Tierras -> Referencia; seleccionar otra via/anden con
   un clic. Verificar CORTE_M3/RELLENO_M3 contra la rasante y SUP_TN. En sendero,
   EDITAR lleva directamente al selector de referencia.
3. Cambiar espesor y recalcular; mover/girar un sendero y EDITAR. Confirmar
   que consulta TN en su nueva posicion y no conserva resultados anteriores
   si faltan superficie o referencia. Cotas permanece como alternativa manual.

Originales DWG/Excel no modificados. Instalacion requiere reiniciar la sesion.
