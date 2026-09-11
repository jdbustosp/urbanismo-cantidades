;; E2E real (2026-09-11, Claude): el movimiento de tierras por cotas tiene que
;; medir contra la SUBRASANTE (terminado - estructura), no contra el
;; terminado. Terreno plano simulado para que el resultado sea verificable a
;; mano.

(setq *e2e-out* (open (strcat (getenv "URB_TEST_LAB") "/mt.txt") "w"))
(defun elog (s) (write-line s *e2e-out*) (princ s) (princ "\n"))
(setq *e2e-fallos* 0)
(defun echk (nombre ok detalle)
  (if ok
    (elog (strcat "OK   " nombre (if detalle (strcat " | " detalle) "")))
    (progn
      (setq *e2e-fallos* (1+ *e2e-fallos*))
      (elog (strcat "FALLO " nombre (if detalle (strcat " | " detalle) "")))))
  ok)

(setq *e2e-err*
  (vl-catch-all-apply
    '(lambda () (load (strcat (getenv "URB_REPO") "/urbanismo_cantidades.lsp")))))

(if (vl-catch-all-error-p *e2e-err*)
  (progn
    (elog (strcat "ERROR-CARGA " (vl-catch-all-error-message *e2e-err*)))
    (elog "DONE") (close *e2e-out*))
  (progn
    (elog (strcat "motor " *urb-version* " cargado"))
    ;; terreno PLANO a cota 2560.00 (sustituye la superficie SUP_TN)
    (defun mp:current-terrain-surface () 'TERRENO-PLANO)
    (defun urb:surface-elevation (s x y) 2560.0)
    (defun mk-poly (pts / data)
      (setq data (list '(0 . "LWPOLYLINE") '(100 . "AcDbEntity")
        '(100 . "AcDbPolyline") (cons 90 (length pts)) '(70 . 1)))
      (foreach p pts (setq data (append data (list (cons 10 p) (cons 42 0.0)))))
      (entmakex data))
    (setq en (mk-poly (list '(0.0 0.0) '(10.0 0.0) '(10.0 2.0) '(0.0 2.0))))
    (setq area (vla-get-Area (vlax-ename->vla-object en)))
    (elog (strcat "anden de prueba: " (rtos area 2 2) " m2 | estructura "
      (rtos *urb-anden-depth* 2 2) " m"))

    ;; --- caso 1: terminado A NIVEL del terreno ---
    ;; hay que excavar la caja de la estructura: 20 x 0,60 = 12 m3 de corte
    (setq m1 (urb:earthworks-from-picks en (list (list 2560.0 (list 0.0 0.0)))
               *urb-anden-depth*))
    (elog (strcat "a nivel: corte " (rtos (car m1) 2 3) " | relleno " (rtos (cadr m1) 2 3)))
    (echk "a nivel del terreno igual se excava la caja de la estructura"
      (< (abs (- (car m1) (* area *urb-anden-depth*))) 0.05)
      (strcat (rtos (car m1) 2 3) " esperado " (rtos (* area *urb-anden-depth*) 2 3)))
    (echk "y no aparece relleno de tierra" (< (cadr m1) 0.01) (rtos (cadr m1) 2 3))

    ;; --- caso 2: terminado 1,00 m POR ENCIMA del terreno ---
    ;; subrasante = +0,40 -> relleno de tierra 20 x 0,40 = 8 m3 (los otros
    ;; 0,60 son estructura granular, que se cuenta aparte)
    (setq m2 (urb:earthworks-from-picks en (list (list 2561.0 (list 0.0 0.0)))
               *urb-anden-depth*))
    (elog (strcat "+1,00: corte " (rtos (car m2) 2 3) " | relleno " (rtos (cadr m2) 2 3)))
    (echk "el relleno de tierra llega solo hasta la subrasante (8 m3, no 20)"
      (< (abs (- (cadr m2) (* area (- 1.0 *urb-anden-depth*)))) 0.05)
      (strcat (rtos (cadr m2) 2 3) " esperado " (rtos (* area (- 1.0 *urb-anden-depth*)) 2 3)))
    (echk "y no aparece corte" (< (car m2) 0.01) (rtos (car m2) 2 3))

    ;; --- caso 3: zona verde con 0,20 de tierra negra, a nivel ---
    (setq m3 (urb:earthworks-from-picks en (list (list 2560.0 (list 0.0 0.0))) 0.20))
    (elog (strcat "zona verde a nivel: corte " (rtos (car m3) 2 3)))
    (echk "la zona verde excava el espesor de su tierra negra (20 x 0,20 = 4 m3)"
      (< (abs (- (car m3) (* area 0.20))) 0.05) (rtos (car m3) 2 3))

    ;; --- lo que daba ANTES (sin descontar estructura) ---
    (setq m0 (urb:earthworks-from-picks en (list (list 2560.0 (list 0.0 0.0))) 0.0))
    (elog (strcat "referencia SIN estructura (calculo anterior): corte "
      (rtos (car m0) 2 3) " | relleno " (rtos (cadr m0) 2 3)))

    (elog (strcat "RESULTADO " (itoa *e2e-fallos*) " FALLOS"))
    (elog "DONE")
    (close *e2e-out*)))
