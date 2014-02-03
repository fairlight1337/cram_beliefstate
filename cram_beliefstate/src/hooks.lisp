(in-package :beliefstate)

(defmethod sem-map-coll-env::on-publishing-collision-object
    cram-beliefstate (object obj-name)
  (with-slots ((pose sem-map-coll-env::pose)
               (type sem-map-coll-env::type)
               (index sem-map-coll-env::index)
               (name sem-map-coll-env::name)
               (dimensions sem-map-coll-env::dimensions)) object
    (let* ((surfaces
             `(,(cons "kitchen_island" "HTTP://IAS.CS.TUM.EDU/KB/KNOWROB.OWL#KITCHEN_ISLAND_COUNTER_TOP-0")
               ,(cons "kitchen_sink_block" "HTTP://IAS.CS.TUM.EDU/KB/KNOWROB.OWL#KITCHEN_SINK_BLOCK_COUNTER_TOP-0")))
           (entry (find obj-name surfaces :test (lambda (x y)
                                                  (string= x (cdr y))))))
      (when entry
        (let ((offset-pose (tf:make-pose (tf:v+ (tf:origin pose)
                                                (tf:make-3d-vector 0 0 0.01))
                                         (tf:orientation pose))))
          (beliefstate:register-interactive-object
           (car entry) 'box offset-pose
           (vector (sem-map-coll-env::x dimensions)
                   (sem-map-coll-env::y dimensions)
                   (sem-map-coll-env::z dimensions))
           `((examine-tabletop ((label ,(concatenate 'string
                                                     "Examine countertop '"
                                                     (car entry)
                                                     "'"))
                                (parameter ,(car entry)))))))))))

(defmethod plan-lib::on-preparing-performing-action-designator
    cram-beliefstate (designator matching-process-modules)
  (prog1
      (beliefstate:start-node
       "PERFORM-ACTION-DESIGNATOR"
       (list
        (list 'description
              (write-to-string
               (desig:description designator)))
        (list 'matching-process-modules
              (write-to-string
               matching-process-modules)))
       2)
    (beliefstate:add-designator-to-active-node designator)))

(defmethod plan-lib::on-finishing-performing-action-designator
    cram-beliefstate (id success)
  (declare (ignore success))
  ;; NOTE(winkler): Success is not used at the moment. It would be
  ;; nice to have an additional service, saying "append data to
  ;; current task". The success would the go there.
  (beliefstate:stop-node id))

(defmethod plan-lib::on-with-designator cram-beliefstate (designator)
  (beliefstate:add-designator-to-active-node
   designator))  

(defmethod cpl-impl::on-preparing-named-top-level cram-beliefstate (name)
  (let ((name (or name "ANONYMOUS-TOP-LEVEL")))
    (beliefstate:start-node name `() 1)))

(defmethod cpl-impl::on-finishing-named-top-level cram-beliefstate (id)
  (beliefstate:stop-node id))

(defmethod cpl-impl::on-preparing-task-execution cram-beliefstate (name log-parameters)
  (beliefstate:start-node name log-parameters 1))

(defmethod cpl-impl::on-finishing-task-execution cram-beliefstate (id)
  (beliefstate:stop-node id))

(defmethod cpl-impl::on-fail cram-beliefstate (condition)
  (when condition
    (let ((failure (intern (symbol-name (slot-value
                                         (class-of condition)
                                         'sb-pcl::name)))))
      (beliefstate:add-failure-to-active-node failure))))

(defmethod desig::on-equate-designators (successor parent)
  (format t "Equate!~%")
  (beliefstate:equate-designators successor parent))

(in-package :crs)

;; Switch off prolog logging for now
;; (defmethod hook-before-proving-prolog :around (query binds)
;;   (beliefstate:start-node "PROLOG"
;;                           (list (list 'query (write-to-string query))
;;                                 (list 'bindings (write-to-string binds)))
;;                           3))

;; (defmethod hook-after-proving-prolog :around (id success)
;;   (beliefstate:stop-node id :success success))


(in-package :cram-uima)

(defmethod hook-before-uima-request :around (designator-request)
  (let ((id (beliefstate:start-node
             "UIMA-PERCEIVE"
             (cram-designators:description designator-request) 2)))
    (beliefstate:add-designator-to-active-node designator-request
                                               :annotation "perception-request")
    id))

(defmethod hook-after-uima-request :around (id result)
  (dolist (desig result)
    (beliefstate:add-object-to-active-node
     desig :annotation "perception-result"))
  (beliefstate:add-topic-image-to-active-node cram-beliefstate::*kinect-topic-rgb*)
  (beliefstate:stop-node id :success (not (eql result nil))))


(in-package :pr2-manipulation-process-module)

(defmethod hook-before-grasp :around (obj-desig)
  (prog1
      (beliefstate:start-node
       "GRASP"
       `() 2)
    (beliefstate:add-topic-image-to-active-node cram-beliefstate::*kinect-topic-rgb*)
    (beliefstate:add-designator-to-active-node obj-desig
                                               :annotation "object-acted-on")))

(defmethod hook-after-grasp :around (id success)
  (progn
    (beliefstate:add-topic-image-to-active-node cram-beliefstate::*kinect-topic-rgb*)
    (beliefstate:stop-node id :success success)))

(defmethod hook-before-putdown :around (obj-desig loc-desig)
  (prog1
      (beliefstate:start-node
       "PUTDOWN"
       `() 2)
    (beliefstate:add-topic-image-to-active-node cram-beliefstate::*kinect-topic-rgb*)
    (beliefstate:add-designator-to-active-node
     obj-desig :annotation "object-acted-on")
    (beliefstate:add-designator-to-active-node
     loc-desig :annotation "putdown-location")))

(defmethod hook-after-putdown :around (id success)
  (progn
    (beliefstate:add-topic-image-to-active-node cram-beliefstate::*kinect-topic-rgb*)
    (beliefstate:stop-node id :success success)))

(defmethod hook-before-move-arm :around (side pose-stamped
                                 planning-group ignore-collisions)
  (prog1
      (beliefstate:start-node
       "VOLUNTARY-BODY-MOVEMENT"
       `() 2)
    (beliefstate:add-designator-to-active-node
     (make-designator
      'cram-designators:action
      `((link ,side)
        (goal-pose ,pose-stamped)
        (planning-group ,planning-group)
        (ignore-collisions ,(cond (ignore-collisions 1)
                                  (t 0)))))
     :annotation "voluntary-movement-details")))

(defmethod hook-after-move-arm :around (id success)
  (beliefstate:stop-node id :success success))
