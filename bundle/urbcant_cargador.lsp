;;; Cargador del bundle UrbanismoCantidades (5.7.29, urbcant-cargador-v2).
;;; El bundle carga ANTES que el acaddoc.lsp. En 5.7.2 este cargador, al no
;;; encontrar todavia el arranque del acaddoc, cargaba la copia local del
;;; bundle y despues el acaddoc cargaba la del repo: el motor corria DOS
;;; veces por apertura y primero una version vieja (visto 2026-09-24:
;;; 5.7.27 del bundle y luego 5.7.28 del repo). Ahora no carga nada al
;;; entrar: lo hace el acaddoc (repo en Drive con respaldo local). Solo si
;;; al final del arranque todavia no hay motor, carga la copia local.
;;; El motor reescribe este archivo instalado si no trae esta marca.
(vl-load-com)
(defun urbcant:respaldo-bundle ()
  (if (not (member "C:URBANISMO" (atoms-family 1)))
    (if (and (boundp 'urbcant:bootstrap) urbcant:bootstrap)
      (urbcant:bootstrap)
      (load (strcat (getenv "APPDATA")
        "/Autodesk/ApplicationPlugins/UrbanismoCantidades.bundle/Contents/urbanismo_cantidades.lsp"))))
  (princ))
(if (not (member "C:URBANISMO" (atoms-family 1)))
  (if (and (boundp 'urbcant:bootstrap) urbcant:bootstrap)
    (urbcant:bootstrap)
    (cond
      ((= (type s::startup) 'LIST)
        (setq s::startup (append s::startup '((urbcant:respaldo-bundle)))))
      ((null s::startup)
        (defun-q s::startup () (urbcant:respaldo-bundle)))
      (T
        (setq urbcant:startup-previo-bundle s::startup)
        (defun s::startup ()
          (vl-catch-all-apply urbcant:startup-previo-bundle nil)
          (urbcant:respaldo-bundle))))))
(princ)
