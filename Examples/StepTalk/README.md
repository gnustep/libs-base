# StepTalk Integration Examples

This directory contains examples demonstrating how to use StepTalk with the GNUstep NSScripting framework through the GSScriptingStepTalkBridge.

## Overview

The GSScriptingStepTalkBridge allows StepTalk (Smalltalk-based scripting for GNUstep) to interact with scriptable applications using the NSScripting framework. This provides a powerful, dynamic scripting environment that can control applications supporting Apple Event-style scripting.

## Prerequisites

1. GNUstep Base Library with NSScripting support
2. StepTalk framework installed
3. A scriptable application or test target

## Examples

### 1. Basic Command Execution (basic-commands.st)

Demonstrates how to:

- Get the shared bridge instance
- Create and execute simple commands
- Work with command results

### 2. Object Specifiers (object-specifiers.st)

Shows how to:

- Build object specifiers for targeting specific objects
- Chain specifiers for nested objects
- Use different specifier types (index, name, property)

### 3. Complete Application Control (app-control.st)

Demonstrates:

- Creating new objects in an application
- Getting and setting properties
- Querying object counts
- Deleting objects

## Running the Examples

From StepTalk:

```smalltalk
"Load a script file"
Transcript loadScript: 'basic-commands.st'
```

Or execute StepTalk code directly in your application.

## Integration Pattern

The typical pattern for using the bridge is:

1. Get the shared bridge instance
2. Create object specifiers to identify target objects
3. Create commands with appropriate arguments
4. Execute commands and handle results
5. Check for errors in command execution

## See Also

- GSScriptingStepTalkBridge.h - Bridge interface documentation
- NSScriptCommand.h - Command execution
- NSScriptObjectSpecifier.h - Object specification
- StepTalk documentation
