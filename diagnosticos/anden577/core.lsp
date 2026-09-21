(vl-load-com)
(setq c577:dir
  "C:/Users/juanbusper/Documents/URBANISMO/work/anden577_20260921")
(setq c577:out (strcat c577:dir "/core577.txt")
      c577:ok 0 c577:fail 0)

(defun c577:log (text / stream)
  (setq stream (open c577:out "a"))
  (write-line text stream)
  (close stream))

(defun c577:check (condition label)
  (if condition
    (progn (setq c577:ok (1+ c577:ok)) (c577:log (strcat "PASS " label)))
    (progn (setq c577:fail (1+ c577:fail)) (c577:log (strcat "FAIL " label)))))

(defun c577:flat-y (points value tolerance / ok point)
  (setq ok T)
  (foreach point points
    (if (> (abs (- (cadr point) value)) tolerance) (setq ok nil)))
  ok)

(defun c577:keep-layer (name x / layer line)
  (setq layer (urb:ensure-layer name 2 T))
  (vla-put-Freeze layer :vlax-false)
  (setq line
    (vla-AddLine (urb:model-space)
      (vlax-3d-point (list x 0.0 0.0))
      (vlax-3d-point (list x 0.1 0.0))))
  (vla-put-Layer line name)
  line)

(defun c577:run (/ ring click anchor without-anchor chosen)
  (c577:log (strcat "VERSION " *urb-version*))
  (c577:check (= *urb-version* "5.7.7") "engine version")
  (setq ring '((0.0 0.0) (100.0 0.0) (100.0 4.0)
               (50.0 4.0) (0.0 4.0))
        click '(50.0 -2.0 0.0)
        anchor (urb:tactile-side-anchor ring '(50.0 9.0 0.0)))
  (c577:check (and anchor (< (abs (- (car anchor) 50.0)) 1e-9)
                              (< (abs (- (cadr anchor) 4.0)) 1e-9))
    "click projects to exact selected boundary")
  ;; Control que reproduce la decision anterior: sin ancla gana el costado
  ;; inferior por el clic. Con el ancla guardada debe sobrevivir el superior.
  (setq *urb-current-tactile-side-choice* nil
        *urb-current-tactile-side-point* click
        *urb-current-tactile-side-anchor* nil
        without-anchor (urb:anden-tactile-chain ring))
  (c577:check (c577:flat-y without-anchor 0.0 1e-9)
    "control without anchor reproduces wrong later side")
  (setq *urb-current-tactile-side-anchor* anchor
        chosen (urb:anden-tactile-chain ring))
  (c577:check (c577:flat-y chosen 4.0 1e-9)
    "stored boundary anchor preserves selected side")

  (urb:prepare-anden-layers)
  (urb:light-mode-set nil)
  (c577:check (= (urb:light-mode-state) "APAGADO")
    "tactile layers begin visible")
  (urb:purge-command)
  (c577:check (= (urb:light-mode-state) "APAGADO")
    "PURGE does not hide guide or toperol")
  (urb:light-mode-set T)
  (c577:check (= (urb:light-mode-state) "ACTIVO")
    "explicit fluid mode freezes all tactile layers")
  (urb:light-mode-set nil)
  (c577:check (= (urb:light-mode-state) "APAGADO")
    "explicit fluid mode restores all tactile layers")
  (c577:log (strcat "SUMMARY ok=" (itoa c577:ok) " fail=" (itoa c577:fail))))

(if (findfile c577:out) (vl-file-delete c577:out))
(setq c577:result (vl-catch-all-apply 'c577:run nil))
(if (vl-catch-all-error-p c577:result)
  (c577:log (strcat "ERROR " (vl-catch-all-error-message c577:result))))
(princ)
