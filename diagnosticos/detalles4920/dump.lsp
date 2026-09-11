;; Vuelca la geometria de unas ventanas del plano a texto para dibujarla fuera
;; de AutoCAD. Los INSERT se explotan (sobre una COPIA del DWG que no se
;; guarda) hasta dejar solo primitivas en WCS. SOLO LECTURA del original.
(setq lab (getenv "URB_TEST_LAB"))
(setq *o* (open (strcat lab "/dump.txt") "w"))
(defun w (s) (write-line s *o*))
(setvar "CMDECHO" 0)

(defun col (obj / c)
  (setq c (vl-catch-all-apply 'vla-get-Color (list obj)))
  (if (or (vl-catch-all-error-p c) (= c 256) (= c 0))
    (progn
      (setq c (vl-catch-all-apply
        '(lambda () (vla-get-Color
           (vla-Item (vla-get-Layers (vla-get-ActiveDocument (vlax-get-acad-object)))
                     (vla-get-Layer obj))))))
      (if (vl-catch-all-error-p c) 7 c))
    c))

(defun r2 (v) (rtos v 2 3))

(defun curve-pts (obj n / en p0 p1 i pts)
  (setq en (vlax-vla-object->ename obj)
        p0 (vlax-curve-getStartParam en) p1 (vlax-curve-getEndParam en) i 0 pts nil)
  (repeat (1+ n)
    (setq pts (cons (vlax-curve-getPointAtParam en (+ p0 (* (- p1 p0) (/ (float i) n)))) pts)
          i (1+ i)))
  (reverse pts))

(defun dump-prim (obj / nm c pts s cen i loop n e p)
  (setq nm (vla-get-ObjectName obj) c (col obj))
  (cond
    ((= nm "AcDbLine")
      (setq pts (list (vlax-safearray->list (vlax-variant-value (vla-get-StartPoint obj)))
                      (vlax-safearray->list (vlax-variant-value (vla-get-EndPoint obj)))))
      (w (strcat "L " (itoa c) " " (r2 (car (car pts))) " " (r2 (cadr (car pts)))
           " " (r2 (car (cadr pts))) " " (r2 (cadr (cadr pts))))))
    ((= nm "AcDbCircle")
      (setq cen (vlax-safearray->list (vlax-variant-value (vla-get-Center obj))))
      (w (strcat "C " (itoa c) " " (r2 (car cen)) " " (r2 (cadr cen))
           " " (rtos (vla-get-Radius obj) 2 4))))
    ((member nm '("AcDbPolyline" "AcDb2dPolyline" "AcDbArc" "AcDbSpline" "AcDbEllipse"))
      (setq pts (vl-catch-all-apply 'curve-pts
                  (list obj (if (= nm "AcDbPolyline")
                              (* 8 (max 1 (fix (vlax-curve-getEndParam (vlax-vla-object->ename obj)))))
                              24))))
      (if (not (vl-catch-all-error-p pts))
        (progn
          (setq s (strcat "P " (itoa c) " " (itoa (length pts))))
          (foreach p pts (setq s (strcat s " " (r2 (car p)) " " (r2 (cadr p)))))
          (w s))))
    ((= nm "AcDbHatch")
      ;; relleno: se vuelca cada lazo exterior como poligono relleno
      (setq i 0)
      (repeat (vla-get-NumberOfLoops obj)
        (setq loop (vl-catch-all-apply
          '(lambda ( / v) (vla-GetLoopAt obj i 'v) (vlax-safearray->list v))))
        (if (not (vl-catch-all-error-p loop))
          (progn
            (setq s "" n 0)
            (foreach e loop
              (setq pts (vl-catch-all-apply 'curve-pts (list e 8)))
              (if (not (vl-catch-all-error-p pts))
                (foreach p pts (setq s (strcat s " " (r2 (car p)) " " (r2 (cadr p))) n (1+ n)))))
            (if (> n 2)
              (w (strcat "F " (itoa c) " "
                   (if (= (strcase (vla-get-PatternName obj)) "SOLID") "S" "P")
                   " " (itoa n) s)))))
        (setq i (1+ i))))))

;; explota recursivamente un INSERT (copias) y vuelca sus primitivas
(defun dump-insert (obj depth / ex items it)
  (setq ex (vl-catch-all-apply 'vla-Explode (list obj)))
  (if (not (vl-catch-all-error-p ex))
    (progn
      ;; un bloque que explota a nada da un arreglo vacio: no revienta
      (setq items (vl-catch-all-apply
                    '(lambda () (vlax-safearray->list (vlax-variant-value ex)))))
      (if (vl-catch-all-error-p items) (setq items nil))
      (foreach it items
        (vl-catch-all-apply
          '(lambda ()
            (if (and (= (vla-get-ObjectName it) "AcDbBlockReference") (< depth 6))
              (dump-insert it (1+ depth))
              (dump-prim it))))
        (vl-catch-all-apply 'vla-Delete (list it))))))

(defun dentro-p (obj x1 y1 x2 y2 / r lo hi)
  (setq r (vl-catch-all-apply
    '(lambda () (vla-GetBoundingBox obj 'lo 'hi)
       (list (vlax-safearray->list lo) (vlax-safearray->list hi)))))
  (and (not (vl-catch-all-error-p r))
       (< (car (car r)) x2) (> (car (cadr r)) x1)
       (< (cadr (car r)) y2) (> (cadr (cadr r)) y1)))

(defun ventana (nombre x1 y1 x2 y2 explotar / ss i obj n r lo hi)
  (w (strcat "W " nombre " " (r2 x1) " " (r2 y1) " " (r2 x2) " " (r2 y2)))
  (setq ss (ssget "_X" '((410 . "Model"))) i 0 n 0)
  (repeat (sslength ss)
    (setq obj (vlax-ename->vla-object (ssname ss i)) i (1+ i))
    (if (vl-catch-all-apply 'dentro-p (list obj x1 y1 x2 y2))
      (progn
        (setq n (1+ n))
        (if (= (vla-get-ObjectName obj) "AcDbBlockReference")
          (if explotar
            (dump-insert obj 0)
            ;; en el panorama solo la caja y el nombre, para ubicar detalles
            (progn
              (setq r (vl-catch-all-apply
                '(lambda () (vla-GetBoundingBox obj 'lo 'hi)
                   (list (vlax-safearray->list lo) (vlax-safearray->list hi)))))
              (if (not (vl-catch-all-error-p r))
                (w (strcat "B " (vla-get-EffectiveName obj) "|"
                     (r2 (car (car r))) " " (r2 (cadr (car r))) " "
                     (r2 (car (cadr r))) " " (r2 (cadr (cadr r))))))))
          (vl-catch-all-apply 'dump-prim (list obj))))))
  (w (strcat "E " nombre " " (itoa n))))

;; ventanas: detalle del acceso vehicular (explotado) y panorama (cajas)
(ventana "mod47" 85250.0 96536.0 85312.0 96556.0 T)
(w "DONE")
(close *o*)
;; marca de fin para el runner de AutoCAD completo
(setq *m* (open (strcat lab "/png_log.txt") "w"))
(write-line "DONE" *m*)
(close *m*)
