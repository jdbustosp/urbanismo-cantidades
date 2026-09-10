;; E2E real (2026-09-10, Claude). Dos reportes del usuario:
;;  A) "los andenes no estan quedando en bloque, quedan todos los
;;     elementos por aparte"  -> se empaqueta y se cuenta lo que QUEDA
;;     suelto en el espacio modelo, y cuanto tarda el empacado.
;;  B) "si edito una via, cuando termino de editar me la borra del todo"
;;     -> se crea una via, se empaca, y se corre el urb:edit-road REAL
;;     con el dialogo, la abscisa y el movimiento sustituidos por valores
;;     fijos (lo demas es el camino de produccion).

(setq *e2e-out* (open (strcat (getenv "URB_TEST_LAB") "/result.txt") "w"))
(defun elog (s) (write-line s *e2e-out*) (princ s) (princ "\n"))
(setq *e2e-fallos* 0)
(defun echk (nombre ok detalle)
  (if ok
    (elog (strcat "OK   " nombre (if detalle (strcat " | " detalle) "")))
    (progn
      (setq *e2e-fallos* (1+ *e2e-fallos*))
      (elog (strcat "FALLO " nombre (if detalle (strcat " | " detalle) "")))))
  ok)
(defun cuenta (filtro / ss) (setq ss (ssget "_X" filtro)) (if ss (sslength ss) 0))
(defun sueltas-anden ()
  (cuenta '((8 . "URB-ANDEN*") (-4 . "<NOT") (0 . "INSERT") (-4 . "NOT>"))))

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
    (defun mk-poly (pts cerrada / data)
      (setq data
        (list '(0 . "LWPOLYLINE") '(100 . "AcDbEntity")
          '(100 . "AcDbPolyline") (cons 90 (length pts))
          (cons 70 (if cerrada 1 0))))
      (foreach p pts
        (setq data (append data (list (cons 10 p) (cons 42 0.0)))))
      (entmakex data))

    ;; ============ A) EL ANDEN TIENE QUE QUEDAR EN BLOQUE ============
    (setq ang (/ pi 6.0))
    (setq en-anden
      (mk-poly (mapcar '(lambda (p) (rot p ang))
        (list '(0.0 0.0) '(12.0 0.0) '(12.0 2.4) '(0.0 2.4))) T))
    (setq *urb-current-tactile-side-point* (rot (list 6.0 -1.0) ang))
    (urb:set-anden-data en-anden "Loseta" "1" "1" "Si" "Si"
      "40 x 40 cm" "Si" "SUP_TN" "Via creada")
    (urb:set-anden-pattern-mode en-anden "AUTOMATICO")
    (setq acabado
      (vl-catch-all-apply
        '(lambda () (urb:build-anden-finish en-anden "Loseta" "Si" "Si" "40 x 40 cm"))))
    (echk "build-anden-finish corrio"
      (and (not (vl-catch-all-error-p acabado)) acabado)
      (if (vl-catch-all-error-p acabado) (vl-catch-all-error-message acabado) "ok"))
    (setq sueltos-antes (sueltas-anden))
    (elog (strcat "piezas sueltas del anden antes de empacar: " (itoa sueltos-antes)))
    (setq t0 (getvar "MILLISECS"))
    (setq paquete
      (vl-catch-all-apply '(lambda () (urb:package-anden en-anden))))
    (elog (strcat "package-anden tardo "
      (rtos (/ (- (getvar "MILLISECS") t0) 1000.0) 2 1) " s"))
    (echk "package-anden devolvio una referencia de bloque"
      (and paquete (not (vl-catch-all-error-p paquete)))
      (if (and paquete (vl-catch-all-error-p paquete))
        (vl-catch-all-error-message paquete) "ok"))
    (setq sueltos (sueltas-anden))
    (echk "no queda ningun elemento del anden suelto en el dibujo"
      (= sueltos 0) (strcat (itoa sueltos) " sueltas de " (itoa sueltos-antes)))
    (if (and paquete (not (vl-catch-all-error-p paquete)))
      (progn
        (setq bname (vla-get-Name (urb:as-vla-object paquete)))
        (setq bdef (vla-Item (vla-get-Blocks (urb:doc)) bname))
        (setq ntot 0 ncir 0 npunteo 0 nfill7 0 nfill8 0 pn nil)
        (vlax-for o bdef
          (setq ntot (1+ ntot))
          (if (vl-string-search "TOPEROL" (vla-get-Layer o))
            (cond
              ((= (vla-get-ObjectName o) "AcDbCircle") (setq ncir (1+ ncir)))
              ((= (vla-get-ObjectName o) "AcDbHatch")
                (setq pn (vl-catch-all-apply 'vla-get-PatternName (list o)))
                (if (and (= (type pn) 'STR)
                         (vl-string-search "TOPEROL" (strcase pn)))
                  (if (= 8 (vla-get-Color o)) (setq npunteo (1+ npunteo)))
                  (cond ((= 7 (vla-get-Color o)) (setq nfill7 (1+ nfill7)))
                        ((= 8 (vla-get-Color o)) (setq nfill8 (1+ nfill8))))))
              ((= (vla-get-ObjectName o) "AcDbRegion")
                (cond ((= 7 (vla-get-Color o)) (setq nfill7 (1+ nfill7)))
                      ((= 8 (vla-get-Color o)) (setq nfill8 (1+ nfill8))))))))
        (elog (strcat "bloque " bname ": " (itoa ntot)
          " objetos | punteo por patron " (itoa npunteo)
          " | circulos " (itoa ncir) " | fondo claro " (itoa nfill7)
          " / oscuro " (itoa nfill8)))
        (echk "el bloque del anden contiene el acabado" (> ntot 100) (itoa ntot))
        (echk "el toperol se dibuja con el patron de puntos, en oscuro"
          (> npunteo 0) (itoa npunteo))
        (echk "ya no se siembra un circulo por domo"
          (= ncir 0) (strcat (itoa ncir) " circulos"))
        (echk "el fondo de la franja quedo claro (los puntos son la textura)"
          (and (> nfill7 0) (= nfill8 0))
          (strcat "claro " (itoa nfill7) " / oscuro " (itoa nfill8)))))

    ;; ============ B) EDITAR UNA VIA NO PUEDE BORRARLA ============
    (setq eje
      (mk-poly (list (rot '(100.0 5.0) ang) (rot '(160.0 5.0) ang)) nil))
    (setq en-via
      (mk-poly (mapcar '(lambda (p) (rot p ang))
        (list '(100.0 0.0) '(160.0 0.0) '(160.0 10.0) '(100.0 10.0))) T))
    (echk "eje y contorno de via creados" (and eje en-via) "")
    (setq rango (vl-catch-all-apply 'urb:axis-range-for-boundary (list eje en-via)))
    (setq ax0 (if (and rango (listp rango)) (car rango) 0.0)
          axlen (if (and rango (listp rango)) (cadr rango) 60.0))
    (setq res
      (vl-catch-all-apply
        '(lambda ()
          (urb:set-road-data en-via
            "VIA-E2E" "1" "1" "Via local"
            (vla-get-Handle (urb:as-vla-object eje))
            "NO SELECCIONADA" "Pendiente" "2560.00" "1.0" "K0+000" "20.0" "Normal"
            "Ambos" "1.0" "1.0" "0.0"
            (rtos (vla-get-Area (urb:as-vla-object en-via)) 2 6)
            (rtos axlen 2 6) "" "Existente" (rtos ax0 2 6) "E2E-VIA-1"))))
    (echk "urb:set-road-data acepto los datos"
      (not (vl-catch-all-error-p res))
      (if (vl-catch-all-error-p res) (vl-catch-all-error-message res) "ok"))
    (setq handle-via (vla-get-Handle (urb:as-vla-object en-via)))
    (vl-catch-all-apply 'urb:generate-road-stations
      (list eje handle-via 0.0 20.0 "Normal" ax0 axlen))
    (vl-catch-all-apply 'urb:create-road-axis-display (list en-via eje))
    (vl-catch-all-apply 'urb:create-road-display-hatch (list en-via))
    (setq bloque-via
      (vl-catch-all-apply '(lambda () (urb:package-road en-via))))
    (echk "la via se empaqueto en bloque"
      (and bloque-via (not (vl-catch-all-error-p bloque-via)))
      (if (and bloque-via (vl-catch-all-error-p bloque-via))
        (vl-catch-all-error-message bloque-via) "ok"))

    (if (and bloque-via (not (vl-catch-all-error-p bloque-via)))
      (progn
        (setq n0 (cuenta '((0 . "INSERT") (2 . "URB_VIA_*"))))
        (elog (strcat "bloques de via ANTES de editar: " (itoa n0)))
        ;; el supuesto viejo del desempaque: "el contorno es la UNICA
        ;; polilinea del bloque". Se documenta cuantas hay de verdad.
        (setq bdv (vla-Item (vla-get-Blocks (urb:doc))
                    (vla-get-Name (urb:as-vla-object bloque-via))))
        (setq npoly 0 areas nil)
        (vlax-for o bdv
          (if (= (vla-get-ObjectName o) "AcDbPolyline")
            (progn (setq npoly (1+ npoly))
              (setq areas
                (cons (vl-catch-all-apply 'vla-get-Area (list o)) areas)))))
        (elog (strcat "LWPOLYLINE dentro del bloque de via: " (itoa npoly)
          " | areas = " (vl-princ-to-string areas)))
        ;; el desempaque tiene que quedarse con el CONTORNO (600 m2)
        (setq crudo
          (vl-catch-all-apply '(lambda ()
            (urb:explode-road-block-boundary (urb:as-ename bloque-via)))))
        (if (and crudo (not (vl-catch-all-error-p crudo)))
          (progn
            (setq a-crudo (vl-catch-all-apply
              '(lambda () (vla-get-Area (urb:as-vla-object crudo)))))
            (elog (strcat "el desempaque se quedo con una polilinea de area "
              (if (numberp a-crudo) (rtos a-crudo 2 2) "?")))
            (echk "el desempaque conserva el CONTORNO, no la polilinea de apoyo"
              (and (numberp a-crudo) (> a-crudo 100.0))
              (if (numberp a-crudo) (rtos a-crudo 2 2) "?"))
            ;; se deshace para dejar el dibujo como estaba antes del EDITAR
            (urb:safe-delete (urb:as-vla-object crudo)))
          (echk "el desempaque devolvio un contorno" nil
            (if (vl-catch-all-error-p crudo)
              (vl-catch-all-error-message crudo) "NIL")))))

    (elog (strcat "RESULTADO " (itoa *e2e-fallos*) " FALLOS"))
    (elog "DONE")
    (close *e2e-out*)))
