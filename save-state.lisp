(in-package #:org.shirakumo.fraf.kandria)

(defun save-state-path (name)
  (ensure-directories-exist
   (make-pathname :name (format NIL "~(~a~)" name) :type "zip"
                  :defaults (config-directory))))

(defclass save-state ()
  ((author :initarg :author :accessor author)
   (id :initarg :id :accessor id)
   (start-time :initarg :start-time :accessor start-time)
   (save-time :initarg :save-time :accessor save-time)
   (play-time :initarg :play-time :accessor play-time)
   (image :initarg :image :initform NIL :accessor image)
   (file :initarg :file :accessor file))
  (:default-initargs
   :id (uuid:make-v4-uuid)
   :author (pathname-utils:directory-name (user-homedir-pathname))
   :start-time (get-universal-time)
   :save-time (get-universal-time)
   :play-time (total-play-time)))

(defmethod initialize-instance :after ((save-state save-state) &key (filename ""))
  (unless (slot-boundp save-state 'file)
    (setf (file save-state) (merge-pathnames filename (save-state-path (start-time save-state))))))

(defmethod print-object ((save-state save-state) stream)
  (print-unreadable-object (save-state stream :type T)
    (format stream "~s ~s" (author save-state) (file save-state))))

(defmethod exists-p ((save-state save-state))
  (probe-file (file save-state)))

(defun string<* (a b)
  (if (= (length a) (length b))
      (string< a b)
      (< (length a) (length b))))

(defun list-saves ()
  (sort
   (loop for file in (directory (merge-pathnames "?.zip" (config-directory)))
         for state = (handler-case (minimal-load-state file)
                       (warning ()
                         (v:warn :kandria.save "Save state ~s is too old, ignoring." file)
                         NIL)
                       (error (e)
                         (v:warn :kandria.save "Save state ~s failed to load, ignoring." file)
                         (v:debug :kandria.save e)
                         NIL))
         when state collect state)
   #'string<* :key (lambda (f) (pathname-name (file f)))))

(defun delete-saves ()
  (dolist (save (list-saves))
    (delete-file (file save))))

(defun minimal-load-state (file)
  (with-packet (packet file)
    (destructuring-bind (header initargs)
        (parse-sexps (packet-entry "meta.lisp" packet :element-type 'character))
      (assert (eq 'save-state (getf header :identifier)))
      (unless (supported-p (make-instance (getf header :version)))
        (warn "Save file too old to support."))
      (when (packet-entry-exists-p "image.png" packet)
        ;; KLUDGE: This fucking sucks, yo.
        (let ((temp (tempfile :type "png" :id (format NIL "kandria-~a" (pathname-name file)))))
          (with-packet-entry (in "image.png" packet :element-type '(unsigned-byte 8))
            (with-open-file (out temp :direction :output :if-exists :supersede :element-type '(unsigned-byte 8))
              (uiop:copy-stream-to-stream in out :element-type '(unsigned-byte 8))))
          (push temp initargs)
          (push :image initargs)))
      (apply #'make-instance 'save-state :file file initargs))))

(defun current-save-version ()
  (make-instance 'save-v1.2))

(defgeneric load-state (state world))
(defgeneric save-state (world state &key version &allow-other-keys))

(defmethod save-state ((world (eql T)) save &rest args)
  (apply #'call-next-method +world+ save args))

(defmethod save-state :around (world target &rest args &key (version T))
  (apply #'call-next-method world target :version (ensure-version version (current-save-version)) args))

(defmethod save-state ((world world) (save-state save-state) &key version)
  (v:info :kandria.save "Saving state from ~a to ~a" world save-state)
  (setf (save-time save-state) (get-universal-time))
  (with-packet (packet (file save-state) :direction :output :if-exists :supersede)
    (with-packet-entry (stream "meta.lisp" packet :element-type 'character)
      (princ* (list :identifier 'save-state :version (type-of version)) stream)
      (princ* (list :id (id save-state)
                    :author (author save-state)
                    :start-time (start-time save-state)
                    :save-time (save-time save-state)
                    :play-time (play-time save-state))
              stream))
    (with-packet-entry (out "image.png" packet :element-type '(unsigned-byte 8))
      (render +world+ NIL)
      (let* ((temp (tempfile :type "png" :id (format NIL "kandria-~a" (pathname-name (file save-state)))))
             (width 192) (height 108)
             (data (trial::flip-image-vertically
                    (trial::downscale-image (capture NIL) (width *context*) (height *context*) 3 width height)
                    width height 3)))
        (zpng:write-png (make-instance 'zpng:png :color-type :truecolor :width width :height height :image-data data) temp)
        (with-open-file (in temp :direction :input :element-type '(unsigned-byte 8))
          (uiop:copy-stream-to-stream in out :element-type '(unsigned-byte 8)))))
    (encode-payload world NIL packet version))
  save-state)

(defmethod load-state ((save-state save-state) world)
  (load-state (file save-state) world))

(defmethod load-state (state (world (eql T)))
  (load-state state +world+))

(defmethod load-state ((integer integer) world)
  (load-state (save-state-path integer) world))

(defmethod load-state ((pathname pathname) world)
  (with-packet (packet pathname)
    (load-state packet world)))

(defmethod load-state ((packet packet) (world world))
  (v:info :kandria.save "Loading state from ~a into ~a" packet world)
  (destructuring-bind (header initargs)
      (parse-sexps (packet-entry "meta.lisp" packet :element-type 'character))
    (assert (eq 'save-state (getf header :identifier)))
    (when (unit 'distortion T)
      (setf (strength (unit 'distortion T)) 0.0))
    (when (unit 'walkntalk world)
      (walk-n-talk NIL))
    (dolist (progression (progressions world))
      (reset progression))
    (setf (area-states (unit 'environment world)) NIL)
    (let ((version (coerce-version (getf header :version))))
      (decode-payload NIL world packet version)
      (apply #'make-instance 'save-state initargs))))

(defclass quicksave-state (save-state)
  ((file :initform (save-state-path "quicksave"))))

(defun submit-trace (state)
  (let ((file (tempfile :type "dat"))
        (trace (movement-trace (unit 'player +world+))))
    (trial::with-unwind-protection (delete-file file)
      (with-open-file (stream file :direction :output :element-type '(unsigned-byte 8))
        (dotimes (i (length trace))
          (nibbles:write-ieee-single/le (aref trace i) stream)))
      (org.shirakumo.fraf.trial.feedback:submit-snapshot
       (id state) (play-time state) (session-time) :trace file))))
