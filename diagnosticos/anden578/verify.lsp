(vl-load-com)

(setq v578:dir
  "C:/Users/juanbusper/Documents/URBANISMO/work/anden578_20260921"
      v578:out (strcat v578:dir "/verify578.txt")
      v578:ok 0
      v578:fail 0)

(defun v578:log (text / stream)
  (setq stream (open v578:out "a"))
  (write-line text stream)
  (close stream))

(defun v578:check (condition label)
  (if condition
    (progn
      (setq v578:ok (1+ v578:ok))
      (v578:log (strcat "PASS " label)))
    (progn
      (setq v578:fail (1+ v578:fail))
      (v578:log (strcat "FAIL " label)))))

(defun v578:max-deviation (chain / a b point value best)
  (setq a (car chain) b (last chain) best 0.0)
  (foreach point chain
    (setq value (urb:dist-point-seg point a b))
    (if (> value best) (setq best value)))
  best)

(defun v578:chains (ename / points clean corners)
  (setq points (urb:anden-block-points ename)
        clean (urb:dedupe-ring-points points)
        corners (urb:polygon-corner-indices clean (* pi (/ 45.0 180.0))))
  (urb:polygon-chains-at-corners clean corners))

(defun v578:point-chains (points / clean corners)
  (setq clean (urb:dedupe-ring-points points)
        corners (urb:polygon-corner-indices clean (* pi (/ 45.0 180.0))))
  (urb:polygon-chains-at-corners clean corners))

(defun v578:find-straight-chain-in-points
  (points / chain found length-value drift-value deviation-value)
  (foreach chain (v578:point-chains points)
    (setq length-value (urb:chain-total-length chain)
          drift-value (/ (* (urb:chain-direction-drift chain) 180.0) pi)
          deviation-value (v578:max-deviation chain))
    (if (and (> length-value 90.0)
             (< length-value 110.0)
             (> drift-value 10.0)
             (< deviation-value 0.02))
      (setq found chain)))
  found)

(defun v578:find-chain (ename min-length max-length min-drift max-deviation
                        / chain found length-value drift-value deviation-value)
  (foreach chain (v578:chains ename)
    (setq length-value (urb:chain-total-length chain)
          drift-value (/ (* (urb:chain-direction-drift chain) 180.0) pi)
          deviation-value (v578:max-deviation chain))
    (if (and (> length-value min-length)
             (< length-value max-length)
             (> drift-value min-drift)
             (< deviation-value max-deviation))
      (setq found chain)))
  found)

(defun v578:find-curved-chain (ename / chain found)
  (foreach chain (v578:chains ename)
    (if (and (> (urb:chain-total-length chain) 150.0)
             (> (urb:chain-direction-drift chain) (* pi (/ 10.0 180.0)))
             (> (v578:max-deviation chain) 5.0))
      (setq found chain)))
  found)

