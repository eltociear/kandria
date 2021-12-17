(in-package #:org.shirakumo.fraf.kandria)

(define-global +default-medium+ (make-instance 'air))
(defvar *current-event* NIL)

(defclass moving (game-entity)
  ((collisions :initform (make-array 4 :initial-element NIL) :reader collisions)
   (medium :initform +default-medium+ :accessor medium)
   (air-time :initform 1.0 :accessor air-time)))

(defmethod handle ((ev tick) (moving moving))
  (when (next-method-p) (call-next-method))
  (let ((loc (location moving))
        (*current-event* ev)
        (size (bsize moving))
        (collisions (collisions moving)))
    ;; Scan for medium
    (let ((medium (bvh:do-fitting (entity (bvh (region +world+)) moving +default-medium+)
                    (when (typep entity 'medium)
                      (return entity)))))
      (setf (medium moving) medium)
      (nv* (velocity moving) (drag medium))
      (if (and (typep medium 'sized-entity)
               (within-p medium moving))
          (submerged moving medium)
          (submerged moving +default-medium+)))
    ;; Scan for hits
    (fill collisions NIL)
    (loop for i from 0
          for hit = (handle-collisions +world+ moving)
          while hit
          do ;; KLUDGE: If we have too many collisions in a frame, we assume
             ;;         we're stuck somewhere, so just die.
             (cond ((< 11 i)
                    (vsetf (frame-velocity moving) 0 0)
                    (unless (typep (hit-object hit) 'moving)
                      (v:warn :kandria.collision "~a has become permanently stuck on~%  ~a" moving hit)
                      (kill moving))
                    (return))
                   ((< 10 i)
                    (vsetf (frame-velocity moving) 0 0))))
    (when (eq (svref collisions 2) (svref collisions 1))
      (setf (svref collisions 1) NIL))
    (when (eq (svref collisions 2) (svref collisions 3))
      (setf (svref collisions 3) NIL))
    ;; Point test for adjacent walls
    (flet ((test (hit)
             (not (collides-p moving (hit-object hit) hit))))
      (let ((l (scan +world+ (vec (- (vx loc) (vx size) 1) (vy loc) 1 (1- (vy size))) #'test)))
        (when l
          (setf (aref collisions 3) (hit-object l))
          ;; Zip L/R. Pretty bad kludge.
          (when (and (typep (aref collisions 3) 'ground)
                     (< 0 (- (vx loc) (vx (hit-location l))) (+ (/ +tile-size+ 2) (vx size))))
            (setf (vx loc) (+ (vx (hit-location l)) (/ +tile-size+ 2) (vx size))))))
      (let ((r (scan +world+ (vec (+ (vx loc) (vx size) 1) (vy loc) 1 (1- (vy size))) #'test)))
        (when r
          (setf (aref collisions 1) (hit-object r))
          ;; Zip L/R. Pretty bad kludge.
          (when (and (typep (aref collisions 1) 'ground)
                     (< 0 (- (vx (hit-location r)) (vx loc)) (+ (/ +tile-size+ 2) (vx size))))
            (setf (vx loc) (- (vx (hit-location r)) (/ +tile-size+ 2) (vx size))))))
      (let ((u (scan +world+ (vec (vx loc) (+ (vy loc) (vy size) 1.5) (1- (vx size)) 1) #'test)))
        (when u
          (setf (aref collisions 0) (hit-object u))))
      (let ((b (scan +world+ (vec (vx loc) (- (vy loc) (vy size) 1.5) (1- (vx size)) 1) #'test)))
        (when b
          (setf (aref collisions 2) (hit-object b))))))
  (incf (air-time moving) (dt ev)))

(defmethod collides-p ((moving moving) (solid half-solid) hit)
  (= 0 (vy (hit-normal hit))))

(defmethod collide :after ((moving moving) (block block) hit)
  (when (< 0 (vy (hit-normal hit)))
    (setf (air-time moving) 0.0)))

(defmethod collide :after ((moving moving) (solid solid) hit)
  (when (< 0 (vy (hit-normal hit)))
    (setf (air-time moving) 0.0)))

(defmethod collide ((moving moving) (block block) hit)
  (let* ((loc (location moving))
         (vel (frame-velocity moving))
         (pos (hit-location hit))
         (normal (hit-normal hit))
         (height (vy (bsize moving)))
         (t-s (/ (block-s block) 2)))
    (cond ((= +1 (vy normal)) (setf (svref (collisions moving) 2) block)
           (setf (vy (velocity moving)) (max 0 (vy (velocity moving)))))
          ((= -1 (vy normal)) (setf (svref (collisions moving) 0) block))
          ((= +1 (vx normal)) (setf (svref (collisions moving) 3) block))
          ((= -1 (vx normal)) (setf (svref (collisions moving) 1) block)))
    (nv+ loc (v* vel (clamp 0 (hit-time hit) 1)))
    (nv- vel (v* normal (v. vel normal)))
    ;; If we're just bumping the edge, move us up.
    (when (and (< -3 (- (vy loc) height (+ t-s (vy pos))) 3)
               (/= 0 (vx normal))
               (null (scan-collision +world+ (v+ pos (vec 0 t-s)))))
      (setf (svref (collisions moving) 2) block)
      (incf (vy loc)))
    ;; Zip out of ground in case of clipping
    (when (/= 0 (vy normal))
      (cond ((and (< (vy pos) (vy loc))
                  (< (- (vy loc) height)
                     (+ (vy pos) t-s)))
             (setf (vy loc) (+ (vy pos) t-s height)))
            ((and (< (vy loc) (vy pos))
                  (< (- (vy pos) t-s)
                     (+ (vy loc) height)))
             (setf (vy loc) (- (vy pos) t-s height))
             (let ((ground (svref (collisions moving) 2)))
               (when (typep ground 'slope)
                 ;; We are on a slope, too, so push in direction of slope
                 (decf (vx loc) (float-sign (- (vy (slope-r ground)) (vy (slope-l ground))))))))))))

(defmethod collides-p ((moving moving) (block platform) hit)
  (and (< (vy (frame-velocity moving)) 0)
       (<= (+ (vy (hit-location hit)) (floor +tile-size+ 2))
           (- (vy (location moving)) (vy (bsize moving))))))

(defmethod collide ((moving moving) (block platform) hit)
  (let* ((loc (location moving))
         (vel (frame-velocity moving))
         (pos (hit-location hit))
         (normal (hit-normal hit))
         (height (vy (bsize moving)))
         (t-s (/ (block-s block) 2)))
    (setf (svref (collisions moving) 2) block)
    (nv+ loc (v* vel (hit-time hit)))
    (nv- vel (v* normal (v. vel normal)))
    ;; Force clamp velocity to zero to avoid "speeding up while on ground"
    (setf (vy (velocity moving)) (max 0 (vy (velocity moving))))
    ;; Zip
    (when (< (- (vy loc) height)
             (+ (vy pos) t-s))
      (setf (vy loc) (+ (vy pos) t-s height)))))

(defmethod collide ((moving moving) (block death) hit)
  (when (collides-p moving block hit)
    (kill moving)))

(defmethod collides-p ((moving moving) (block spike) hit)
  (let ((vel (if (v= (frame-velocity moving) 0.0) (velocity moving) (frame-velocity moving))))
    (unless (v= vel 0.0)
      (let ((angle (vangle (spike-normal block) vel))
            (loc (nv+ (v* vel 0.5) (location moving))))
        (and (<= 85 (rad->deg angle) 185)
             (if (/= 0 (vx (spike-normal block)))
                 (<= (abs (- (vx (hit-location hit)) (vx loc))) 7)
                 (<= (abs (- (vy (hit-location hit)) (vy loc))) 7)))))))

(defmethod collides-p ((moving moving) (block slope) hit)
  (ignore-errors
   (let ((tt (slope (location moving) (frame-velocity moving) (bsize moving) block (hit-location hit))))
     (when tt
       (setf (hit-time hit) tt)
       (setf (hit-normal hit) (nvunit (vec2 (- (vy2 (slope-l block)) (vy2 (slope-r block)))
                                            (- (vx2 (slope-r block)) (vx2 (slope-l block))))))))))

(defmethod collide ((moving moving) (block slope) hit)
  (let* ((loc (location moving))
         (vel (frame-velocity moving))
         (normal (hit-normal hit)))
    (setf (svref (collisions moving) 2) block)
    (nv+ loc (v* vel (clamp 0 (hit-time hit) 1)))
    (nv- vel (v* normal (v. vel normal)))
    ;; Force clamp velocity to zero to avoid "speeding up while on ground"
    (setf (vy (velocity moving)) (max 0 (vy (velocity moving))))
    ;; Make sure we stop sliding down the slope.
    (when (< (abs (vx vel)) 0.3)
      (setf (vx vel) 0.0))
    (when (< (abs (vy vel)) 0.001)
      (setf (vy vel) 0.0))
    ;; Zip
    (let* ((xrel (+ 0.5 (/ (- (vx loc) (vx (hit-location hit))) +tile-size+)))
           (yrel (lerp (vy (slope-l block)) (vy (slope-r block)) (clamp 0f0 xrel 1f0))))
      (setf (vy loc) (max (vy loc) (+ yrel (vy (bsize moving)) (vy (hit-location hit))))))))

(defmethod collides-p :before ((moving moving) (other moving-platform) hit)
  (when *current-event*
    (handle *current-event* other)))

(defmethod collide ((moving moving) (other game-entity) hit)
  ;; WTF: I have no idea how this can happen, but it DOES.
  (when (eq moving other) (return-from collide))
  (let* ((loc (location moving))
         (vel (frame-velocity moving))
         (pos (location other))
         (normal (hit-normal hit))
         (bsize (bsize moving))
         (psize (bsize other)))
    (cond ((= +1 (vy normal)) (setf (svref (collisions moving) 2) other)
           (setf (vy (velocity moving)) (max 0 (vy (velocity moving)))))
          ((= -1 (vy normal)) (setf (svref (collisions moving) 0) other))
          ((= +1 (vx normal)) (setf (svref (collisions moving) 3) other))
          ((= -1 (vx normal)) (setf (svref (collisions moving) 1) other)))
    ;; I know not doing this seems very wrong, but doing it
    ;; causes weirdly slow movement on falling platforms.
    #++
    (nv+ loc (v* (v+ vel (frame-velocity other)) (hit-time hit)))
    (cond ((< (* (vy vel) (vy normal)) 0) (setf (vy vel) 0))
          ((< (* (vx vel) (vx normal)) 0) (setf (vx vel) 0)))
    (when (or (eql :animated (state other))
              (typep other 'moving-platform))
      (nv+ vel (velocity other)))
    ;; Zip out of ground in case of clipping
    (unless (or (typep moving 'half-solid)
                (typep other 'half-solid))
      (when (<= (abs (- (vx pos) (vx loc))) (vx psize))
        (when (and (< (vy pos) (vy loc))
                   (null (svref (collisions moving) 0)))
          (setf (vy loc) (+ (vy pos) (vy psize) (vy bsize))))
        (when (and (< (vy loc) (vy pos))
                   (null (svref (collisions moving) 2)))
          (setf (vy loc) (- (vy pos) (vy psize) (vy bsize))))))
    (when (<= (abs (- (vy pos) (vy loc))) (vy psize))
      (when (and (< (vx pos) (vx loc))
                 (null (svref (collisions moving) 1)))
        (setf (vx loc) (+ (vx pos) (vx psize) (vx bsize))))
      (when (and (< (vx loc) (vx pos))
                 (null (svref (collisions moving) 3)))
        (setf (vx loc) (- (vx pos) (vx psize) (vx bsize)))))))

(defmethod collides-p ((moving moving) (stopper stopper) hit) NIL)
(defmethod interactable-p ((elevator elevator)) T)

(defun place-on-ground (entity loc &optional (xdiff 0) (ydiff 0))
  (let* ((chunk (find-chunk loc))
         (ground (when chunk (find-ground chunk loc))))
    (if ground
        (vsetf (location entity)
               (random* (vx ground) xdiff)
               (+ (vy ground) (vy (bsize entity))))
        (vsetf (location entity)
               (random* (vx loc) xdiff)
               (+ (- (vy loc) ydiff) (vy (bsize entity)) 1)))))

(defmethod collide ((moving moving) (other sized-entity) hit)
  (let* ((loc (location moving))
         (vel (frame-velocity moving))
         (pos (location other))
         (normal (hit-normal hit))
         (bsize (bsize moving))
         (psize (bsize other)))
    (cond ((= +1 (vy normal)) (setf (svref (collisions moving) 2) other)
           (setf (vy (velocity moving)) (max (vy (velocity other)) (vy (velocity moving)))))
          ((= -1 (vy normal)) (setf (svref (collisions moving) 0) other))
          ((= +1 (vx normal)) (setf (svref (collisions moving) 3) other))
          ((= -1 (vx normal)) (setf (svref (collisions moving) 1) other)))
    (nv+ loc (v* vel (hit-time hit)))
    (cond ((< (* (vy vel) (vy normal)) 0) (setf (vy vel) 0))
          ((< (* (vx vel) (vx normal)) 0) (setf (vx vel) 0)))
    ;; Zip out of ground in case of clipping
    (unless (or (typep moving 'half-solid)
                (typep other 'half-solid))
      (when (<= (abs (- (vx pos) (vx loc))) (vx psize))
        (when (and (< (vy pos) (vy loc))
                   (< (- (vy loc) (vy bsize)) (+ (vy pos) (vy psize)))
                   (null (svref (collisions moving) 0)))
          (setf (vy loc) (+ (vy pos) (vy psize) (vy bsize))))
        (when (and (< (vy loc) (vy pos))
                   (< (- (vy pos) (vy psize)) (+ (vy loc) (vy bsize)))
                   (null (svref (collisions moving) 2)))
          (setf (vy loc) (- (vy pos) (vy psize) (vy bsize))))))
    (when (<= (abs (- (vy pos) (vy loc))) (vy psize))
      (when (and (< (vx pos) (vx loc))
                 (< (- (vy loc) (vy bsize)) (+ (vy pos) (vy psize)))
                 (null (svref (collisions moving) 1)))
        (setf (vx loc) (+ (vx pos) (vx psize) (vx bsize))))
      (when (and (< (vx loc) (vx pos))
                 (< (- (vy pos) (vy psize)) (+ (vy loc) (vy bsize)))
                 (null (svref (collisions moving) 3)))
        (setf (vx loc) (- (vx pos) (vx psize) (vx bsize)))))))
