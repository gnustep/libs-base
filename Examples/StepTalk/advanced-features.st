"============================================
 Advanced Features Example
 Demonstrates advanced bridge features like
 custom command handlers and caching
============================================"

| bridge command result handler |

"Get the shared bridge instance"
bridge := GSScriptingStepTalkBridge sharedBridge.

Transcript show: 'Advanced Bridge Features'; cr.
Transcript show: '======================='; cr; cr.

"Example 1: Custom command handler"
Transcript show: 'Example 1: Custom Command Handler'; cr.

"Create a block that handles custom commands"
handler := [:cmd |
    Transcript show: 'Custom handler invoked for command: ', 
                     cmd asString; cr.
    'Custom result from StepTalk'.
].

"Register the handler"
bridge 
    registerCommandHandler: handler
    forCommand: 'myCustomCommand'
    inSuite: 'CustomSuite'.

Transcript show: 'Registered custom command handler'; cr; cr.

"Example 2: Multiple specifier types"
Transcript show: 'Example 2: Using Multiple Specifier Types'; cr.

"Middle specifier"
| middleSpec |
middleSpec := bridge
    createSpecifier: 'middle'
    inContainer: nil
    forKey: 'documents'
    withValue: nil.

Transcript show: 'Created middle specifier'; cr.

"Random specifier"
| randomSpec |
randomSpec := bridge
    createSpecifier: 'random'
    inContainer: nil
    forKey: 'documents'
    withValue: nil.

Transcript show: 'Created random specifier'; cr; cr.

"Example 3: Relative specifiers"
Transcript show: 'Example 3: Relative Specifiers'; cr.

| baseSpec relativeSpec |
baseSpec := bridge
    createSpecifier: 'name'
    inContainer: nil
    forKey: 'documents'
    withValue: 'MyDocument'.

relativeSpec := bridge
    createSpecifier: 'relative'
    inContainer: nil
    forKey: 'documents'
    withValue: (Dictionary new
        at: 'base' put: baseSpec;
        at: 'position' put: 'after';
        yourself).

Transcript show: 'Created relative specifier (document after MyDocument)'; cr; cr.

"Example 4: UniqueID specifier"
Transcript show: 'Example 4: UniqueID Specifier'; cr.

| uidSpec |
uidSpec := bridge
    createSpecifier: 'uniqueID'
    inContainer: nil
    forKey: 'documents'
    withValue: 'DOC-12345'.

Transcript show: 'Created uniqueID specifier'; cr; cr.

"Example 5: Complex command with multiple arguments"
Transcript show: 'Example 5: Complex Command Arguments'; cr.

| locationSpec |
locationSpec := bridge
    createSpecifier: 'position'
    inContainer: nil
    forKey: 'documents'
    withValue: 'end'.

properties := Dictionary new
    at: 'name' put: 'NewDocument';
    at: 'modified' put: false;
    at: 'visible' put: true;
    yourself.

result := bridge
    executeCommand: 'create'
    forSuite: 'CoreSuite'
    withArguments: (Dictionary new
        at: 'ObjectClass' put: 'document';
        at: 'Location' put: locationSpec;
        at: 'WithProperties' put: properties;
        yourself).

Transcript show: 'Created document with complex arguments'; cr; cr.

"Example 6: Batch operations"
Transcript show: 'Example 6: Batch Operations'; cr.

| docs |
docs := Array new: 5.

1 to: 5 do: [:i |
    | docName |
    docName := 'Document', i asString.
    
    docs at: i put: (bridge
        createObject: 'document'
        atLocation: nil
        withProperties: (Dictionary new
            at: 'name' put: docName;
            yourself)).
    
    Transcript show: 'Created ', docName; cr.
].

Transcript show: 'Created 5 documents in batch'; cr; cr.

"Example 7: Query and filter"
Transcript show: 'Example 7: Querying Objects'; cr.

count := bridge countObjects: 'document' inContainer: nil.
Transcript show: 'Total documents: ', count asString; cr.

"Get all documents (this would need a whose specifier in real use)"
Transcript show: 'To filter, use NSWhoseSpecifier in production'; cr; cr.

"Example 8: Clear cache"
Transcript show: 'Example 8: Cache Management'; cr.
bridge clearCache.
Transcript show: 'Cleared bridge cache'; cr; cr.

"Example 9: Error handling patterns"
Transcript show: 'Example 9: Robust Error Handling'; cr.

[
    command := bridge
        createCommand: 'get'
        forSuite: 'CoreSuite'
        withArguments: nil.
    
    result := command executeCommand.
    
    (command scriptErrorNumber = 0) 
        ifTrue: [
            Transcript show: 'Success: ', result asString; cr.
        ]
        ifFalse: [
            Transcript show: 'Error ', 
                           command scriptErrorNumber asString,
                           ': ',
                           command scriptErrorString; cr.
        ].
] on: Error do: [:ex |
    Transcript show: 'Exception caught: ', ex messageText; cr.
].

Transcript cr; show: 'Advanced examples complete!'; cr.
