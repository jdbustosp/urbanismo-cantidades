(vl-load-com)

(defun p474:line (f text)
  (write-line (vl-princ-to-string text) f))

(defun p474:ms (fn args / t0 r)
  (setq t0 (getvar "MILLISECS"))
  (setq r (vl-catch-all-apply fn args))
  (list (- (getvar "MILLISECS") t0) r))

(defun p474:unique (values / out value)
  (foreach value values
    (if (not (member value out)) (setq out (cons value out))))
  (reverse out))

(defun p474:appearance (/ blks blk base item widths heights tag)
  (setq widths nil heights nil blks (vla-get-Blocks (urb:doc)))
  (vlax-for blk blks
    (setq base (mp:infer-base (vla-get-Name blk) nil))
    (if (mp:base-is-tramo base)
      (vlax-for item blk
        (cond
          ((= (vla-get-ObjectName item) "AcDbPolyline")
            (setq widths
              (cons (rtos (vla-get-ConstantWidth item) 2 3) widths)))
          ((= (vla-get-ObjectName item) "AcDbAttributeDefinition")
            (setq tag (strcase (vla-get-TagString item)))
            (if (member tag '("ETIQUETA" "PENDIENTE_VIS"))
              (setq heights (cons (rtos (vla-get-Height item) 2 3) heights))))))))
  (list (p474:unique widths) (p474:unique heights)))

(defun p474:run (/ out f all-ins tramo-ss full filtered picked old-filter
                   refresh appearance head atts)
  (setq out (strcat (getenv "URB_TEST_OUT") "/resultado_master.txt"))
  (setq f (open out "w"))
  (p474:line f (strcat "MOTOR=" *urb-version*))
  (p474:line f (strcat "ANCHO_TRAMO_CONFIG=" (rtos *mp-vis-width* 2 3)))
  (p474:line f (strcat "ALTURA_TEXTO_CONFIG="
    (rtos *mp-vis-tramo-text-height* 2 3)))
  (setq all-ins (ssget "_X" '((0 . "INSERT"))))
  (setq tramo-ss
    (ssget "_X" '((0 . "INSERT")
      (2 . "MP_TRAMO_*,TRAMO_*,CANT_TRAMO_*"))))
  (p474:line f (strcat "INSERTS=" (itoa (if all-ins (sslength all-ins) 0))))
  (p474:line f (strcat "TRAMOS_CANDIDATOS="
    (itoa (if tramo-ss (sslength tramo-ss) 0))))
  (setq full (p474:ms 'urb:q-collect-readonly nil))
  (p474:line f (strcat "CONSULTA_COMPLETA_MS=" (itoa (car full))))
  (setq head (handent "90908"))
  (if head
    (progn
      (setq atts (urb:block-attribute-values head))
      (p474:line f (strcat "HANDLE_90908_DIAMETRO="
        (urb:safe-string (cdr (assoc "DIAMETRO" atts)) "")))
      (p474:line f (strcat "HANDLE_90908_TIPO="
        (urb:safe-string (cdr (assoc "TIPO" atts)) "")))
      (setq old-filter *urb-q-only-ename* *urb-q-only-ename* head)
      (setq filtered (p474:ms 'urb:q-collect-readonly nil))
      (setq *urb-q-only-ename* old-filter)
      (p474:line f (strcat "CONSULTA_90908_MS=" (itoa (car filtered)))))
    (p474:line f "HANDLE_90908=NO_ENCONTRADO"))
  (setq refresh (p474:ms 'urb:q-refresh-network-segments nil))
  (p474:line f (strcat "REFRESH_REDES_MS=" (itoa (car refresh))))
  (if (vl-catch-all-error-p (cadr refresh))
    (p474:line f (strcat "REFRESH_REDES_ERROR="
      (vl-catch-all-error-message (cadr refresh))))
    (p474:line f (strcat "REFRESH_REDES_RESULT="
      (vl-princ-to-string (cadr refresh)))))
  (setq appearance (vl-catch-all-apply 'p474:appearance nil))
  (if (vl-catch-all-error-p appearance)
    (p474:line f (strcat "APARIENCIA_ERROR="
      (vl-catch-all-error-message appearance)))
    (progn
      (p474:line f (strcat "ANCHOS_TRAMO=" (vl-princ-to-string (car appearance))))
      (p474:line f (strcat "ALTURAS_TEXTO_TRAMO="
        (vl-princ-to-string (cadr appearance))))))
  (close f)
  (princ))

(load (getenv "URB_TEST_LSP"))
(p474:run)
(princ)
