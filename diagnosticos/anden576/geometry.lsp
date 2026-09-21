(vl-load-com)

(setq g576:dir (getenv "URB_TEST_LAB"))
(setq g576:out (strcat g576:dir "/geometry576.txt"))

(defun g576:log (text / stream)
  (setq stream (open g576:out "a"))
  (write-line text stream)
  (close stream))

(defun g576:check (condition label)
  (g576:log (strcat (if condition "PASS " "FAIL ") label))
  (if (not condition) (vl-exit-with-error label)))

(defun g576:flat-y-p (points tolerance / low high point)
  (foreach point points
    (setq low (if low (min low (cadr point)) (cadr point))
          high (if high (max high (cadr point)) (cadr point))))
  (and low high (<= (- high low) tolerance)))

(defun g576:run (/ sparse dense ref chosen chain rings off tapered offset-poly offset-points)
  (g576:log (strcat "VERSION " *urb-version*))
  (g576:check (= *urb-version* "5.7.6") "engine version")

  ;; El borde inferior solo tiene vertices en sus extremos. El superior
  ;; tiene un vertice en el centro. Con la medicion vieja por vertices el
  ;; superior ganaba (5 m contra 50 m) aunque el clic estuviera a 1 m del
  ;; inferior. La distancia exacta a segmentos debe dar 1 m contra 5 m.
  (setq sparse '((0.0 0.0) (100.0 0.0))
        dense '((100.0 4.0) (50.0 4.0) (0.0 4.0))
        ref '(50.0 -1.0 0.0))
  (g576:check (< (abs (- (urb:chain-min-distance sparse ref) 1.0)) 1e-9)
    "distance to sparse long edge is exact")
  (g576:check (< (abs (- (urb:chain-min-distance dense ref) 5.0)) 1e-9)
    "distance to opposite dense edge is exact")

  (setq *urb-current-tactile-side-choice* nil
        *urb-current-tactile-side-point* ref
        chosen (urb:anden-tactile-chain
          '((0.0 0.0) (100.0 0.0) (100.0 4.0)
            (50.0 4.0) (0.0 4.0))))
  (g576:check (and chosen (= (length chosen) 2) (g576:flat-y-p chosen 1e-9)
                   (< (abs (cadar chosen)) 1e-9))
    "clicked road side wins even when it has fewer vertices")

  ;; La guia nueva devuelve un solo escalar de offset para todo el tramo.
  ;; En un corredor ancho conserva el nominal de 2.50 m.
  (setq chain (urb:open-poly-from-points '((0.0 0.0) (10.0 0.0)) 0.0)
        rings '(((0.0 0.0) (10.0 0.0) (10.0 3.0) (0.0 3.0)))
        off (urb:guide-uniform-offset chain rings 2.5 0.2 1.0))
  (g576:check (and off (< (abs (- off 2.5)) 1e-8))
    "wide corridor keeps one nominal guide offset")
  (setq offset-poly (urb:offset-poly chain off)
        offset-points (if offset-poly (urb:lwpoly-points-with-arcs-fine offset-poly) nil))
  (g576:check (and offset-points (g576:flat-y-p offset-points 1e-8))
    "guide offset of a straight road side remains straight")
  (if offset-poly (entdel offset-poly))

  ;; Si el ancho varia, se usa el minimo disponible UNA sola vez: el valor
  ;; esperado cerca del extremo angosto es 2.4 - 0.10 - 0.06 - 0.10.
  (setq tapered '(((0.0 0.0) (10.0 0.0) (10.0 3.0) (0.0 2.4)))
        off (urb:guide-uniform-offset chain tapered 2.5 0.2 1.0))
  (g576:log (strcat "TAPERED_UNIFORM_OFFSET=" (rtos off 2 8)))
  (g576:check (and off (> off 2.13) (< off 2.15))
    "variable width reduces the whole guide uniformly, without snaking")
  (entdel chain)
  (g576:log "FINISHED"))

(if (findfile g576:out) (vl-file-delete g576:out))
(setq g576:result (vl-catch-all-apply 'g576:run nil))
(if (vl-catch-all-error-p g576:result)
  (g576:log (strcat "FAILED " (vl-catch-all-error-message g576:result))))
(princ)
