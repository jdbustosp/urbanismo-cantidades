(vl-load-com)

(setq c579:dir "C:/Users/juanbusper/Documents/URBANISMO/work/anden579_20260921"
      c579:out (strcat c579:dir "/census579.txt"))

(defun c579:log (text / f)
  (setq f (open c579:out "a"))
  (write-line text f)
  (close f))

(defun c579:bbox-text (ename / pts)
  (setq pts (urb:object-box-points (vlax-ename->vla-object ename)))
  (vl-princ-to-string pts))

(defun c579:scan-app (appid types / ss i en data)
  (setq ss (ssget "_X" (list (cons 0 types) (list -3 (list appid)))))
  (if ss
    (progn
      (c579:log (strcat "APP " appid " COUNT " (itoa (sslength ss))))
      (setq i 0)
      (repeat (sslength ss)
        (setq en (ssname ss i)
              data (urb:get-xdata-strings en appid))
        (c579:log
          (strcat "  HANDLE=" (cdr (assoc 5 (entget en)))
                  " TYPE=" (cdr (assoc 0 (entget en)))
                  " LAYER=" (cdr (assoc 8 (entget en)))
                  " DATA=" (vl-princ-to-string data)
                  " BOX=" (c579:bbox-text en)))
        (setq i (1+ i))))
    (c579:log (strcat "APP " appid " COUNT 0"))))

(defun c579:roads (/ ss i en mov data)
  (setq ss (ssget "_X" '((0 . "INSERT,LWPOLYLINE") (-3 ("URB_VIA")))))
  (c579:log (strcat "ROADS " (itoa (if ss (sslength ss) 0))))
  (if ss
    (progn
      (setq i 0)
      (repeat (sslength ss)
        (setq en (ssname ss i)
              data (urb:get-xdata-strings en "URB_VIA")
              mov (urb:road-movement-data en))
        (c579:log
          (strcat "  ROAD HANDLE=" (cdr (assoc 5 (entget en)))
                  " NAME=" (cdr (assoc 2 (entget en)))
                  " MOV=" (vl-princ-to-string mov)
                  " LEN=" (urb:safe-string (nth 18 data) "")
                  " AREA=" (urb:safe-string (nth 17 data) "")
                  " STATUS=" (urb:safe-string (nth 19 data) "")
                  " SURF=" (urb:safe-string (nth 6 data) "")
                  " BOX=" (c579:bbox-text en)))
        (setq i (1+ i))))))

(defun c579:loose (/ ss i en data)
  (setq ss (ssget "_X" '((-3 ("URB_ANDEN_GEN")))))
  (c579:log (strcat "LOOSE_ANDEN_GEN " (itoa (if ss (sslength ss) 0))))
  (if ss
    (progn
      (setq i 0)
      (repeat (sslength ss)
        (setq en (ssname ss i)
              data (urb:get-xdata-strings en "URB_ANDEN_GEN"))
        (c579:log
          (strcat "  LOOSE HANDLE=" (cdr (assoc 5 (entget en)))
                  " TYPE=" (cdr (assoc 0 (entget en)))
                  " LAYER=" (cdr (assoc 8 (entget en)))
                  " DATA=" (vl-princ-to-string data)
                  " PARENT_EXISTS=" (if (handent (car data)) "YES" "NO")
                  " BOX=" (c579:bbox-text en)))
        (setq i (1+ i))))))

(defun c579:run ()
  (c579:log (strcat "VERSION " *urb-version*))
  (c579:log (strcat "DWG " (getvar "DWGNAME")))
  (c579:scan-app "URB_ANDEN" "LWPOLYLINE")
  (c579:scan-app "URB_ANDEN_BLOCK" "INSERT")
  (c579:scan-app "URB_GREEN_BLOCK" "INSERT")
  (c579:scan-app "URB_GREEN_MOV" "INSERT")
  (c579:scan-app "URB_SENDERO" "LWPOLYLINE,INSERT")
  (c579:scan-app "URB_SEND_MOV" "LWPOLYLINE,INSERT")
  (c579:loose)
  (c579:roads)
  (c579:log "FINISHED"))

(if (findfile c579:out) (vl-file-delete c579:out))
(setq c579:result (vl-catch-all-apply 'c579:run nil))
(if (vl-catch-all-error-p c579:result)
  (c579:log (strcat "ERROR " (vl-catch-all-error-message c579:result))))
(princ)
