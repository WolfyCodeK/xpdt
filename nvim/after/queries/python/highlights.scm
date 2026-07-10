;; extends

; Class-definition name: bat colors it cyan + underline (entity.name.class).
((class_definition name: (identifier) @type.classdef)
 (#set! "priority" 200))

; Base (inherited) classes: bat colors these green + underline, distinct from
; the class name. Capture the whole superclass (incl. the module part of a
; dotted name like models.IntegerChoices) so it all goes green.
((class_definition
   superclasses: (argument_list (identifier) @type.inherited))
 (#set! "priority" 200))

((class_definition
   superclasses: (argument_list (attribute) @type.inherited))
 (#set! "priority" 200))
