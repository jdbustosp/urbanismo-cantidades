(defun ov:old-triangulate
  (points / verts triangles guard n i prev cur nxt test contains ear-found)
  ;; Ear clipping sobre el contorno ordenado de la LWPOLYLINE. Cada
  ;; triangulo es convexo y su interseccion con una banda tambien lo es;
  ;; evita la operacion ACIS multi-isla que falla en curvas concavas.
  (setq verts (urb:clean-polygon-points points))
  (if (< (urb:polygon-signed-area verts) 0.0)
    (setq verts (reverse verts)))
  (setq guard 0 triangles nil)
  (while (and (> (length verts) 3) (< guard 20000))
    (setq n (length verts) i 0 ear-found nil)
    (while (and (< i n) (not ear-found))
      (setq prev (nth (rem (+ i n -1) n) verts)
            cur (nth i verts)
            nxt (nth (rem (1+ i) n) verts))
      (if (> (urb:triangle-cross prev cur nxt) 1e-10)
        (progn
          (setq contains nil)
          (foreach test verts
            (if (and (not contains)
                     (not (urb:point-near-2d-p test prev 1e-12))
                     (not (urb:point-near-2d-p test cur 1e-12))
                     (not (urb:point-near-2d-p test nxt 1e-12))
                     (urb:point-in-triangle-p test prev cur nxt))
              (setq contains T)))
          (if (not contains)
            (progn
              (setq triangles (cons (list prev cur nxt) triangles)
                    verts (urb:remove-point-once verts cur)
                    ear-found T)))))
      (setq i (1+ i)))
    (if (not ear-found) (setq guard 20000))
    (setq guard (1+ guard)))
  (if (= (length verts) 3)
    (reverse (cons verts triangles))
    nil)
)

