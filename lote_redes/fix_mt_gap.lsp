;; FIX GAP DOBLE MT (2026-08-26): reparar_mt_master.lsp (fase B2) fijo la
;; polilinea interna de cada def de tramo MT en x0=-1.0 / x1=(distv+1.0),
;; sumandose al gap=1.0 YA aplicado en la INSERCION por mp:insert-cant-
;; tramo -- resultado: 2.0 m de hueco real en cada extremo en vez de 1.0
;; (medido exacto en el master: GAP real inicio/fin = 2.000 m). Se
;; corrige a x0=0.0 / x1=distv (la convencion correcta que ya usa
;; fix_ap_defs.lsp para BT-AP, que nunca tuvo este bug).
(vl-load-com)
(defun fg:log (m / f)
  (setq f (open "C:/Users/jdbus/Documents/URBANISMO/work/lote_redes/fix_mt_gap_log.txt" "a"))
  (if f (progn (write-line m f) (close f)))
  (princ (strcat "\n" m)))

(defun c:FIXMTGAP (/ blks blk nb nombres par distv lin fixed malas
                   blkrec be bd pts x0 x1 p e)
  (setq blks (vla-get-Blocks (vla-get-ActiveDocument (vlax-get-acad-object))))
  ;; PASO 1: recolectar nombres+distv (sin mutar mientras se itera blks)
  (setq nombres nil)
  (vlax-for blk blks
    (setq nb (vla-get-Name blk))
    (if (wcmatch nb "MP_TRAMO_MT_*")
      (setq nombres
        (cons (list nb (atof (vl-string-translate "_" "."
          (substr nb (+ 4 (vl-string-search "MT_" nb))))))
          nombres))))
  (fg:log (strcat "Definiciones MP_TRAMO_MT_* encontradas: " (itoa (length nombres))))
  ;; PASO 2: mutar cada definicion, una a la vez
  (setq fixed 0 malas 0)
  (foreach par nombres
    (setq nb (car par) distv (cadr par))
    (setq blk (vla-Item blks nb))
    (vlax-for e blk
      (if (= (vla-get-ObjectName e) "AcDbPolyline")
        (progn
          (setq lin (entget (vlax-vla-object->ename e)))
          (setq lin (subst (cons 10 (list 0.0 0.0)) (assoc 10 lin) lin))
          (entmod
            (reverse
              (subst (cons 10 (list distv 0.0))
                (assoc 10 (reverse lin)) (reverse lin))))
          (setq fixed (1+ fixed))))))
  (fg:log (strcat "Definiciones corregidas (x0=0.0, x1=distv): " (itoa fixed)))
  ;; PASO 3: verificar TODAS
  (foreach par nombres
    (setq nb (car par) distv (cadr par))
    (setq blkrec (tblsearch "BLOCK" nb))
    (setq be (cdr (assoc -2 blkrec)) x0 nil x1 nil)
    (while be
      (setq bd (entget be))
      (if (= (cdr (assoc 0 bd)) "LWPOLYLINE")
        (progn
          (setq pts nil)
          (foreach p bd (if (= (car p) 10) (setq pts (cons (cadr p) pts))))
          (setq x0 (apply 'min pts) x1 (apply 'max pts))))
      (setq be (entnext be)))
    (if (or (null x0) (> (abs x0) 0.01) (> (abs (- x1 distv)) 0.01))
      (progn (setq malas (1+ malas))
        (fg:log (strcat "  SIGUE MAL: " nb " x0=" (if x0 (rtos x0 2 3) "?")
          " x1=" (if x1 (rtos x1 2 3) "?") " (esperado 0 / " (rtos distv 2 3) ")")))))
  (fg:log (strcat "VERIFICACION: " (itoa malas) " definiciones aun mal de " (itoa (length nombres))))
  (vla-Regen (vla-get-ActiveDocument (vlax-get-acad-object)) 1)
  (fg:log "FIXMTGAP-TERMINADO"))
(c:FIXMTGAP)
