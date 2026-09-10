;; E2E real v4.88.0 (Claude, 2026-09-10):
;;  A) urb:anden-block-points saca el contorno de un anden YA empacado
;;     (es lo que permite rehacer el MT desde EDITAR sin reconstruirlo).
;;  B) la altura de bordillo por defecto y la cota de diseno sobre via.

(setq *e2e-out* (open (strcat (getenv "URB_TEST_LAB") "/r4880.txt") "w"))
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
    (defun rot (p a / c s) (setq c (cos a) s (sin a))
      (list (- (* (car p) c) (* (cadr p) s))
            (+ (* (car p) s) (* (cadr p) c))))
    (defun mk-poly (pts / data)
      (setq data
        (list '(0 . "LWPOLYLINE") '(100 . "AcDbEntity")
          '(100 . "AcDbPolyline") (cons 90 (length pts)) '(70 . 1)))
      (foreach p pts (setq data (append data (list (cons 10 p) (cons 42 0.0)))))
      (entmakex data))

    ;; ---------- B) altura de bordillo ----------
    (setq alto (vl-catch-all-apply 'urb:prefab-default-alto (list "Bordillo")))
    (elog (strcat "altura de bordillo por defecto = "
      (if (numberp alto) (rtos alto 2 3) (vl-princ-to-string alto))))
    (echk "urb:prefab-default-alto responde con la altura de Ajustes"
      (and (numberp alto) (> alto 0.0) (< alto 1.0))
      (if (numberp alto) (rtos alto 2 3) "?"))
    (echk "por defecto son los 0,20 m del bordillo A-80"
      (and (numberp alto) (< (abs (- alto 0.20)) 1e-6))
      (if (numberp alto) (rtos alto 2 3) "?"))

    ;; ---------- A) contorno de un anden ya empacado ----------
    (setq ang (/ pi 6.0))
    (setq en-anden
      (mk-poly (mapcar '(lambda (p) (rot p ang))
        (list '(0.0 0.0) '(12.0 0.0) '(12.0 2.4) '(0.0 2.4)))))
    (setq area0 (vla-get-Area (urb:as-vla-object en-anden)))
    (setq *urb-current-tactile-side-point* (rot (list 6.0 -1.0) ang))
    (urb:set-anden-data en-anden "Loseta" "1" "1" "No" "Si"
      "40 x 40 cm" "Si" "SUP_TN" "Via creada")
    (urb:set-anden-pattern-mode en-anden "AUTOMATICO")
    (setq acabado
      (vl-catch-all-apply
        '(lambda () (urb:build-anden-finish en-anden "Loseta" "No" "Si" "40 x 40 cm"))))
    (echk "build-anden-finish corrio"
      (and (not (vl-catch-all-error-p acabado)) acabado)
      (if (vl-catch-all-error-p acabado) (vl-catch-all-error-message acabado) "ok"))
    (setq paquete (vl-catch-all-apply '(lambda () (urb:package-anden en-anden))))
    (echk "el anden quedo empacado"
      (and paquete (not (vl-catch-all-error-p paquete)))
      (if (and paquete (vl-catch-all-error-p paquete))
        (vl-catch-all-error-message paquete) "ok"))
    (if (and paquete (not (vl-catch-all-error-p paquete)))
      (progn
        (setq pts (vl-catch-all-apply 'urb:anden-block-points
                    (list (urb:as-ename paquete))))
        (elog (strcat "urb:anden-block-points devolvio "
          (if (vl-catch-all-error-p pts) (vl-catch-all-error-message pts)
            (if pts (strcat (itoa (length pts)) " puntos") "NIL"))))
        (echk "se recupera el contorno sin desempacar el bloque"
          (and (not (vl-catch-all-error-p pts)) pts (= 4 (length pts)))
          (if (and (not (vl-catch-all-error-p pts)) pts)
            (itoa (length pts)) "NIL"))
        ;; y tiene que ser el contorno de verdad: mismo area que el original
        (setq area1
          (vl-catch-all-apply
            '(lambda ( / ctrl a)
              (setq ctrl
                (mk-poly (mapcar '(lambda (p) (list (car p) (cadr p))) pts)))
              (setq a (vla-get-Area (urb:as-vla-object ctrl)))
              (entdel ctrl)
              a)))
        (elog (strcat "area original " (rtos area0 2 3) " | area recuperada "
          (if (numberp area1) (rtos area1 2 3)
            (vl-catch-all-error-message area1))))
        (echk "el contorno recuperado es el del anden, no otra pieza"
          (and (numberp area1) (< (abs (- area0 area1)) 0.05))
          (if (numberp area1) (rtos area1 2 3) "?"))))

    (elog (strcat "RESULTADO " (itoa *e2e-fallos*) " FALLOS"))
    (elog "DONE")
    (close *e2e-out*)))
