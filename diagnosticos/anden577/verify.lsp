(vl-load-com)

(setq v577:dir
  "C:/Users/juanbusper/Documents/URBANISMO/work/anden577_20260921")
(setq v577:out (strcat v577:dir "/verify577.txt"))

(defun v577:log (text / stream)
  (setq stream (open v577:out "a"))
  (write-line text stream)
  (close stream))

(defun v577:check (condition label)
  (v577:log (strcat (if condition "PASS " "FAIL ") label))
  (if (not condition) (vl-exit-with-error label)))

(defun v577:flat-y (points value tolerance / ok point)
  (setq ok T)
  (foreach point points
    (if (> (abs (- (cadr point) value)) tolerance) (setq ok nil)))
  ok)

(defun v577:keep-layer (name x / layer line)
  (setq layer (urb:ensure-layer name 2 T))
  (vla-put-Freeze layer :vlax-false)
  (setq line
    (vla-AddLine (urb:model-space)
      (vlax-3d-point (list x 0.0 0.0))
      (vlax-3d-point (list x 0.1 0.0))))
  (vla-put-Layer line name)
  line)

(defun v577:loose (handle / *urb-generation-parent* *urb-generation-start*)
  (length (urb:generated-objects handle)))

(defun v577:run (/ ring click anchor chosen keepers i original target boundary
                    handle points result packed start build-ms pack-ms)
  (v577:log (strcat "VERSION " *urb-version*))
  (v577:check (= *urb-version* "5.7.7") "engine version")
  (v577:check
    (= (strcase (vl-string-translate "\\" "/"
         (strcat (getvar "DWGPREFIX") (getvar "DWGNAME"))))
       (strcase (strcat v577:dir "/fixture.dwg")))
    "correct fixture")

  ;; El clic original esta bajo el anden. Se simula que, despues de un
  ;; recorte, su distancia vuelve a ser ambigua y se conserva el ancla del
  ;; borde superior elegido. La 5.7.6 ignora ANCHOR y escoge el borde inferior;
  ;; la 5.7.7 debe conservar el superior.
  (setq ring '((0.0 0.0) (100.0 0.0) (100.0 4.0)
               (50.0 4.0) (0.0 4.0))
        click '(50.0 -2.0 0.0)
        anchor (urb:tactile-side-anchor ring '(50.0 9.0 0.0)))
  (v577:check (and anchor (< (abs (- (car anchor) 50.0)) 1e-9)
                              (< (abs (- (cadr anchor) 4.0)) 1e-9))
    "click is projected to exact selected boundary")
  (setq *urb-current-tactile-side-choice* nil
        *urb-current-tactile-side-point* click
        *urb-current-tactile-side-anchor* anchor
        chosen (urb:anden-tactile-chain ring))
  (v577:check (and chosen (v577:flat-y chosen 4.0 1e-9))
    "stored boundary anchor wins after later contour changes")

  ;; PURGE ya no debe activar silenciosamente el modo liviano. Se mantienen
  ;; las cuatro capas referenciadas por lineas minimas para que no sean
  ;; purgadas y se comprueba su bandera de congelacion antes/despues.
  (urb:prepare-anden-layers)
  (urb:light-mode-set nil)
  (v577:check (= (urb:light-mode-state) "APAGADO")
    "tactile layers begin visible")
  (urb:purge-command)
  (v577:check (= (urb:light-mode-state) "APAGADO")
    "PURGE keeps guide and toperol visible")
  (urb:light-mode-set T)
  (v577:check (= (urb:light-mode-state) "ACTIVO")
    "explicit fluid mode freezes all tactile layers")
  (urb:light-mode-set nil)
  (v577:check (= (urb:light-mode-state) "APAGADO")
    "fluid mode restores all tactile layers")
  ;; Regresion sobre el mismo anden real de 188 m usado en 5.7.6.
  (foreach original (urb:all-anden-blocks)
    (if (wcmatch (cdr (assoc 2 (entget original))) "URB_ANDEN_13D362_*")
      (setq target original)))
  (v577:check target "real 188 m source sidewalk exists")
  (setq boundary (urb:explode-anden-block-boundary target)
        handle (cdr (assoc 5 (entget boundary)))
        points (urb:lwpoly-points-with-arcs-fine boundary)
        *urb-current-tactile-side-point* '(83038.9 95306.5 0.0)
        *urb-current-tactile-side-anchor*
          (urb:tactile-side-anchor points *urb-current-tactile-side-point*)
        *urb-current-tactile-side-choice* nil)
  (v577:check *urb-current-tactile-side-anchor*
    "real road-side click has a boundary anchor")
  (urb:set-anden-data boundary "Loseta" "4" "4B" "Si" "Si"
    "20 x 20 cm" "No" "SUP_TN" "Via creada")
  (setq start (getvar "MILLISECS")
        result (urb:build-anden-finish boundary "Loseta" "Si" "Si" "20 x 20 cm")
        build-ms (- (getvar "MILLISECS") start))
  (v577:check result "real finish builds with guide and toperol")
  (setq start (getvar "MILLISECS")
        packed (urb:package-anden boundary)
        pack-ms (- (getvar "MILLISECS") start))
  (v577:check packed "real sidewalk packages")
  (v577:check (= (vla-get-ObjectName packed) "AcDbBlockReference")
    "real result is one block reference")
  (v577:check (= (v577:loose handle) 0)
    "real sidewalk leaves zero loose generated pieces")
  (v577:log (strcat "TIMES build=" (itoa build-ms)
                    " pack=" (itoa pack-ms)
                    " total=" (itoa (+ build-ms pack-ms))))
  (v577:log "FINISHED (fixture only; no terrain and no save)"))

(if (findfile v577:out) (vl-file-delete v577:out))
(setq v577:result (vl-catch-all-apply 'v577:run nil))
(if (vl-catch-all-error-p v577:result)
  (v577:log (strcat "FAILED " (vl-catch-all-error-message v577:result))))
(princ)
