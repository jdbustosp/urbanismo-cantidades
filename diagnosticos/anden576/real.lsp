(vl-load-com)

(setq r576:dir (getenv "URB_TEST_LAB"))
(setq r576:out (strcat r576:dir "/real576.txt"))

(defun r576:log (text / stream)
  (setq stream (open r576:out "a"))
  (write-line text stream)
  (close stream))

(defun r576:check (condition label)
  (r576:log (strcat (if condition "PASS " "FAIL ") label))
  (if (not condition) (vl-exit-with-error label)))

(defun r576:loose (handle / *urb-generation-parent* *urb-generation-start*)
  (length (urb:generated-objects handle)))

(defun r576:curve-distance-range (ename chain / points point value low high)
  (setq points (urb:lwpoly-points-with-arcs-fine ename))
  (foreach point points
    (setq value (urb:chain-min-distance chain point)
          low (if low (min low value) value)
          high (if high (max high value) value)))
  (if low (list low high (- high low) (length points)) nil))

(defun r576:long-chain-min-distance (points reference / clean corners chains maxlen chain chain-len candidates best)
  (setq clean (urb:dedupe-ring-points points)
        corners (urb:polygon-corner-indices clean (* pi (/ 45.0 180.0)))
        chains (urb:polygon-chains-at-corners clean corners)
        maxlen 0.0)
  (foreach chain chains
    (setq chain-len (urb:chain-total-length chain))
    (if (> chain-len maxlen) (setq maxlen chain-len)))
  (foreach chain chains
    (if (> (urb:chain-total-length chain) (max 0.5 (* 0.25 maxlen)))
      (setq candidates (cons chain candidates))))
  (foreach chain (if candidates candidates chains)
    (setq chain-len (urb:chain-min-distance chain reference))
    (if (or (null best) (< chain-len best)) (setq best chain-len)))
  best)

(defun r576:run (/ target original boundary handle points driving reference nearest
                   result start build-ms packed pack-ms)
  (r576:log (strcat "VERSION " *urb-version*))
  (r576:check (= *urb-version* "5.7.6") "engine version")
  (if (/= (strcase (vl-string-translate "\\" "/"
          (strcat (getvar "DWGPREFIX") (getvar "DWGNAME"))))
        (strcase (strcat r576:dir "/fixture.dwg")))
    (vl-exit-with-error "Wrong fixture"))

  (foreach original (urb:all-anden-blocks)
    (if (wcmatch (cdr (assoc 2 (entget original))) "URB_ANDEN_13D362_*")
      (setq target original)))
  (r576:check target "real 188 m source sidewalk exists")
  (setq boundary (urb:explode-anden-block-boundary target)
        handle (cdr (assoc 5 (entget boundary)))
        points (urb:lwpoly-points-with-arcs-fine boundary)
        reference '(83038.9 95306.5 0.0)
        *urb-current-tactile-side-point* reference
        *urb-current-tactile-side-choice* nil
        driving (urb:anden-tactile-chain points))
  (if (and (urb:anden-near-root-container-p boundary)
           (not (vl-some '(lambda (item)
             (and (= (car item) 42) (not (equal (cdr item) 0.0 1e-12))))
             (entget boundary))))
    (setq driving (urb:anden-tactile-chain (urb:ring-remove-notches points))))
  (setq nearest (r576:long-chain-min-distance points reference))
  (r576:log (strcat "SIDE_DISTANCE chosen="
    (rtos (urb:chain-min-distance driving reference) 2 6)
    " nearest=" (rtos nearest 2 6)
    " chain_points=" (itoa (length driving))))
  (r576:check (< (abs (- (urb:chain-min-distance driving reference) nearest)) 1e-5)
    "production chain is the long side nearest the road-side click")

  (urb:set-anden-data boundary "Loseta" "4" "4B" "Si" "Si"
    "20 x 20 cm" "No" "SUP_TN" "Via creada")
  (setq start (getvar "MILLISECS")
        result (urb:build-anden-finish boundary "Loseta" "Si" "Si" "20 x 20 cm")
        build-ms (- (getvar "MILLISECS") start))
  (r576:check result "real finish builder accepts guide and toperol")
  (setq start (getvar "MILLISECS")
        packed (urb:package-anden boundary)
        pack-ms (- (getvar "MILLISECS") start))
  (r576:check packed "real sidewalk packages")
  (r576:check (= (vla-get-ObjectName packed) "AcDbBlockReference")
    "result is one block reference")
  (r576:check (= (r576:loose handle) 0) "zero loose generated pieces")
  (r576:log (strcat "TIMES build=" (itoa build-ms) " pack=" (itoa pack-ms)
    " total=" (itoa (+ build-ms pack-ms))))
  (r576:log (strcat "BLOCK " (vla-get-Handle packed) " " (vla-get-Name packed)))
  (r576:log "FINISHED (fixture only; no terrain and no save)"))

(if (findfile r576:out) (vl-file-delete r576:out))
(setq r576:result (vl-catch-all-apply 'r576:run nil))
(if (vl-catch-all-error-p r576:result)
  (r576:log (strcat "FAILED " (vl-catch-all-error-message r576:result))))
(princ)
