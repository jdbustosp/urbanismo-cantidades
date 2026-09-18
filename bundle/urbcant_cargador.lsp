;;; Cargador del bundle UrbanismoCantidades (5.7.2).
;;; Antes el bundle cargaba el motor COMPLETO aunque el acaddoc.lsp ya lo
;;; hubiera cargado desde el repo: el motor corria DOS veces por apertura
;;; (medido en el maestro: ~35 s) y, si la copia del bundle era mas vieja,
;;; pisaba las funciones nuevas del repo. Ahora el bundle solo carga el
;;; motor si todavia no esta en este documento, y prefiere el mismo camino
;;; del acaddoc (repo en Drive con respaldo local).
(vl-load-com)
(if (not (member "C:URBANISMO" (atoms-family 1)))
  (if (and (boundp 'urbcant:bootstrap) urbcant:bootstrap)
    (urbcant:bootstrap)
    (load (strcat (getenv "APPDATA")
                  "\\Autodesk\\ApplicationPlugins\\UrbanismoCantidades.bundle\\Contents\\urbanismo_cantidades.lsp"))))
(princ)
