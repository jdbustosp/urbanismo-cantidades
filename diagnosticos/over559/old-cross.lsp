(defun ov:old-cross (points / n i j p1 p2 p3 p4 found)
  ;; Revisa todo par de aristas NO adyacentes del contorno cerrado en
  ;; busca de un cruce real (poligono "moño"/autointersectado).
  (setq n (length points) found nil i 0)
  (while (and (< i n) (not found))
    (setq p1 (nth i points) p2 (nth (rem (1+ i) n) points))
    (setq j (+ i 2))
    (while (and (<= j (1- n)) (not found))
      (if (not (and (= i 0) (= j (1- n))))
        (progn
          (setq p3 (nth j points) p4 (nth (rem (1+ j) n) points))
          (if (urb:segments-cross-p p1 p2 p3 p4)
            (setq found T))))
      (setq j (1+ j)))
    (setq i (1+ i)))
  found)

