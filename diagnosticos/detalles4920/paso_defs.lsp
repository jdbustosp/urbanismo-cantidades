;; Vuelca la DEFINICION de cada bloque de rampa peatonal del plano (no estan
;; insertados en el modelo). Una ventana por bloque, en coordenadas del bloque.
(setq lab (getenv "URB_TEST_LAB"))
(setq *o* (open (strcat lab "/paso_defs.txt") "w"))
(load (strcat lab "/dumpx.lsp"))
(setvar "CMDECHO" 0)
(setq k 0 tb (tblnext "BLOCK" T))
(while tb
  (setq nm (cdr (assoc 2 tb)))
  (if (and (wcmatch (strcase nm) "*RAMPA*,*M?DULO*")
           (not (wcmatch (strcase nm) "*VEHICULAR*"))
           (/= (substr nm 1 1) "*"))
    (progn
      (setq k (1+ k))
      (w (strcat "W def" (itoa k) " 0 0 1 1"))
      (w (strcat "N " nm))
      (dump-block nm (mx-id) nil 0)
      (w (strcat "E def" (itoa k) " 0"))))
  (setq tb (tblnext "BLOCK")))
(w "DONE")
(close *o*)
(setq *m* (open (strcat lab "/png_log.txt") "w"))
(write-line "DONE" *m*)
(close *m*)
