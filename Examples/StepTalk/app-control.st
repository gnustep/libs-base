"============================================
 Application Control Example
 Demonstrates complete application control
 using the convenience methods
============================================"

| bridge docSpec windowSpec count result properties |

"Get the shared bridge instance"
bridge := GSScriptingStepTalkBridge sharedBridge.

Transcript show: 'Application Control Examples'; cr.
Transcript show: '==========================='; cr; cr.

"Example 1: Count objects"
Transcript show: 'Example 1: Counting Documents'; cr.
count := bridge countObjects: 'document' inContainer: nil.
Transcript show: 'Current document count: ', count asString; cr; cr.

"Example 2: Create a new document"
Transcript show: 'Example 2: Creating New Document'; cr.
properties := Dictionary new
    at: 'name' put: 'UntitledDocument';
    at: 'modified' put: false;
    yourself.

result := bridge 
    createObject: 'document'
    atLocation: nil
    withProperties: properties.

Transcript show: 'Created new document: ', result asString; cr; cr.

"Example 3: Get object by name"
Transcript show: 'Example 3: Getting Object by Name'; cr.
result := bridge 
    getObject: 'UntitledDocument'
    ofType: 'document'
    fromContainer: nil.

Transcript show: 'Retrieved document: ', result asString; cr; cr.

"Example 4: Set a property"
Transcript show: 'Example 4: Setting Property'; cr.
docSpec := bridge
    createSpecifier: 'name'
    inContainer: nil
    forKey: 'documents'
    withValue: 'UntitledDocument'.

bridge 
    setProperty: 'name'
    ofObject: docSpec
    toValue: 'MyDocument'.

Transcript show: 'Changed document name to "MyDocument"'; cr; cr.

"Example 5: Get modified property value"
Transcript show: 'Example 5: Getting Property Value'; cr.
result := bridge 
    getObject: 'name'
    ofType: 'property'
    fromContainer: docSpec.

Transcript show: 'Document name is now: ', result asString; cr; cr.

"Example 6: Count again to verify"
Transcript show: 'Example 6: Verify Count Increased'; cr.
count := bridge countObjects: 'document' inContainer: nil.
Transcript show: 'New document count: ', count asString; cr; cr.

"Example 7: Delete object"
Transcript show: 'Example 7: Deleting Object'; cr.
bridge deleteObject: docSpec.
Transcript show: 'Deleted document'; cr; cr.

"Example 8: Final count"
Transcript show: 'Example 8: Final Count'; cr.
count := bridge countObjects: 'document' inContainer: nil.
Transcript show: 'Final document count: ', count asString; cr; cr.

"Example 9: Working with windows"
Transcript show: 'Example 9: Working with Windows'; cr.
count := bridge countObjects: 'window' inContainer: nil.
Transcript show: 'Window count: ', count asString; cr.

windowSpec := bridge
    createSpecifier: 'index'
    inContainer: nil
    forKey: 'windows'
    withValue: 1.

"Get window name"
result := bridge 
    getObject: 'name'
    ofType: 'property'
    fromContainer: windowSpec.

Transcript show: 'First window name: ', result asString; cr; cr.

"Example 10: Complex nested access"
Transcript show: 'Example 10: Complex Nested Access'; cr.

"Get the third paragraph of the first document"
docSpec := bridge
    createSpecifier: 'index'
    inContainer: nil
    forKey: 'documents'
    withValue: 1.

| paraSpec |
paraSpec := bridge
    createSpecifier: 'index'
    inContainer: docSpec
    forKey: 'paragraphs'
    withValue: 3.

result := bridge
    executeCommand: 'get'
    forSuite: 'CoreSuite'
    withArguments: (Dictionary new
        at: 'ObjectSpecifier' put: paraSpec;
        yourself).

Transcript show: 'Third paragraph: ', result asString; cr; cr.

Transcript show: 'Application control examples complete!'; cr.
