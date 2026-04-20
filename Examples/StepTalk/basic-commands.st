"============================================
 Basic Commands Example
 Demonstrates simple command execution using
 the GSScriptingStepTalkBridge
============================================"

| bridge command result |

"Get the shared bridge instance"
bridge := GSScriptingStepTalkBridge sharedBridge.

Transcript show: 'StepTalk NSScripting Bridge Example'; cr.
Transcript show: '===================================='; cr; cr.

"Example 1: Execute a get command"
Transcript show: 'Example 1: Simple Get Command'; cr.
command := bridge 
    createCommand: 'get'
    forSuite: 'CoreSuite'
    withArguments: nil.

result := command executeCommand.
Transcript show: 'Command executed, result: ', result asString; cr; cr.

"Example 2: Execute a count command"
Transcript show: 'Example 2: Count Command'; cr.
result := bridge 
    executeCommand: 'count'
    forSuite: 'CoreSuite'
    withArguments: (Dictionary new
        at: 'ObjectClass' put: 'document';
        yourself).

Transcript show: 'Document count: ', result asString; cr; cr.

"Example 3: Check command errors"
Transcript show: 'Example 3: Error Handling'; cr.
command := bridge
    createCommand: 'nonexistent'
    forSuite: 'CoreSuite'
    withArguments: nil.

result := command executeCommand.

(command scriptErrorNumber ~= 0) ifTrue: [
    Transcript show: 'Error occurred: ', 
                     command scriptErrorString; cr.
] ifFalse: [
    Transcript show: 'Command succeeded'; cr.
].

Transcript cr; show: 'Examples complete!'; cr.
