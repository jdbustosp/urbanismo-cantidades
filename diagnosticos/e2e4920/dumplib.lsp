;; Vuelca la geometria de unas ventanas del plano a texto para dibujarla fuera
;; de AutoCAD. Los INSERT se explotan (sobre una COPIA del DWG que no se
;; guarda) hasta dejar solo primitivas en WCS. SOLO LECTURA del original.
(setq lab (getenv "URB_TEST_LAB"))
;; *o* lo abre el llamador
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

;; explota una REGION (copia) en curvas, las muestrea y las encadena en
;; lazos por coincidencia de extremos; vuelca cada lazo como relleno
(defun reg-fill (obj c / ex items piezas lazo cabo pz hallo s n it sub)
  (setq ex (vl-catch-all-apply 'vla-Explode (list obj)))
  (if (not (vl-catch-all-error-p ex))
    (progn
      (setq items (vl-catch-all-apply
                    '(lambda () (vlax-safearray->list (vlax-variant-value ex)))))
      (if (vl-catch-all-error-p items) (setq items nil))
      (setq piezas nil)
      (foreach it items
        (if (= (vla-get-ObjectName it) "AcDbRegion")
          (reg-fill it c)
          (progn
            (setq sub (vl-catch-all-apply 'curve-pts
                        (list it (if (= (vla-get-ObjectName it) "AcDbLine") 1 12))))
            (if (not (vl-catch-all-error-p sub)) (setq piezas (cons sub piezas))))))
      (foreach it items (vl-catch-all-apply 'vla-Delete (list it)))
      (while piezas
        (setq lazo (car piezas) piezas (cdr piezas) hallo T)
        (while (and hallo piezas)
          (setq cabo (last lazo) hallo nil)
          (foreach pz piezas
            (if (not hallo)
              (cond
                ((equal (car pz) cabo 1e-4)
                  (setq lazo (append lazo (cdr pz)) hallo T
                        piezas (vl-remove pz piezas)))
                ((equal (last pz) cabo 1e-4)
                  (setq lazo (append lazo (cdr (reverse pz))) hallo T
                        piezas (vl-remove pz piezas)))))))
        (if (> (length lazo) 2)
          (progn
            (setq s "" n 0)
            (foreach p lazo
              (setq s (strcat s " " (r2 (car p)) " " (r2 (cadr p))) n (1+ n)))
            (w (strcat "F " (itoa c) " S " (itoa n) s))))))))

;; puntos de un arco de bulge entre p1 y p2 (sin p1)
(defun bulge-pts (p1 p2 b / ang ch r mid cen a1 k res n)
  (if (< (abs b) 1e-9)
    (list p2)
    (progn
      (setq ang (* 4.0 (atan b)) ch (distance p1 p2)
            r (/ ch (* 2.0 (sin (/ ang 2.0))))
            mid (polar p1 (angle p1 p2) (/ ch 2.0))
            cen (polar mid (+ (angle p1 p2) (/ pi 2.0)) (* r (cos (/ ang 2.0))))
            a1 (angle cen p1) n 12 k 1 res nil)
      (repeat n
        (setq res (cons (polar cen (+ a1 (* ang (/ (float k) n))) (abs r)) res) k (1+ k)))
      (reverse res))))

;; relleno leido del DXF del HATCH (sirve aunque ya no sea asociativo, como
;; los que quedan al explotar un bloque). Devuelve T si pudo volcarlo.
(defun hatch-dxf-fill (obj c / ed rest pts lazos flag nv hb p b q ne tipo cen r a0 a1 ccw k tr tag solid)
  (setq ed (entget (vlax-vla-object->ename obj))
        rest (cdr (member (assoc 91 ed) ed)) lazos nil)
  (while (and rest (= (caar rest) 92))
    (setq flag (cdar rest) rest (cdr rest) pts nil)
    (if (= 2 (logand flag 2))
      (progn
        (setq hb (cdr (assoc 72 rest)))
        (setq rest (member (assoc 93 rest) rest) nv (cdar rest) rest (cdr rest))
        (repeat nv
          (setq p (cdar rest) rest (cdr rest) b 0.0)
          (if (= (caar rest) 42) (setq b (cdar rest) rest (cdr rest)))
          (setq pts (cons (list p b) pts)))
        (setq pts (reverse pts) q nil)
        (setq k 0)
        (repeat (length pts)
          (setq p (nth k pts))
          (setq q (append q (list (car p))))
          (setq q (append q (reverse (cdr (reverse
                    (bulge-pts (car p) (car (nth (rem (1+ k) (length pts)) pts)) (cadr p)))))))
          (setq k (1+ k)))
        (setq lazos (cons q lazos)))
      (progn
        (setq rest (member (assoc 93 rest) rest) ne (cdar rest) rest (cdr rest) q nil)
        (repeat ne
          (setq tipo (cdar rest) rest (cdr rest))
          (cond
            ((= tipo 1)
              (setq q (append q (list (cdr (assoc 10 rest)) (cdr (assoc 11 rest)))))
              (setq rest (cdr (member (assoc 11 rest) rest))))
            ((= tipo 2)
              (setq cen (cdr (assoc 10 rest)) r (cdr (assoc 40 rest))
                    a0 (* pi (/ (cdr (assoc 50 rest)) 180.0))
                    a1 (* pi (/ (cdr (assoc 51 rest)) 180.0))
                    ccw (cdr (assoc 73 rest)))
              (if (< a1 a0) (setq a1 (+ a1 (* 2 pi))))
              (setq k 0)
              (repeat 13
                (setq q (append q (list (polar cen (if (= ccw 1)
                                                     (+ a0 (* (- a1 a0) (/ k 12.0)))
                                                     (- (- a0) (* (- a1 a0) (/ k 12.0))))
                                              r)))
                      k (1+ k)))
              (setq rest (cdr (member (assoc 73 rest) rest))))
            (T (setq rest nil ne 0))))
        (setq lazos (cons q lazos))))
    ;; saltar las referencias a objetos de origen
    (if (and rest (= (caar rest) 97))
      (progn (setq k (cdar rest) rest (cdr rest))
             (repeat k (if (= (caar rest) 330) (setq rest (cdr rest)))))))
  (setq tr (vl-catch-all-apply 'vla-get-EntityTransparency (list obj)))
  (setq tag (if (and (= (type tr) 'STR) (/= (strcase tr) "BYLAYER")
                     (/= tr "0") (/= (strcase tr) "BYBLOCK")) "T" "F"))
  (setq solid (= (strcase (vla-get-PatternName obj)) "SOLID"))
  (foreach q lazos
    (if (> (length q) 2)
      (w (strcat tag " " (itoa c) " " (if solid "S" "P") " " (itoa (length q))
           (apply 'strcat (mapcar '(lambda (p) (strcat " " (r2 (car p)) " " (r2 (cadr p)))) q))))))
  (if lazos T nil))

;; relleno de un HATCH reconstruyendo su borde con -HATCHEDIT (vale aunque
;; ya no sea asociativo, como los que quedan al explotar un bloque)
(defun hatch-recreate-fill (obj c / marca en pts tr tag solid lazos r)
  (setq marca (entlast) lazos nil)
  (setq r (vl-catch-all-apply
    '(lambda () (command "_.-HATCHEDIT" (vlax-vla-object->ename obj) "_B" "_P" "_N"))))
  (setq en (entnext marca))
  (while en
    (if (= (cdr (assoc 0 (entget en))) "LWPOLYLINE")
      (progn
        (setq pts (vl-catch-all-apply 'curve-pts
                    (list (vlax-ename->vla-object en)
                          (* 8 (max 1 (fix (vlax-curve-getEndParam en)))))))
        (if (not (vl-catch-all-error-p pts)) (setq lazos (cons pts lazos)))))
    (setq marca en en (entnext en))
    (entdel marca))
  (setq tr (vl-catch-all-apply 'vla-get-EntityTransparency (list obj)))
  (setq tag (if (and (= (type tr) 'STR) (/= (strcase tr) "BYLAYER")
                     (/= tr "0") (/= (strcase tr) "BYBLOCK")) "T" "F"))
  (setq solid (= (strcase (vla-get-PatternName obj)) "SOLID"))
  (foreach q lazos
    (if (> (length q) 2)
      (w (strcat tag " " (itoa c) " " (if solid "S" "P") " " (itoa (length q))
           (apply 'strcat (mapcar '(lambda (p) (strcat " " (r2 (car p)) " " (r2 (cadr p)))) q))))))
  (if lazos T nil))

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
    ;; REGION (las bandas del anden): se reencadena con el motor y se
    ;; vuelca como poligono relleno de su color
    ((and (= nm "AcDbRegion") urb:region-loops)
      (setq loop (vl-catch-all-apply 'urb:region-loops (list obj)))
      (if (or (null loop) (vl-catch-all-error-p loop))
        ;; con arcos (recorte de un bordillo curvo) region-loops no
        ;; reencadena: se explota y se encadena aqui por puntos
        (reg-fill obj c))
      (if (and loop (not (vl-catch-all-error-p loop)))
        (foreach lp loop
          (if (and (listp lp) (> (length lp) 2))
            (progn
              (setq s "" n 0)
              (foreach v lp
                (setq s (strcat s " " (r2 (car (car v))) " " (r2 (cadr (car v))))
                      n (1+ n)))
              (w (strcat "F " (itoa c) " S " (itoa n) s)))))))
    ((and (= nm "AcDbHatch") (hatch-recreate-fill obj c)) nil)
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
  (setq ss (ssget "_X") i 0 n 0)
  (repeat (if ss (sslength ss) 0)
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

