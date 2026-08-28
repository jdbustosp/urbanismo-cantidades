;;; extraer_rec.lsp — extrae de los records los datos para el cruce:
;;; ACU: posiciones de V-NODE-ACU -> rec_acu_nodes.lsp
;;; PLU: segmentos de LLUVIAS-RECIEN-CONST (MLINE/LINE/LWPOLY/ARC),
;;;      pozos PZ_LLUV_RC, sumideros SUMIDERO RECIEN CONSTRUIDO
;;;      -> rec_plu_data.lsp
;;; Solo DXF/entget (accoreconsole).
(defun rec:wp (f x y) (write-line (strcat "  (" (rtos x 2 3) " " (rtos y 2 3) ")") f))
(defun rec:ws (f x1 y1 x2 y2)
  (write-line (strcat "  (" (rtos x1 2 3) " " (rtos y1 2 3) " "
    (rtos x2 2 3) " " (rtos y2 2 3) ")") f))

(defun c:EXTRECACU (/ f ss i ed p)
  (setq f (open "C:/Users/jdbus/Documents/URBANISMO/work/record2/rec_acu_nodes.lsp" "w"))
  (write-line "(setq rec:acu-nodes '(" f)
  (setq ss (ssget "_X" '((0 . "INSERT") (8 . "V-NODE-ACU"))) i 0)
  (while (and ss (< i (sslength ss)))
    (setq ed (entget (ssname ss i)) p (cdr (assoc 10 ed)))
    (rec:wp f (car p) (cadr p))
    (setq i (1+ i)))
  (write-line "))" f)
  (write-line "(princ (strcat \"\nacu-nodes: \" (itoa (length rec:acu-nodes))))(princ)" f)
  (close f) (princ))

(defun rec:emit-poly (f ed / pts g prev)
  (setq pts nil)
  (foreach g ed (if (= 10 (car g)) (setq pts (cons (cdr g) pts))))
  (setq pts (reverse pts) prev nil)
  (foreach p pts
    (if prev (rec:ws f (car prev) (cadr prev) (car p) (cadr p)))
    (setq prev p)))

(defun rec:emit-mline (f ed / pts g prev)
  (setq pts nil)
  (foreach g ed (if (= 11 (car g)) (setq pts (cons (cdr g) pts))))
  (setq pts (reverse pts) prev nil)
  (foreach p pts
    (if prev (rec:ws f (car prev) (cadr prev) (car p) (cadr p)))
    (setq prev p)))

(defun c:EXTRECPLU (/ f ss i ed ty p q a0 a1 r c)
  (setq f (open "C:/Users/jdbus/Documents/URBANISMO/work/record2/rec_plu_data.lsp" "w"))
  ;; tuberia ejecutada
  (write-line "(setq rec:plu-segs '(" f)
  (setq ss (ssget "_X" '((8 . "LLUVIAS-RECIEN-CONST"))) i 0)
  (while (and ss (< i (sslength ss)))
    (setq ed (entget (ssname ss i)) ty (cdr (assoc 0 ed)))
    (cond
      ((= ty "LINE")
        (setq p (cdr (assoc 10 ed)) q (cdr (assoc 11 ed)))
        (rec:ws f (car p) (cadr p) (car q) (cadr q)))
      ((= ty "LWPOLYLINE") (rec:emit-poly f ed))
      ((= ty "MLINE") (rec:emit-mline f ed))
      ((= ty "ARC")
        (setq c (cdr (assoc 10 ed)) r (cdr (assoc 40 ed))
              a0 (cdr (assoc 50 ed)) a1 (cdr (assoc 51 ed)))
        (rec:ws f (+ (car c) (* r (cos a0))) (+ (cadr c) (* r (sin a0)))
                  (+ (car c) (* r (cos a1))) (+ (cadr c) (* r (sin a1))))))
    (setq i (1+ i)))
  (write-line "))" f)
  ;; pozos lluvias recien construidos
  (write-line "(setq rec:plu-pozos '(" f)
  (setq ss (ssget "_X" '((0 . "INSERT") (2 . "PZ_LLUV_RC"))) i 0)
  (while (and ss (< i (sslength ss)))
    (setq ed (entget (ssname ss i)) p (cdr (assoc 10 ed)))
    (rec:wp f (car p) (cadr p))
    (setq i (1+ i)))
  (write-line "))" f)
  ;; sumideros recien construidos (puntos medios de sus lineas)
  (write-line "(setq rec:plu-sumid '(" f)
  (setq ss (ssget "_X" '((0 . "LINE") (8 . "SUMIDERO RECIEN CONSTRUIDO"))) i 0)
  (while (and ss (< i (sslength ss)))
    (setq ed (entget (ssname ss i)) p (cdr (assoc 10 ed)) q (cdr (assoc 11 ed)))
    (rec:wp f (/ (+ (car p) (car q)) 2.0) (/ (+ (cadr p) (cadr q)) 2.0))
    (setq i (1+ i)))
  (write-line "))" f)
  (write-line "(princ (strcat \"\nplu segs/pozos/sumid: \" (itoa (length rec:plu-segs)) \"/\" (itoa (length rec:plu-pozos)) \"/\" (itoa (length rec:plu-sumid))))(princ)" f)
  (close f) (princ))
(princ "\nEXTRECACU / EXTRECPLU listos")(princ)
