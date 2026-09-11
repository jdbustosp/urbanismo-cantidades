;; E2E real (2026-09-11, Claude): "elegi 2565.25 pero me reconoce siempre la
;; cota de abajo, 2562.25". Se crea una etiqueta de DOS renglones rotada como
;; la de la foto y se simula el clic (lo que devuelve nentsel) arriba y abajo.

(setq *e2e-out* (open (strcat (getenv "URB_TEST_LAB") "/cota.txt") "w"))
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
    ;; nunca preguntar en el test: si cae al menu, se registra
    (defun urb:ask-which-cota (nums) (elog "  (cayo al menu)") 'MENU)

    (foreach caso (list (list "horizontal" 0.0) (list "rotada 60" (/ pi 3.0))
                        (list "rotada 120" (* 2.0 (/ pi 3.0))))
      (setq nombre (car caso) rot (cadr caso))
      ;; MTEXT de dos renglones con justificacion media-centro, altura 1.5
      (setq mt (vla-AddMText (urb:space) (vlax-3d-point '(100.0 100.0 0.0))
                 0.0 "2565.25\\P2562.25"))
      (vla-put-Height mt 1.5)
      (vla-put-AttachmentPoint mt acAttachmentPointMiddleCenter)
      (vla-put-InsertionPoint mt (vlax-3d-point '(100.0 100.0 0.0)))
      (vla-put-Rotation mt rot)
      (setq en (vlax-vla-object->ename mt))
      ;; "arriba" y "abajo" en el sistema del propio texto: +/- 0.8 m sobre
      ;; su eje hacia arriba (-sin, cos)
      (setq ux (- (sin rot)) uy (cos rot))
      (setq p-arriba (list (+ 100.0 (* 0.8 ux)) (+ 100.0 (* 0.8 uy)) 0.0))
      (setq p-abajo  (list (- 100.0 (* 0.8 ux)) (- 100.0 (* 0.8 uy)) 0.0))
      (setq v1 (urb:selected-cota-number (list en p-arriba)))
      (setq v2 (urb:selected-cota-number (list en p-abajo)))
      (elog (strcat nombre ": clic arriba -> " (vl-princ-to-string v1)
        " | clic abajo -> " (vl-princ-to-string v2)))
      (echk (strcat nombre ": clic sobre el renglon de ARRIBA da 2565.25")
        (and (numberp v1) (equal v1 2565.25 1e-6)) (vl-princ-to-string v1))
      (echk (strcat nombre ": clic sobre el renglon de ABAJO da 2562.25")
        (and (numberp v2) (equal v2 2562.25 1e-6)) (vl-princ-to-string v2))
      (vla-Delete mt))

    ;; y un texto de UNA sola cota sigue igual que siempre
    (setq mt (vla-AddMText (urb:space) (vlax-3d-point '(0.0 0.0 0.0)) 0.0 "2558.40"))
    (setq v (urb:selected-cota-number (list (vlax-vla-object->ename mt) '(0.0 0.0 0.0))))
    (echk "una etiqueta de una sola cota no cambia" (equal v 2558.40 1e-6)
      (vl-princ-to-string v))

    (elog (strcat "RESULTADO " (itoa *e2e-fallos*) " FALLOS"))
    (elog "DONE")
    (close *e2e-out*)))
