(in-package #:org.shirakumo.fraf.kandria)

(defclass main (org.shirakumo.fraf.trial.steam:main
                org.shirakumo.fraf.trial.notify:main)
  ((scene :initform NIL)
   (state :initarg :state :initform NIL :accessor state)
   (quicksave :initform (make-instance 'quicksave-state :play-time 0) :accessor quicksave)
   (timestamp :initform (get-universal-time) :accessor timestamp)
   (org.shirakumo.fraf.trial.steam:use-steaminput :initform NIL))
  (:default-initargs
   :clear-color (vec 2/17 2/17 2/17 0)
   :version '(3 3) :profile :core
   :title #.(format NIL "Kandria - ~a" (version :app))
   :app-id 1261430
   :world (pathname-utils:subdirectory (root) "world")))

(defmethod initialize-instance ((main main) &key app-id world)
  (declare (ignore app-id))
  (setf +main+ main)
  (call-next-method)
  (setf +input-source+ :keyboard)
  (with-packet (packet world :direction :input)
    (setf (scene main) (make-instance 'world :packet packet)))
  ;; FIXME: Allow running without sound.
  (harmony:start (harmony:make-simple-server :name "Kandria" :latency (setting :audio :latency)))
  (loop for (k v) on (setting :audio :volume) by #'cddr
        do (setf (harmony:volume k) v)))

(defmethod initialize-instance :after ((main main) &key region)
  (when region
    (load-region region T)))

(defmethod update ((main main) tt dt fc)
  (let* ((scene (scene main))
         (dt (* (time-scale scene) (float dt 1.0))))
    (when (< 0 (pause-timer scene))
      (decf (pause-timer scene) dt)
      (setf dt (* dt 0.05)))
    (issue scene 'tick :tt tt :dt dt :fc fc)
    (process scene)))

(defmethod (setf scene) :after (scene (main main))
  (setf +world+ scene))

(defmethod finalize :after ((main main))
  (setf +world+ NIL)
  (harmony:free harmony:*server*)
  (setf harmony:*server* NIL)
  (setf +main+ NIL))

(defmethod save-state ((main main) (state (eql T)) &rest args)
  (unless (state main)
    (setf (state main) (make-instance 'save-state :filename "1")))
  (apply #'save-state main (state main) args))

(defmethod save-state ((main main) (state (eql :quick)) &rest args)
  (apply #'save-state main (quicksave main) args))

(defmethod save-state ((main main) (state save-state) &rest args)
  (prog1 (apply #'save-state (scene main) state args)
    (unless (typep state 'quicksave-state)
      (setf (state main) state))))

(defmethod load-state ((state (eql T)) (main main))
  (cond ((state main)
         (if (< (save-time (state main)) (save-time (quicksave main)))
             (load-state (quicksave main) main)
             (load-state (state main) main)))
        ((list-saves)
         (load-state (first (list-saves)) main))
        (T
         (load-state NIL main))))

(defmethod load-state ((state (eql :quick)) (main main))
  (load-state (quicksave main) main))

(defmethod load-state ((state null) (main main))
  (load-state (initial-state (scene main)) (scene main))
  (trial:commit (scene main) (loader main))
  (clrhash +spawn-tracker+))

(defmethod load-state ((state save-state) (main main))
  (restart-case
      (handler-bind ((error (lambda (e)
                              (when (deploy:deployed-p)
                                (v:severe :kandria.save "Failed to load save state ~a: ~a" state e)
                                (v:debug :kandria.save e)
                                (invoke-restart 'reset)))))
        (prog1 (load-state state (scene main))
          (trial:commit (scene main) (loader main))
          (clrhash +spawn-tracker+)
          (unless (typep state 'quicksave-state)
            (setf (state main) state))))
    (reset ()
      :report "Ignore the save and reset to the initial state."
      (load-state NIL main))))

(defun session-time (&optional (main +main+))
  (- (get-universal-time) (timestamp main)))

(defun total-play-time (&optional (main +main+))
  ;; FIXME: This is /not/ correct as repeat saving and loading will accrue time manyfold.
  #++
  (+ (- (get-universal-time) (timestamp main))
     (play-time (state main)))
  ;; FIXME: This is /not/ correct either as it's influenced by time dilution and dilation.
  (clock (scene main)))

(defun main ()
  (let* ((args (uiop:command-line-arguments))
         (arg (pop args)))
    (cond ((null arg)
           (launch))
          ((equal arg "config-directory")
           (format T "~&~a~%" (uiop:native-namestring (config-directory))))
          ((equal arg "controller-config")
           (gamepad::configurator-main))
          ((equal arg "credits")
           (format T "~&~a~%" (alexandria:read-file-into-string
                               (merge-pathnames "CREDITS.mess" (root)))))
          ((equal arg "region")
           (if args
               (launch :region (pop args))
               (format T "~&Please pass a region file to load.~%")))
          ((equal arg "report")
           (let ((report (format NIL "~{~a~^ ~}" args)))
             (org.shirakumo.fraf.trial.feedback:submit-report
              :files NIL :description report)
             (format T "~&Report sent. Thank you!~%")))
          ((equal arg "swank")
           (let ((port (swank:create-server :dont-close T)))
             (format T "~&Started swank on port ~d.~%" port)
             (loop (sleep 1))))
          ((equal arg "state")
           (if args
               (launch :state (make-instance 'save-state :file (uiop:parse-native-namestring (pop args))))
               (format T "~&Please pass a save file to load.~%")))
          ((equal arg "world")
           (if args
               (launch :world (pop args))
               "~&Please pass a world file to load.~%"))
          ((equal arg "help")
           (format T "~&Kandria v~a

Website:     https://kandria.com
Discord:     https://kandria.com/discord
Steam page:  https://kandria.com/steam
Editor Help: https://kandria.com/editor

Possible sub-commands:
  config-directory      Show the directory with config and save files.
  controller-config     Launch the controller configuration utility.
  credits               Show the game credits.
  help                  Show this help screen.
  region [region]       Load the region from the specified file.
  report [report...]    Send a feedback report.
  state [save]          Load the save from the specified file.
  swank                 Launch swank to allow debugging.
  world [world]         Load the world from the specified file.
" (version :app))))))

(defmethod render-loop :around ((main main))
  (let ((*package* #.*package*))
    (call-next-method)))

(defun launch (&rest initargs)
  (let ((*package* #.*package*))
    (load-keymap)
    (ignore-errors
     (load-settings))
    (save-settings)
    (maybe-start-swank)
    (apply #'trial:launch 'main
           :width (first (setting :display :resolution))
           :height (second (setting :display :resolution))
           :vsync (setting :display :vsync)
           :fullscreen (setting :display :fullscreen)
           (append (setting :debugging :initargs) initargs))))

(defmethod setup-scene ((main main) (scene world))
  (enter (make-instance 'camera) scene)
  (let ((shadow (make-instance 'shadow-map-pass))
        (lighting (make-instance 'lighting-pass))
        (rendering (make-instance 'rendering-pass))
        (distortion (make-instance 'distortion-pass))
        (disp-render (make-instance 'displacement-render-pass))
        (displacement (make-instance 'displacement-pass))
        (sandstorm (make-instance 'sandstorm-pass))
        ;; This is dumb and inefficient. Ideally we'd connect the same output
        ;; to both distortion and UI and then just make the UI pass not clear
        ;; the framebuffer when drawing.
        (ui (make-instance 'ui-pass :base-scale (setting :display :ui-scale)))
        (blend (make-instance 'blend-pass :name 'blend)))
    (connect (port shadow 'shadow-map) (port rendering 'shadow-map) scene)
    (connect (port lighting 'color) (port rendering 'lighting) scene)
    (connect (port rendering 'color) (port displacement 'previous-pass) scene)
    (connect (port disp-render 'displacement-map) (port displacement 'displacement-map) scene)
    (connect (port displacement 'color) (port sandstorm 'previous-pass) scene)
    (connect (port sandstorm 'color) (port distortion 'previous-pass) scene)
    (connect (port distortion 'color) (port blend 'trial::a-pass) scene)
    (connect (port ui 'color) (port blend 'trial::b-pass) scene))
  (register (make-instance 'walkntalk) scene)
  (show (make-instance 'status-lines))
  (when (deploy:deployed-p)
    (show (make-instance 'report-button-panel))))

(defmethod setup-rendering :after ((main main))
  (disable :cull-face :scissor-test :depth-test)
  (load-state T main)
  (save-state main (quicksave main))
  (save-state main T))

(defun apply-video-settings (&optional (settings (setting :display)))
  (when *context*
    (destructuring-bind (&key resolution fullscreen vsync ui-scale &allow-other-keys) settings
      (show *context* :fullscreen fullscreen :mode resolution)
      (setf (vsync *context*) vsync)
      (setf (alloy:base-scale (unit 'ui-pass T)) ui-scale))))

(define-setting-observer volumes :audio :volume (value)
  (when harmony:*server*
    (loop for (k v) on value by #'cddr
          do (setf (harmony:volume k) v))))

(define-setting-observer video :display (value)
  (apply-video-settings value))

(defun maybe-start-swank (&optional force)
  (let ((swank (etypecase (or force (setting :debugging :swank))
                 (null NIL)
                 ((eql T) swank::default-server-port)
                 (integer (setting :debugging :swank)))))
    (when swank
      (v:info :kandria.debugging "Launching SWANK server on port ~a." swank)
      (swank:create-server :port swank :dont-close T)
      (setf *inhibit-standalone-error-handler* T))))

(load-quests :eng)
