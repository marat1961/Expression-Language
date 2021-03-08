# Expression-Language

The Expression Language (EL) is a simple language designed to meet the needs of the presentation layer in applications.

The syntax is quite simple. Model objects are accessed by name. A generalized "[]" operator can be used to access maps, lists, arrays of objects and properties of a object, and to invoke methods in a object; the operator can be nested arbitrarily. 

The "." operator can be used as a convenient shorthand for property access when the property name follows the conventions of identifiers, but the "[]" operator allows for more generalized access. Simlarly, "." operator can also be used to invoke methods, when the method name is known, but the "[]" operator can be used to invoke methods dynamically.

Relational comparisons are allowed using the standard relational operators.

Comparisons may be made against other values, or against boolean (for equality comparisons only), string, integer, or floating point literals. Arithmetic operators can be used to compute integer and floating point values. Logical operators are available.

The EL features a flexible architecture where the resolution of model objects (and their associated properties), functions, and variables are all performed through a pluggable API, making the EL easily adaptable to various environments.
