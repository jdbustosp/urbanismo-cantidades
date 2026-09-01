;;; SNAPACU (2026-09-01): conecta la tuberia ACU a sus accesorios.
;;; Por cada tramo ACU mide la distancia de cada extremo al accesorio
;;; mas cercano (<3.5 m): si algun extremo esta a >0.05 del centro del
;;; accesorio, RECONSTRUYE el tramo de centro a centro (los tramos del
;;; plano venian con la linea partida alrededor del simbolo o pasada de
;;; largo). Conserva TODOS los atributos; LONGITUD queda geometrica
;;; real. Reporta histograma. Recolectar->mutar.
(defun sa:log (msg)
  (if *sa-f* (write-line msg *sa-f*))
  (princ (strcat "\n" msg)) (princ))
(defun c:SNAPACU (/ ss i en atts tr accs item best1 bd1 best2 bd2 p1 p2
                    n-ok n-snap n-far ents d rot lst en2)
  (setq *sa-f* (open "C:/Users/jdbus/Documents/URBANISMO/work/etapas/snapacu.txt" "w"))
  ;; accesorios (centros)
  (setq accs nil)
  (setq ss (ssget "_X" (list (cons 0 "INSERT") (cons 2 "MP_PUNTO_ACC_ACU*"))) i 0)
  (if ss
    (while (< i (sslength ss))
      (setq en (ssname ss i))
      (setq accs (cons (cdr (assoc 10 (entget en))) accs))
      (setq i (1+ i))))
  (sa:log (strcat "accesorios: " (itoa (length accs))))
  ;; tramos
  (setq ss (ssget "_X" (list (cons 0 "INSERT") (cons 2 "MP_TRAMO_ACU_*"))) i 0 ents nil)
  (if ss (while (< i (sslength ss)) (setq ents (cons (ssname ss i) ents)) (setq i (1+ i))))
  (setq n-ok 0 n-snap 0 n-far 0)
  (foreach en ents
    (setq atts (mp:att-alist en))
    (setq tr (cr:tramo-ends en))
    (setq p1 (list (nth 0 tr) (nth 1 tr)) p2 (list (nth 2 tr) (nth 3 tr)))
    (setq best1 nil bd1 1e9 best2 nil bd2 1e9)
    (foreach item accs
      (setq d (distance (list (car item) (cadr item)) p1))
      (if (< d bd1) (setq bd1 d best1 item))
      (setq d (distance (list (car item) (cadr item)) p2))
      (if (< d bd2) (setq bd2 d best2 item)))
    ;; snap solo si hay accesorio cerca y no esta clavado
    (setq lst nil)
    (if (and best1 (< bd1 3.5) (> bd1 0.05))
      (setq p1 (list (car best1) (cadr best1)) lst T))
    (if (and best2 (< bd2 3.5) (> bd2 0.05))
      (setq p2 (list (car best2) (cadr best2)) lst T))
    (cond
      (lst
        ;; reconstruir con atributos preservados
        (setq atts (vl-remove-if
          (quote (lambda (a) (member (car a)
            (list "LONGITUD" "LONGITUD_2D" "LONGITUD_3D" "ETIQUETA"
                  "HANDLE_EXTREMO_INI" "HANDLE_EXTREMO_FIN"))))
          atts))
        (setq en2 (mp:insert-cant-tramo "TRAMO_ACUEDUCTO" p1 p2 atts))
        (if en2
          (progn
            (entdel en)
            ;; etiqueta formato plano + horizontal
            (setq atts (mp:att-alist en2))
            (mp:setatts en2 (list (cons "ETIQUETA"
              (mp:label-tramo "TRAMO_ACUEDUCTO" atts))))
            (foreach a (vlax-invoke (vlax-ename->vla-object en2) (quote GetAttributes))
              (if (= "ETIQUETA" (strcase (vla-get-TagString a)))
                (vl-catch-all-apply (quote vla-put-Rotation) (list a 0.0))))
            (setq n-snap (1+ n-snap)))
          (setq n-far (1+ n-far))))
      ((or (and best1 (>= bd1 3.5)) (and best2 (>= bd2 3.5)))
        (setq n-far (1+ n-far)))
      (T (setq n-ok (1+ n-ok)))))
  (sa:log (strcat "SNAPACU: " (itoa n-ok) " ya conectados | "
    (itoa n-snap) " RECONECTADOS | " (itoa n-far)
    " con extremo sin accesorio cerca (union tramo-tramo, ok)"))
  (sa:log "FIN-SNAPACU")
  (close *sa-f*) (setq *sa-f* nil)
  (princ))
(princ "\nSNAPACU listo")(princ)
