;;; ibis-test.el --- Tests for ibis.el -*- lexical-binding: t; -*-

;;; Commentary:

;; ERT tests for the vocabulary, graph, parser and serializer.

;;; Code:

(require 'ert)
(require 'ibis)

(ert-deftest ibis-test-namespace ()
  (should (equal ibis-namespace "https://vocab.methodandstructure.com/ibis#")))

(ert-deftest ibis-test-class-p ()
  (should (ibis-class-p 'issue))
  (should (ibis-class-p 'network))
  (should-not (ibis-class-p 'skos:Concept)))

(ert-deftest ibis-test-class-parent ()
  (should (eq (ibis-class-parent 'network) 'skos:ConceptScheme))
  (should (eq (ibis-class-parent 'argument) 'issue))
  (should (eq (ibis-class-parent 'entity) 'skos:Concept))
  (should-not (ibis-class-parent 'skos:Concept)))

(ert-deftest ibis-test-subclass-p ()
  (should (ibis-subclass-p 'argument 'state))
  (should (ibis-subclass-p 'issue 'issue))
  (should (ibis-subclass-p 'position 'skos:Concept))
  (should-not (ibis-subclass-p 'position 'issue)))

(ert-deftest ibis-test-disjoint-p ()
  (should (ibis-disjoint-p 'argument 'position))
  (should (ibis-disjoint-p 'position 'issue))
  (should-not (ibis-disjoint-p 'argument 'issue))
  (should-not (ibis-disjoint-p 'issue 'issue)))

(ert-deftest ibis-test-property-lookup ()
  (should (eq (ibis-property-range (ibis-property 'suggests)) 'issue))
  (should (eq (ibis-property-domain (ibis-property 'suggests)) 'entity))
  (should (eq (ibis-property-name (ibis-property 'response)) 'response))
  (should (eq (ibis-property-parent (ibis-property 'specializes)) 'skos:broader))
  (should-not (ibis-property 'nonesuch)))

(ert-deftest ibis-test-inverse ()
  (should (eq (ibis-inverse 'questions) 'questioned-by))
  (should (eq (ibis-inverse 'responds-to) 'response))
  (should-not (ibis-inverse 'nonesuch)))

(ert-deftest ibis-test-label ()
  (should (equal (ibis-label 'response) "Has Response"))
  (should (equal (ibis-label 'responds-to) "Responds to"))
  (should (equal (ibis-label 'issue) "Issue"))
  (should (equal (ibis-label 'position) "Position"))
  (should (equal (ibis-label 'argument) "Argument"))
  (should-not (ibis-label 'nonesuch)))

(ert-deftest ibis-test-preferred ()
  (should (eq (ibis-preferred 'supported-by) 'supports))
  (should (eq (ibis-preferred 'specializes) 'generalizes))
  (should (eq (ibis-preferred 'response) 'responds-to))
  (should (eq (ibis-preferred 'questions) 'questions)))

(ert-deftest ibis-test-inverse-of-inverse-is-self ()
  (dolist (name (ibis--property-names))
    (let* ((prop (ibis-property name))
           (back (ibis-property (ibis-property-inverse prop))))
      (should (eq (ibis-property-inverse back) name))
      (should (eq (ibis-property-domain back) (ibis-property-range prop)))
      (should (eq (ibis-property-range back) (ibis-property-domain prop))))))

(ert-deftest ibis-test-legal-properties ()
  (should (equal (ibis-legal-properties 'position 'argument)
                 '(supported-by opposed-by responds-to)))
  (should (equal (ibis-legal-properties 'position 'position)
                 '(generalizes specializes)))
  (should-not (ibis-legal-properties 'network 'issue)))

(ert-deftest ibis-test-relation-legal-p ()
  (should (ibis-relation-legal-p 'argument 'supports 'position))
  (should (ibis-relation-legal-p 'position 'responds-to 'issue))
  (should-not (ibis-relation-legal-p 'issue 'supports 'position))
  (should-not (ibis-relation-legal-p 'position 'supports 'argument)))

(ert-deftest ibis-test-legality-respects-domain-and-range ()
  (pcase-dolist (`((,subject . ,object) . ,names) ibis--legality)
    (dolist (name names)
      (let ((prop (ibis-property name)))
        (should prop)
        (should (ibis-subclass-p subject (ibis-property-domain prop)))
        (should (ibis-subclass-p object (ibis-property-range prop)))))))

(defun ibis-test--sample-network ()
  "Return a network of one issue with two positions attached."
  (let* ((network (make-ibis-network))
         (issue (ibis-network-add-node
                 network (make-ibis-node :id "I-1" :class 'issue :text "Wie?")))
         (first (ibis-network-add-node
                 network (make-ibis-node :class 'position :text "So")))
         (second (ibis-network-add-node
                  network (make-ibis-node :class 'position :text "Anders"))))
    (ibis-network-add-edge network first 'responds-to issue)
    (ibis-network-add-edge network second 'responds-to issue)
    network))

(ert-deftest ibis-test-network-node-by-id ()
  (let* ((network (ibis-test--sample-network))
         (issue (ibis-network-node-by-id network "I-1")))
    (should (eq issue (car (ibis-network-nodes network))))
    (should (equal (ibis-node-text issue) "Wie?"))
    (should-not (ibis-network-node-by-id network "I-9"))))

(ert-deftest ibis-test-node-parent-and-children ()
  (let* ((network (ibis-test--sample-network))
         (nodes (ibis-network-nodes network))
         (issue (nth 0 nodes))
         (first (nth 1 nodes))
         (second (nth 2 nodes)))
    (should (eq (ibis-node-parent network first) issue))
    (should (eq (ibis-node-parent network second) issue))
    (should-not (ibis-node-parent network issue))
    (should (equal (ibis-node-children network issue) (list first second)))
    (should-not (ibis-node-children network first))))

(ert-deftest ibis-test-network-add-edge ()
  (let* ((network (ibis-test--sample-network))
         (edge (car (ibis-network-edges network))))
    (should (= (length (ibis-network-edges network)) 2))
    (should (eq (ibis-edge-predicate edge) 'responds-to))
    (should (eq (ibis-edge-subject edge) (nth 1 (ibis-network-nodes network))))
    (should (eq (ibis-edge-object edge) (nth 0 (ibis-network-nodes network))))))

(provide 'ibis-test)

;;; ibis-test.el ends here
