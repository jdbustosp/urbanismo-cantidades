;; APLICAR CIRCUITOS (2026-08-26): marca los tramos MT multi-circuito
;; detectados por fix_mt2 (lista handle/circuitos en fix_mt2_log.txt)
;; con el dato CIRCUITOS. Se guarda via mp:setatt-one, que ademas de los
;; atributos escribe la copia XDATA que el presupuesto lee (att-alist),
;; asi que funciona aunque el bloque viejo no tenga el ATTDEF.
(vl-load-com)
(defun ac:log (m / f)
  (setq f (open "C:/Users/jdbus/Documents/URBANISMO/work/lote_redes/aplicar_circuitos_log.txt" "a"))
  (if f (progn (write-line m f) (close f)))
  (princ (strcat "\n" m)))

(defun c:APLICARCIRC (/ f lin h circ ok fail en r chk)
  (setq f (open "C:/Users/jdbus/Documents/URBANISMO/work/lote_redes/fix_mt2_log.txt" "r"))
  (setq ok 0 fail 0)
  (while (setq lin (read-line f))
    (if (wcmatch lin "  h=*circuitos=*")
      (progn
        ;; "  h=5FEB7 L=29.0 circuitos=2"
        (setq h (substr lin 5 (- (vl-string-search " " lin 4) 4)))
        (setq circ (substr lin (+ 11 (vl-string-search "circuitos=" lin))))
        (setq en (handent h))
        (if en
          (progn
            (setq r (vl-catch-all-apply 'mp:setatt-one
              (list en "CIRCUITOS" circ)))
            (if (vl-catch-all-error-p r)
              (progn (setq fail (1+ fail))
                (ac:log (strcat "ERROR h=" h ": " (vl-catch-all-error-message r))))
              (setq ok (1+ ok))))
          (progn (setq fail (1+ fail))
            (ac:log (strcat "ERROR handle no existe: " h)))))))
  (close f)
  (ac:log (strcat "CIRCUITOS aplicados: " (itoa ok) " | errores: " (itoa fail)))
  ;; verificacion: releer 2 muestras via att-alist (mezcla attrib+XDATA)
  (setq f (open "C:/Users/jdbus/Documents/URBANISMO/work/lote_redes/fix_mt2_log.txt" "r"))
  (setq chk 0)
  (while (and (setq lin (read-line f)) (< chk 2))
    (if (wcmatch lin "  h=*circuitos=*")
      (progn
        (setq h (substr lin 5 (- (vl-string-search " " lin 4) 4)))
        (setq en (handent h))
        (if en
          (progn
            (setq chk (1+ chk))
            (ac:log (strcat "VERIF h=" h " CIRCUITOS(att-alist)="
              (if (cdr (assoc "CIRCUITOS" (mp:att-alist en)))
                (cdr (assoc "CIRCUITOS" (mp:att-alist en))) "NO LEIDO"))))))))
  (close f)
  (ac:log "APLICARCIRC-TERMINADO")
  (princ))
(c:APLICARCIRC)
