;; FIX GAP REAL MT v2 (2026-08-26): el gap de 2.0m NO viene de la
;; geometria interna del bloque (esa ya estaba bien, 0..distv) sino del
;; PUNTO DE INSERCION del tramo: los 220 tramos MT fueron insertados
;; AYER (LOTE REDES) con la formula VIEJA de mp:tramo-visual-gap (radio
;; generico 2.0m), y nunca se recrearon -- todo lo tocado hoy (fase B2,
;; fix_mt_gap v1) solo edito la definicion, no el INSERT. La UNICA forma
;; correcta de aplicar el gap NUEVO (1.0m) es recrear cada tramo con
;; mp:insert-cant-tramo (que ya tiene la formula correcta) usando los
;; puntos REALES de sus 2 nodos.
(vl-load-com)
(defun fg2:log (m / f)
  (setq f (open "C:/Users/jdbus/Documents/URBANISMO/work/lote_redes/fix_mt_gap2_log.txt" "a"))
  (if f (progn (write-line m f) (close f)))
  (princ (strcat "\n" m)))

(defun c:FIXMTGAP2 (/ nodos ss n i e atts idv pt tocados sinmatch pini pfin
                    p1 p2 vals r nb reconstruidos resu)
  ;; ---------- indexar TODOS los nodos MT posibles por ID
  (setq nodos nil)
  (foreach patron '("MP_PUNTO_CAMARA_CS276" "MP_PUNTO_CAMARA_CS280"
                     "MP_PUNTO_SUBESTACION_E" "MP_PUNTO_POSTE_ELEC")
    (setq ss (ssget "_X" (list '(0 . "INSERT") (cons 2 patron))))
    (setq n (if ss (sslength ss) 0) i 0)
    (while (< i n)
      (setq e (ssname ss i))
      (setq atts (mp:att-alist e))
      (setq idv (cdr (assoc "ID" atts)))
      (if idv (setq nodos (cons (cons idv (cdr (assoc 10 (entget e)))) nodos)))
      (setq i (1+ i))))
  (fg2:log (strcat "Nodos MT indexados (cajas+subestaciones+postes): " (itoa (length nodos))))
  ;; ---------- recorrer tramos: recolectar (handle vals p1 p2) primero
  (setq ss (ssget "_X" '((0 . "INSERT") (2 . "MP_TRAMO_MT_*"))))
  (setq n (if ss (sslength ss) 0) i 0 tocados nil sinmatch 0)
  (while (< i n)
    (setq e (ssname ss i))
    (setq atts (mp:att-alist e))
    (setq pini (cdr (assoc "POZO_INI" atts)) pfin (cdr (assoc "POZO_FIN" atts)))
    (if (and pini pfin (assoc pini nodos) (assoc pfin nodos))
      (setq tocados
        (cons (list e atts (cdr (assoc pini nodos)) (cdr (assoc pfin nodos))) tocados))
      (setq sinmatch (1+ sinmatch)))
    (setq i (1+ i)))
  (fg2:log (strcat "Tramos con ambos extremos identificados: " (itoa (length tocados))
    " | sin match (no se tocan): " (itoa sinmatch) " de " (itoa n)))
  ;; ---------- reconstruir: borrar + reinsertar con mp:insert-cant-tramo
  ;; (formula de gap actual, correcta) preservando TODOS los datos via vals
  (setq reconstruidos 0)
  (foreach r tocados
    (setq e (car r) vals (cadr r) p1 (caddr r) p2 (cadddr r))
    (entdel e)
    (setq resu
      (vl-catch-all-apply 'mp:insert-cant-tramo
        (list "TRAMO_E_MT"
          (list (car p1) (cadr p1) 0.0)
          (list (car p2) (cadr p2) 0.0)
          vals)))
    (if (vl-catch-all-error-p resu)
      (fg2:log (strcat "  ERROR reconstruyendo: " (vl-catch-all-error-message resu)))
      (setq reconstruidos (1+ reconstruidos))))
  (fg2:log (strcat "Tramos reconstruidos con gap correcto: " (itoa reconstruidos)))
  ;; ---------- purgar definiciones viejas huerfanas (ya sin instancias)
  (command "_.-PURGE" "_B" "MP_TRAMO_MT_*" "_N")
  (command "_.-PURGE" "_B" "MP_TRAMO_MT_*" "_N")
  (vla-Regen (vla-get-ActiveDocument (vlax-get-acad-object)) 1)
  (fg2:log "FIXMTGAP2-TERMINADO"))
(c:FIXMTGAP2)
