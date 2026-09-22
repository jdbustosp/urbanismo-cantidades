(defun p17:baseline-scanline (points step / pts rest a b edges levels y0 y1 ym
   hits edge pair l0 l1 r0 r1 n k f0 f1 p0 p1 p2 p3 quad centroid weight ox oy z out height)
  ;; 5.7.4: trapecios recortados entre TODOS los niveles de vertices.
  ;; Cada celda aporta area y centroide reales, sin normalizacion global.
  ;; Evita perder remates <0.25m y conserva integrales de planos lineales.
  ;; Coordenadas locales: estabilidad en las coordenadas grandes del DWG.
  (if (and (> (length points) 2) (> step 0.0))
    (progn
      (setq ox (caar points) oy (cadar points)
            z (if (caddr (car points)) (caddr (car points)) 0.0)
            pts (mapcar '(lambda (p) (list (- (car p) ox) (- (cadr p) oy))) points)
            rest (append pts (list (car pts)))
            levels (vl-sort (mapcar 'cadr pts) '<))
      (while (cdr rest)
        (setq a (car rest) b (cadr rest))
        (if (/= (cadr a) (cadr b)) (setq edges (cons (list a b) edges)))
        (setq rest (cdr rest)))
      (while (cdr levels)
        (setq y0 (car levels) y1 (cadr levels))
        (while (< y0 (- y1 1e-10))
          (setq height (min step (- y1 y0)) ym (+ y0 (* 0.5 height)) hits nil)
          (foreach edge edges
            (setq a (car edge) b (cadr edge))
            (if (or (and (<= (cadr a) ym) (< ym (cadr b)))
                    (and (<= (cadr b) ym) (< ym (cadr a))))
              (setq hits (cons (list (urb:earthwork-strip-x edge ym) edge) hits))))
          (setq hits (mapcar '(lambda (i) (nth i hits))
            (vl-sort-i hits '(lambda (a b) (< (car a) (car b))))))
          (while (cdr hits)
            (setq pair (list (cadar hits) (cadadr hits)) hits (cddr hits)
                  l0 (urb:earthwork-strip-x (car pair) y0)
                  l1 (urb:earthwork-strip-x (car pair) (+ y0 height))
                  r0 (urb:earthwork-strip-x (cadr pair) y0)
                  r1 (urb:earthwork-strip-x (cadr pair) (+ y0 height))
                  n (max 1 (fix (+ 0.999999999 (/ (max (- r0 l0) (- r1 l1)) step)))) k 0)
            (repeat n
              (setq f0 (/ (float k) n) f1 (/ (float (1+ k)) n)
                    p0 (list (+ l0 (* f0 (- r0 l0))) y0)
                    p1 (list (+ l0 (* f1 (- r0 l0))) y0)
                    p2 (list (+ l1 (* f1 (- r1 l1))) (+ y0 height))
                    p3 (list (+ l1 (* f0 (- r1 l1))) (+ y0 height)))
              ;; Un trapecio convexo necesita una sola consulta a la superficie:
              ;; su centroide y area integran exactamente cualquier plano lineal.
              ;; Antes se dividia siempre en dos triangulos, duplicando las
              ;; llamadas COM sin ganar precision sobre una superficie TIN.
              (setq quad (list p0 p1 p2 p3)
                    weight (abs (urb:polygon-signed-area quad))
                    centroid (urb:polygon-centroid quad))
              (if (and centroid (> weight 1e-14))
                (setq out (cons (list
                  (list (+ ox (car centroid)) (+ oy (cadr centroid)) z)
                  weight) out)))
              (setq k (1+ k))))
          (setq y0 (+ y0 height)))
        (setq levels (cdr levels)))
      out)))
