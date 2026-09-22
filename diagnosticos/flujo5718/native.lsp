(vl-load-com)
(setq f18:out "C:/Users/juanbusper/Documents/URBANISMO/work/flujo5718/native.txt"
      f18:pass 0 f18:fail 0)
(defun f18:log (s / f) (setq f (open f18:out "a")) (write-line s f) (close f))
(defun f18:check (ok s)
  (if ok (setq f18:pass (1+ f18:pass)) (setq f18:fail (1+ f18:fail)))
  (f18:log (strcat (if ok "PASS " "FAIL ") s)))
(defun f18:s-curve (/ r th d b p0 p1 p2 q0 q1 q2 dx dy)
  (setq r 80.0 th 0.5 d 1.75 b (/ (sin (/ th 4.0)) (cos (/ th 4.0)))
    dx 1000.0 dy 1000.0 p0 (list dx (+ dy d))
    p1 (list (+ dx (* (- r d) (sin th))) (+ dy r (- (* (- r d) (cos th)))))
    p2 (list (+ dx (* 2 r (sin th))) (+ dy (* 2 r (- 1 (cos th))) d))
    q0 (list dx (- dy d))
    q1 (list (+ dx (* (+ r d) (sin th))) (+ dy r (- (* (+ r d) (cos th)))))
    q2 (list (+ dx (* 2 r (sin th))) (- (+ dy (* 2 r (- 1 (cos th)))) d)))
  (entmakex (list '(0 . "LWPOLYLINE") '(100 . "AcDbEntity") '(8 . "URB-ANDEN")
    '(100 . "AcDbPolyline") '(90 . 6) '(70 . 1)
    (cons 10 p0) (cons 42 b) (cons 10 p1) (cons 42 (- b)) (cons 10 p2) '(42 . 0.0)
    (cons 10 q2) (cons 42 b) (cons 10 q1) (cons 42 (- b)) (cons 10 q0) '(42 . 0.0))))
(defun f18:run (/ en h built objects o a angles maxdev dev)
  (f18:check (= *urb-version* "5.7.18") "version")
  (urb:prepare-anden-layers)
  (setq en (f18:s-curve) h (cdr (assoc 5 (entget en))))
  (urb:set-xdata-strings en "URB_ANDEN_AXIS" '("0.0"))
  (urb:set-anden-pattern-mode en "AUTOMATICO")
  (setq *urb-generation-parent* h)
  (setq built (vl-catch-all-apply 'urb:create-composite-loseta (list en "20 x 20 cm")))
  (f18:check (and (not (vl-catch-all-error-p built)) built) "curved finish generated")
  (setq objects (urb:generated-objects h) angles nil)
  (foreach o objects
    ;; create-composite-loseta no crea tactiles: todos sus HATCH son del
    ;; material. Las capas pueden ser LISA, GRIS, BLANCO o ADOQUIN.
    (if (= (vla-get-ObjectName o) "AcDbHatch")
      (progn
        (setq a (vl-catch-all-apply 'vla-get-PatternAngle (list o)))
        (if (numberp a) (setq angles (cons (urb:normalize-axis-angle a) angles))))))
  ;; El acabado compuesto contiene dos familias ortogonales (losetas y
  ;; juntas). Lo incorrecto es una tercera orientacion progresiva en
  ;; abanico, no la perpendicularidad propia del patron.
  (setq maxdev 0.0)
  (foreach a angles
    (setq dev
      (min (urb:axis-angle-distance a 0.0)
           (urb:axis-angle-distance a (/ pi 2.0))))
    (setq maxdev (max maxdev dev)))
  (f18:log (strcat "MATERIAL_HATCHES " (itoa (length angles)) " MAX_OFF_MARKED_OR_ORTHOGONAL " (rtos maxdev 2 10)))
  (f18:check (> (length angles) 1) "material hatches inspected")
  (f18:check (< maxdev 1e-7) "all curved material obeys marked axis or its orthogonal; no fan")
  (f18:log (strcat "SUMMARY pass=" (itoa f18:pass) " fail=" (itoa f18:fail)))
  (if (= f18:fail 0) (f18:log "FINISHED")))
(f18:log "STARTED")
(setq f18:r (vl-catch-all-apply 'f18:run nil))
(if (vl-catch-all-error-p f18:r) (f18:log (strcat "ERROR " (vl-catch-all-error-message f18:r))))
(princ)
