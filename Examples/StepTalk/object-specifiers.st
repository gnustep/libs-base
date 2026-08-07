"============================================
 Object Specifiers Example
 Demonstrates building object specifiers
 to target specific objects
============================================"

| bridge spec1 spec2 result |

"Get the shared bridge instance"
bridge := GSScriptingStepTalkBridge sharedBridge.

Transcript show: 'Object Specifier Examples'; cr.
Transcript show: '========================'; cr; cr.

"Example 1: Simple property specifier"
Transcript show: 'Example 1: Property Specifier'; cr.
spec1 := bridge
    createSpecifier: 'property'
    inContainer: nil
    forKey: 'name'
    withValue: nil.

Transcript show: 'Created property specifier for "name"'; cr; cr.

"Example 2: Index specifier"
Transcript show: 'Example 2: Index Specifier'; cr.
spec2 := bridge
    createSpecifier: 'index'
    inContainer: nil
    forKey: 'documents'
    withValue: 1.

Transcript show: 'Created index specifier for first document'; cr; cr.

"Example 3: Name specifier"
Transcript show: 'Example 3: Name Specifier'; cr.
spec2 := bridge
    createSpecifier: 'name'
    inContainer: nil
    forKey: 'windows'
    withValue: 'MyWindow'.

Transcript show: 'Created name specifier for window "MyWindow"'; cr; cr.

"Example 4: Nested specifiers"
Transcript show: 'Example 4: Nested Specifiers'; cr.

"Container specifier - first document"
spec1 := bridge
    createSpecifier: 'index'
    inContainer: nil
    forKey: 'documents'
    withValue: 1.

"Property specifier within container"
spec2 := bridge
    createSpecifier: 'property'
    inContainer: spec1
    forKey: 'name'
    withValue: nil.

Transcript show: 'Created nested specifier: name of first document'; cr; cr.

"Example 5: Using specifier in a command"
Transcript show: 'Example 5: Using Specifier in Command'; cr.

result := bridge
    executeCommand: 'get'
    forSuite: 'CoreSuite'
    withArguments: (Dictionary new
        at: 'ObjectSpecifier' put: spec2;
        yourself).

Transcript show: 'Retrieved value: ', result asString; cr; cr.

"Example 6: Range specifier"
Transcript show: 'Example 6: Range Specifier'; cr.

| startSpec endSpec rangeSpec |

startSpec := bridge
    createSpecifier: 'index'
    inContainer: nil
    forKey: 'documents'
    withValue: 1.

endSpec := bridge
    createSpecifier: 'index'
    inContainer: nil
    forKey: 'documents'
    withValue: 3.

rangeSpec := bridge
    createSpecifier: 'range'
    inContainer: nil
    forKey: 'documents'
    withValue: (Dictionary new
        at: 'start' put: startSpec;
        at: 'end' put: endSpec;
        yourself).

Transcript show: 'Created range specifier for documents 1-3'; cr; cr.

Transcript show: 'Specifier examples complete!'; cr.