(defun v578:midpoint-longest-edge (chain / edge selected best p1 p2)
  (setq best -1.0)
  (foreach edge (urb:open-chain-edges chain)
    (if (> (nth 2 edge) best)
      (setq best (nth 2 edge) selected edge)))
  (setq p1 (nth 0 selected) p2 (nth 1 selected))
  (mapcar '(lambda (a b) (* 0.5 (+ a b))) p1 p2))

(defun v578:log-chains (label chains / chain)
  (foreach chain chains
    (v578:log
      (strcat label
        " len=" (rtos (urb:chain-total-length chain) 2 4)
        " drift="
          (rtos (/ (* (urb:chain-direction-drift chain) 180.0) pi) 2 4)
        " dev=" (rtos (v578:max-deviation chain) 2 6)
        " off="
          (rtos (urb:chain-off-axis-length
                  chain (* pi (/ 2.0 180.0))) 2 6)))))

(defun v578:run (/ straight-block curved-block straight-chain curved-chain
                    off-axis old-result selftests item points clusters
        boundary data anchor raw-anchor result packed start build-ms pack-ms
        parent-handle driving-after boundary-points boundary-straight)
  (v578:log (strcat "VERSION " *urb-version*))
  (v578:check (= *urb-version* "5.7.8") "engine version")
  (v578:check
    (= (strcase (vl-string-translate "\\" "/"
         (strcat (getvar "DWGPREFIX") (getvar "DWGNAME"))))
       (strcase (strcat v578:dir "/fixture.dwg")))
    "correct fixture")

  (setq straight-block (handent "104A88")
        curved-block (handent "F9686"))
  (v578:check straight-block "real straight sidewalk 104A88 exists")
  (v578:check curved-block "real curved sidewalk F9686 exists")

  (setq straight-chain
    (v578:find-chain straight-block 90.0 110.0 10.0 0.02))
  (v578:check straight-chain
    "real 99.6 m side with centimetric residual is reproduced")
  (if straight-chain
    (progn
      (setq off-axis
        (urb:chain-off-axis-length
          straight-chain (* pi (/ 2.0 180.0)))
            old-result
        (and (> (urb:chain-total-length straight-chain) 0.40)
             (> (urb:chain-direction-drift straight-chain)
                (* pi (/ 2.0 180.0)))))
      (v578:log
        (strcat "STRAIGHT length="
          (rtos (urb:chain-total-length straight-chain) 2 4)
          " drift="
          (rtos (/ (* (urb:chain-direction-drift straight-chain) 180.0) pi) 2 4)
          " deviation=" (rtos (v578:max-deviation straight-chain) 2 6)
          " off_axis=" (rtos off-axis 2 6)))
      (v578:check old-result
        "previous angular rule reproduces false segmented decision")
      (v578:check (< off-axis 0.04)
        "off-axis residue is under four centimetres")
      (v578:check (not (urb:anden-needs-segmented-p straight-chain))
        "new rule keeps real straight side on one modulation axis")))

  (setq curved-chain (v578:find-curved-chain curved-block))
  (v578:check curved-chain "real sustained curve is reproduced")
  (if curved-chain
    (progn
      (v578:log
        (strcat "CURVE length="
          (rtos (urb:chain-total-length curved-chain) 2 4)
          " drift="
          (rtos (/ (* (urb:chain-direction-drift curved-chain) 180.0) pi) 2 4)
          " deviation=" (rtos (v578:max-deviation curved-chain) 2 6)
          " off_axis="
          (rtos (urb:chain-off-axis-length
                  curved-chain (* pi (/ 2.0 180.0))) 2 6)))
      (v578:check (urb:anden-needs-segmented-p curved-chain)
        "new rule preserves segmented modulation on real curve")))

  (setq selftests (urb:quality-selftests))
  (foreach item selftests
    (v578:check (cadr item) (strcat "selftest: " (car item))))

  ;; Reconstruccion real del bloque de la captura sobre una copia local.
  ;; El ancla se pone en el borde recto encontrado arriba: asi la prueba
  ;; usa exactamente el costado que antes disparaba la cuna diagonal.
  (setq data (urb:anden-block-data straight-block)
        boundary (urb:explode-anden-block-boundary straight-block)
        boundary-points (urb:lwpoly-points-with-arcs-fine boundary)
        boundary-straight (v578:find-straight-chain-in-points boundary-points)
        raw-anchor (v578:midpoint-longest-edge straight-chain)
        anchor (urb:tactile-side-anchor boundary-points raw-anchor)
        points (urb:lwpoly-points-with-arcs boundary)
        clusters (urb:dominant-anden-axis-clusters points)
        *urb-current-tactile-side-choice* nil
        *urb-current-tactile-side-point* anchor
        *urb-current-tactile-side-anchor* anchor)
  (v578:check boundary "real boundary is recovered from block")
  (vla-put-Visible (vlax-ename->vla-object straight-block) :vlax-false)
  (v578:log-chains "BOUNDARY_CHAIN" (v578:point-chains boundary-points))
  (v578:check (= (length clusters) 1)
    "straight sidewalk has one dominant material axis")
  (urb:set-anden-data boundary
    (nth 1 data) (nth 2 data) (nth 3 data)
    (nth 7 data) (nth 8 data) (nth 9 data)
    (nth 10 data) (nth 11 data) (nth 12 data))
  (setq parent-handle (cdr (assoc 5 (entget boundary)))
        driving-after
          (urb:anden-tactile-chain
            (urb:lwpoly-points-with-arcs-fine boundary)))
  (v578:check (urb:anden-needs-segmented-p driving-after)
    "production selector preserves the real gradual curve")
  (setq start (getvar "MILLISECS")
        result (urb:build-anden-finish boundary
                 (nth 1 data) (nth 7 data) (nth 8 data) (nth 9 data))
        build-ms (- (getvar "MILLISECS") start))
  (v578:check result "real straight sidewalk finish rebuilds")
  (setq start (getvar "MILLISECS")
        packed (urb:package-anden boundary)
        pack-ms (- (getvar "MILLISECS") start))
  (v578:check packed "rebuilt sidewalk packages")
  (v578:check (= (vla-get-ObjectName packed) "AcDbBlockReference")
    "rebuilt sidewalk is one block reference")
  (v578:check (= (length (urb:generated-objects parent-handle)) 0)
    "rebuilt sidewalk leaves zero loose pieces")
  (v578:log
    (strcat "BUILD build_ms=" (itoa build-ms)
      " pack_ms=" (itoa pack-ms)
      " path=segmented_with_continuous_miter_phase"))
  (v578:log
    (strcat "SUMMARY ok=" (itoa v578:ok) " fail=" (itoa v578:fail)))
  (if (= v578:fail 0) (v578:log "FINISHED")))

(if (findfile v578:out) (vl-file-delete v578:out))
(setq v578:result (vl-catch-all-apply 'v578:run nil))
(if (vl-catch-all-error-p v578:result)
  (v578:log (strcat "ERROR " (vl-catch-all-error-message v578:result))))
(princ)
