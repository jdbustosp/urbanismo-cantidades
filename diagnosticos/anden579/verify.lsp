(vl-load-com)
(setq v579:dir "C:/Users/juanbusper/Documents/URBANISMO/work/anden579_20260921"
      v579:out (strcat v579:dir "/verify579.txt")
      v579:ok 0 v579:fail 0)

(defun v579:log (s / f) (setq f (open v579:out "a")) (write-line s f) (close f))
(defun v579:check (c s)
  (if c (progn (setq v579:ok (1+ v579:ok)) (v579:log (strcat "PASS " s)))
        (progn (setq v579:fail (1+ v579:fail)) (v579:log (strcat "FAIL " s)))))

(defun v579:make-poly (pts layer / data p)
  (setq data (list '(0 . "LWPOLYLINE") '(100 . "AcDbEntity")
          '(100 . "AcDbPolyline") (cons 90 (length pts)) '(70 . 1)
          (cons 8 layer)))
  (foreach p pts (setq data (append data (list (cons 10 p) '(42 . 0.0)))))
  (entmakex data))

(defun v579:make-notch ()
  (v579:make-poly
    '((0.0 0.0) (45.0 0.0) (45.0 1.0) (47.0 1.0)
      (47.0 0.0) (100.0 0.0) (100.0 4.0) (0.0 4.0))
    "URB-ANDEN"))

(defun v579:latest-toperol-case (/ path file line row pts side)
  (setq path (strcat (getenv "TEMP") "/urbcant_toperol_fallo.txt"))
  (if (setq file (open path "r"))
    (progn
      (while (setq line (read-line file))
        (cond
          ((wcmatch line "===*") (setq pts nil side nil))
          ((wcmatch line "V *")
            (setq row (read (strcat "(" line ")"))
                  pts (cons (cdr row) pts)))
          ((wcmatch line "LADO_VIA *")
            (setq row (read (strcat "(" line ")"))
                  side (cadr row)))))
      (close file)
      (list (reverse pts) side))))

(defun v579:chain-max-deviation (chain / a b p maximum)
  (setq a (car chain) b (last chain) maximum 0.0)
  (foreach p chain
    (setq maximum (max maximum (urb:dist-point-seg p a b))))
  maximum)

(defun v579:road-check (/ road data axis boundary surface local raw footprint result
                         direction axis-start span depth p1 p2 projected sources)
  (setq road (handent "169202") data (urb:get-xdata-strings road "URB_VIA")
        axis (urb:road-axis-recover road data (urb:safe-string (nth 22 data) ""))
        boundary (urb:explode-road-block-boundary road)
        surface (urb:select-surface-object (nth 6 data))
        local (urb:road-design-grade-records road data)
        direction (urb:safe-string (nth 12 data) "Inicio")
        axis-start (atof (nth 21 data)) span (atof (nth 18 data))
        depth (urb:road-profile-depth (nth 4 data)))
  (v579:check (and road data axis boundary surface local) "real pending road inputs")
  (setq sources (urb:road-ldata-stored road "URB_VIA_RASANTE_SRC"))
  (v579:log (strcat "ROAD STORED_GRADE=" (vl-princ-to-string local)
    " SOURCES=" (vl-princ-to-string sources)))
  (if (and axis boundary surface local)
    (progn
      (setq raw (mapcar '(lambda (r) (list
        (if (urb:string-equal-p direction "Final")
          (- (+ axis-start span) (car r)) (+ axis-start (car r))) (cadr r))) local)
        footprint (urb:road-earthwork-footprint boundary axis
          (atof (nth 14 data)) (atof (nth 15 data)) direction))
      (v579:check footprint "571.65m road exact footprint")
      (if footprint (entdel footprint))
      ;; Dos pozos intermedios conservan sus estaciones reales; ya no se
      ;; convierten silenciosamente en los extremos de la via.
      (setq p1 (urb:curve-pt axis (+ axis-start 100.0))
            p2 (urb:curve-pt axis (+ axis-start 300.0))
            projected (urb:picked-cotas-to-stations
              (list (list 2564.0 p1 "POZO" "P1")
                    (list 2571.0 p2 "POZO" "P2")) axis))
      (v579:check (and (= (length projected) 2)
                       (equal (caar projected) (+ axis-start 100.0) 0.01)
                       (equal (caadr projected) (+ axis-start 300.0) 0.01))
        "two intermediate wells keep projected stations")
      ;; Esta rasante guardada es la que producia 95 mil m3. El calculador
      ;; debe rechazarla ANTES de la integracion y no devolver cantidades.
      (setq result (urb:compute-road-earthworks boundary data axis))
      (v579:check (and (null result) *urb-last-road-grade-diagnostic*
                       (not (car *urb-last-road-grade-diagnostic*))
                       (> (nth 1 *urb-last-road-grade-diagnostic*) 10.0))
        "absurd 19-25m road grade rejected before volume integration")
      (v579:log (strcat "ROAD GRADE_GUARD="
        (vl-princ-to-string *urb-last-road-grade-diagnostic*)))))
  (if boundary (entdel boundary)))

(defun v579:run (/ tests item block side boundary notch pts cleaned chain data
                   parent finish packed green gdata gb send sb real-case real-points
                   real-boundary real-parent real-finish real-packed real-top
                   build-start build-end pack-end)
  (v579:log (strcat "VERSION " *urb-version*))
  (v579:check (= *urb-version* "5.7.9") "engine version")
  (setq tests (urb:quality-selftests))
  (foreach item tests (v579:check (cadr item) (strcat "selftest " (car item))))

  ;; El ancla debe sobrevivir al bloque y al contorno extraido.
  (setq block (handent "104A88") side '(82899.30 95464.10))
  (urb:set-tactile-side-data block side)
  (v579:check (equal side (urb:tactile-side-data block) 1e-6)
    "tactile side stored on block")
  (setq boundary (urb:explode-anden-block-boundary block))
  (v579:check (and boundary (equal side (urb:tactile-side-data boundary) 1e-6))
    "tactile side survives boundary extraction")
  (if boundary (entdel boundary))

  ;; Entrante rectangular: la cadena tactil debe seguir recta y el hueco
  ;; solo recorta el material, no cambia el rumbo.
  (setq notch (v579:make-notch)
        pts (urb:lwpoly-points-with-arcs-fine notch)
        cleaned (urb:ring-remove-notches pts)
        *urb-current-tactile-side-point* '(46.0 -1.0)
        *urb-current-tactile-side-anchor* (urb:tactile-side-anchor pts '(46.0 -1.0))
        chain (urb:anden-tactile-chain cleaned))
  (v579:check (< (length cleaned) (length pts)) "rectilinear cutout notch removed from guide axis")
  (v579:check (and chain (> (urb:chain-total-length chain) 99.0))
    "guide chain remains continuous across cutout")

  ;; Caso real guardado automaticamente por el fallo del usuario: una franja
  ;; recta con numerosos entrantes de contenedores a ambos costados.
  (setq real-case (v579:latest-toperol-case)
        real-points (car real-case)
        *urb-current-tactile-side-anchor*
          (if (cadr real-case) (cadr real-case) '(83079.4 95132.6 0.0))
        cleaned (if real-points (urb:ring-remove-notches real-points))
        chain (if cleaned (urb:anden-tactile-chain cleaned)))
  (v579:check (and real-points (> (length real-points) 20))
    "saved real zero-toperol case loaded")
  (v579:check (and cleaned (< (length cleaned) (length real-points)))
    "saved real container notches removed from guide axis")
  (if chain
    (v579:log (strcat "REAL_GUIDE raw=" (itoa (length real-points))
      " cleaned=" (itoa (length cleaned)) " chain=" (itoa (length chain))
      " length=" (rtos (urb:chain-total-length chain) 2 4)
      " deviation=" (rtos (v579:chain-max-deviation chain) 2 6)
      " points=" (vl-princ-to-string chain))))
  (v579:check (and chain (< (v579:chain-max-deviation chain) 0.05))
    "saved real straight guide stays straight")

  ;; Reconstruir el contorno del fallo y ejecutar el constructor real: debe
  ;; sembrar toperol y terminar como una unica referencia de bloque.
  (setq real-boundary (v579:make-poly real-points "URB-ANDEN")
        *urb-current-tactile-side-point* *urb-current-tactile-side-anchor*
        *urb-current-tactile-side-anchor* (cadr real-case))
  (if (null *urb-current-tactile-side-anchor*)
    (setq *urb-current-tactile-side-anchor* '(83079.4 95132.6 0.0)
          *urb-current-tactile-side-point* *urb-current-tactile-side-anchor*))
  (urb:set-anden-data real-boundary "Loseta" "1" "1" "Si" "Si"
    "20 x 20 cm" "No" "SUP_TN" "Cotas seleccionadas")
  (urb:set-tactile-side-data real-boundary *urb-current-tactile-side-anchor*)
  (setq real-parent (cdr (assoc 5 (entget real-boundary)))
        build-start (getvar "MILLISECS")
        real-finish (urb:build-anden-finish real-boundary "Loseta" "Si" "Si" "20 x 20 cm")
        build-end (getvar "MILLISECS")
        real-top (urb:count-toperol-symbols (urb:generated-objects real-parent)))
  (v579:check (and real-finish (> real-top 0))
    "saved real case generates toperol")
  (if real-finish (setq real-packed (urb:package-anden real-boundary)))
  (setq pack-end (getvar "MILLISECS"))
  (v579:log (strcat "REAL_ANDEN build_ms=" (itoa (- build-end build-start))
    " package_ms=" (itoa (- pack-end build-end))
    " total_ms=" (itoa (- pack-end build-start))
    " toperol_symbols=" (itoa real-top)))
  (v579:check (and real-packed (= (vla-get-ObjectName real-packed) "AcDbBlockReference"))
    "saved real case packages as one block")
  (v579:check (= (length (urb:generated-objects real-parent)) 0)
    "saved real case leaves no loose finish entities")

  ;; Restaurar el caso sintetico que se empaqueta a continuacion.
  (setq pts (urb:lwpoly-points-with-arcs-fine notch)
        *urb-current-tactile-side-point* '(46.0 -1.0)
        *urb-current-tactile-side-anchor* (urb:tactile-side-anchor pts '(46.0 -1.0)))
  (urb:set-anden-data notch "Loseta" "1" "1" "Si" "Si" "20 x 20 cm" "No" "SUP_TN" "Cotas seleccionadas")
  (urb:set-tactile-side-data notch *urb-current-tactile-side-anchor*)
  (setq parent (cdr (assoc 5 (entget notch)))
        finish (urb:build-anden-finish notch "Loseta" "Si" "Si" "20 x 20 cm"))
  (v579:check finish "notched sidewalk finish")
  (if finish (setq packed (urb:package-anden notch)))
  (v579:check (and packed (= (vla-get-ObjectName packed) "AcDbBlockReference"))
    "notched sidewalk packages as one block")
  (v579:check (= (length (urb:generated-objects parent)) 0)
    "notched sidewalk leaves no loose finish entities")

  ;; Los bloques reales se pueden extraer para recalcular sus tierras.
  (setq green (handent "AB3C7") gdata (urb:green-zone-data green)
        gb (urb:explode-green-block-boundary green))
  (v579:check (and gb (equal (vla-get-Area (vlax-ename->vla-object gb))
                        (atof (nth 3 gdata)) 1e-4))
    "green zone editable boundary and area")
  (if gb (entdel gb))
  (setq send (handent "10504B") sb (urb:send-temp-contour send))
  (v579:check sb "sender path editable boundary")
  (if sb (entdel sb))

  (v579:road-check)
  (v579:log (strcat "SUMMARY ok=" (itoa v579:ok) " fail=" (itoa v579:fail)))
  (if (= v579:fail 0) (v579:log "FINISHED")))

(if (findfile v579:out) (vl-file-delete v579:out))
(setq v579:r (vl-catch-all-apply 'v579:run nil))
(if (vl-catch-all-error-p v579:r)
  (v579:log (strcat "ERROR " (vl-catch-all-error-message v579:r))))
(princ)
