# GNUstep Base API Gap Audit

**Audit date:** 2026-07-21  
**Repository examined:** `gnustep/libs-base`, commit `6307e474d` (1.31.1)  
**Modern comparison target:** the locally installed macOS 26.2 SDK, Foundation.framework headers

## Scope and method

This is an API-surface audit of GNUstep Base, not a conformance or performance
test.  GNUstep Base is the non-graphical Foundation-layer library; AppKit and
the rest of Cocoa are outside this repository's scope.  Consequently, the
macOS/Cocoa findings below compare **Foundation.framework** only.  The
OpenStep comparison is against the [October 1994 OpenStep Specification]
(https://www.gnustep.org/resources/OpenStepSpec/OpenStepSpec.html), specifically
its [Foundation class index](https://www.gnustep.org/resources/OpenStepSpec/FoundationKit/Classes/index.html).

The audit used the public headers in `Headers/Foundation`, searched the source
tree for implementations, and compared header filenames against
`Foundation.framework/Headers` in the macOS 26.2 SDK.  A missing header/class is
definitive.  A selector that is listed as missing was searched in the public
Foundation headers; it may not exist in this repository as a private or
GNUstep-extension API under another name.  Absence of a name alone does not
establish an equivalent feature is absent.

## Executive summary

* **OpenStep Foundation:** 49 of 53 specified classes are represented.  The
  four missing classes form one legacy subsystem: persistent/memory byte stores
  and their B-tree helper classes.  Therefore every public method on those
  classes is also absent.  The historical in-tree compliance document reaches
  the same class-level result, but labels itself a 2005 best guess.
* **Current macOS Foundation:** the tree exposes 167 top-level Foundation
  headers, compared with 172 in the macOS 26.2 SDK.  Nine SDK headers/classes
  are absent; four GNUstep headers have no same-named Apple header.  The main
  gaps are collection-diffing, grammar-aware localization/inflection, list and
  relative-date formatting, and newer KVO registration sharing.
* **Compatibility position:** GNUstep Base has broad historical Foundation
  coverage and many later Cocoa APIs, but is not source-complete with macOS
  26.2 Foundation.  It also cannot, by itself, provide Cocoa compatibility:
  applications using AppKit, Core Foundation, CFNetwork, Security, Swift-only
  APIs, or Apple services require other frameworks or a porting layer.

## OpenStep Foundation gaps

The OpenStep Foundation specification enumerates 53 classes.  The following
four do not have a public header or implementation in this tree.  All other
OpenStep Foundation classes listed in the specification are present in
`Headers/Foundation`; this agrees with the repository's historical
`Documentation/General/OpenStepCompliance.gsdoc` inventory.

| Missing class | Purpose in OpenStep | Missing public API |
| --- | --- | --- |
| `NSByteStore` | Transactional, relocatable, memory-backed blocks | All selectors in the next table |
| `NSByteStoreFile` | File-backed `NSByteStore` with transactional integrity | All selectors in the next table |
| `NSBTreeBlock` | Ordered key/value B-tree storage in a byte store | All selectors in the next table |
| `NSBTreeCursor` | Cursor used to position, read, write, and delete B-tree values | All selectors in the next table |

### Missing OpenStep methods

The selectors below are transcribed from the specification pages for
[NSByteStore](https://www.gnustep.org/resources/OpenStepSpec/FoundationKit/Classes/NSByteStore.html),
[NSByteStoreFile](https://www.gnustep.org/resources/OpenStepSpec/FoundationKit/Classes/NSByteStoreFile.html),
[NSBTreeBlock](https://www.gnustep.org/resources/OpenStepSpec/FoundationKit/Classes/NSBTreeBlock.html),
and [NSBTreeCursor](https://www.gnustep.org/resources/OpenStepSpec/FoundationKit/Classes/NSBTreeCursor.html).
Because their declaring header, `Foundation/NSByteStore.h`, is absent, this is
the complete public method gap for the four absent classes.

| Class | Missing class methods | Missing instance methods |
| --- | --- | --- |
| `NSByteStore` | `+byteStore` | `-count`, `-empty`, `-getBlocks:`, `-rootBlock`, `-createBlockOfSize:`, `-copyBlock:range:`, `-freeBlock:`, `-openBlock:range:`, `-readBlock:range:`, `-closeBlock:`, `-resizeBlock:toSize:`, `-sizeOfBlock:`, `-startTransaction`, `-abortTransaction`, `-commitTransaction`, `-areTransactionsEnabled`, `-nestingLevel`, `-changeCount`, `-copyBytes:toBlock:range:`, `-contentsAsData`, `-replaceContentsWithData:` |
| `NSByteStoreFile` | `+byteStoreFile:transactionsEnabled:create:readOnly:` | `-initWithPath:transactionsEnabled:create:readOnly:`, `-storePath`, `-compactUntilDate:` |
| `NSBTreeBlock` | `+btreeBlockWithStore:`, `+btreeBlockWithStore:block:` | `-initWithStore:`, `-initWithStore:block:`, `-byteStore`, `-storeBlock`, `-setComparator:context:`, `-count`, `-removeAllObjects` |
| `NSBTreeCursor` | `+bTreeCursorWithBTree:` | `-initWithBTree:`, `-btree`, `-moveCursorToFirstKey`, `-moveCursorToLastKey`, `-moveCursorToNextKey`, `-moveCursorToPreviousKey`, `-moveCursorToKey:`, `-isOnKey`, `-cursorKey`, `-cursorValue`, `-cursorValueWithRange:`, `-writeValue:`, `-writeValue:atIndex:`, `-removeValue` |

This gap is low impact for ordinary modern Foundation applications: these
classes were a specialized OpenStep persistence API and have no modern Cocoa
counterpart.  It matters for strict OpenStep source compatibility or software
that specifically used `NSByteStore.h`.

## macOS 26.2 Foundation gaps

### Missing headers and classes

The following macOS SDK public headers are absent from `Headers/Foundation`.
Names and availability are from the macOS 26.2 SDK headers.  A header-level
gap is not necessarily a feature gap where an older GNUstep API supplies an
alternative, but there is no source-compatible declaration with the Apple
name.

| macOS header | Missing type(s) / capability | Earliest macOS availability |
| --- | --- | --- |
| `NSInflectionRule.h` | `NSInflectionRule`, `NSInflectionRuleExplicit`; inflection rules for attributed strings | 12.0 |
| `NSKeyValueSharedObservers.h` | `NSKeyValueSharedObservers`, `NSKeyValueSharedObserversSnapshot`; reusable KVO registrations | 15.0 |
| `NSListFormatter.h` | `NSListFormatter`; locale-aware list joining | 10.15 |
| `NSLocalizedNumberFormatRule.h` | `NSLocalizedNumberFormatRule`; automatic number-inflection rule | 12.0 |
| `NSMorphology.h` | `NSMorphology`, `NSMorphologyPronoun`, `NSMorphologyCustomPronoun`; grammatical gender, number, case, pronoun and custom-pronoun data | 12.0 (some properties 14.0) |
| `NSOrderedCollectionChange.h` | `NSOrderedCollectionChange`; one insertion/removal in a collection diff | 10.15 |
| `NSOrderedCollectionDifference.h` | `NSOrderedCollectionDifference`; ordered collection differences and transforms | 10.15 |
| `NSRelativeDateTimeFormatter.h` | `NSRelativeDateTimeFormatter`; localized relative time output | 10.15 |
| `NSTermOfAddress.h` | `NSTermOfAddress`; localized grammatical term-of-address data | 15.0 |

The macOS SDK headers also contain `NSKeyValueSharedObserversSnapshot` even
though the filename is `NSKeyValueSharedObservers.h`; it is counted here as a
missing class rather than a separate missing header.

### Verified missing selectors on existing GNUstep classes

These selectors are declared by macOS 26.2 Foundation on classes that GNUstep
Base already has, and are absent from the corresponding GNUstep public headers.

| GNUstep class | Missing macOS selector(s) | Consequence |
| --- | --- | --- |
| `NSArray` | `-differenceFromArray:`, `-differenceFromArray:withOptions:`, `-differenceFromArray:withOptions:usingEquivalenceTest:` | No source-compatible generation of Apple ordered collection differences |
| `NSMutableArray` | `-applyDifference:` | Cannot apply an Apple ordered collection difference |
| `NSOrderedSet` | `-applyDifference:` | Same collection-diff application gap |
| `NSString` | `-localizedStandardRangeOfString:`, `-localizedStandardContainsString:`, `-stringByApplyingTransform:reverse:` | Missing Apple’s standard user-facing search and transliteration entry points |
| `NSAttributedString` | `-attributedStringByInflectingString` and the inflection-rule attribute API | Cannot use macOS grammatical inflection workflow |
| `NSObject` | `-setSharedObservers:` | Cannot install the macOS 15 shared KVO observer snapshot |

The missing-class headers add their own selector surface.  The highest-value
entry points are `+[NSListFormatter localizedStringByJoiningStrings:]`,
`-stringFromItems:`, `-localizedStringFromTimeInterval:`,
`-localizedStringForDate:relativeToDate:`, the `NSMorphology` properties and
custom-pronoun methods, `+[NSInflectionRule automaticRule]`, and
`-[NSKeyValueSharedObservers addSharedObserver:forKey:options:context:]`.

### Differences that are not deficits

* GNUstep has four top-level headers with no same-named macOS Foundation header:
  `NSErrorRecoveryAttempting.h`, `NSInvocationOperation.h`,
  `NSSerialization.h`, and `NSUtilities.h`.  This is not evidence of excess or
  incompatibility: Apple may place comparable declarations elsewhere or not
  publish an equivalent header.
* The repository already includes many post-OpenStep Foundation facilities,
  including URL loading/session APIs, XML, JSON, predicates, operations,
  regular expressions, progress, units, and item providers.  The result should
  not be read as “OpenStep-only.”
* The repository supports API visibility controls and runtime behavior options
  for different OpenStep/macOS-era targets (`GS_OPENSTEP_V`, `STRICT_OPENSTEP`,
  and `GSMacOSXCompatible`).  These help porting, but do not add the absent
  macOS 26.2 declarations or implementations.

## Assessment and priorities

### Interoperability assessment

For classic Objective-C Foundation code, GNUstep Base remains substantially
compatible with the OpenStep surface and covers a broad portion of later Cocoa
Foundation.  The strongest modern incompatibilities are in locale-sensitive
language features and collection-diffing, rather than the original Foundation
object, collection, coding, run-loop, or distributed-object foundations.

For code targeting current macOS, this library should be treated as a
**portable Foundation implementation with selective Cocoa compatibility**, not
as a drop-in replacement for the macOS 26.2 SDK.  Source that relies only on
the common Foundation subset can be portable; source using the APIs in the
tables needs availability guards, a compatibility shim, or an implementation
in GNUstep Base.

### Recommended remediation order

1. Implement `NSOrderedCollectionChange` and
   `NSOrderedCollectionDifference`, then the `NSArray`, `NSMutableArray`, and
   `NSOrderedSet` bridge selectors.  This is a bounded, useful modern API unit.
2. Add `NSListFormatter` and `NSRelativeDateTimeFormatter`, preferably backed
   by ICU where configured, to improve common localized UI text.
3. Add morphology/inflection classes and attributed-string integration.  This
   has a larger linguistic-data and platform-behavior dependency; begin with
   the public data model and availability-gated stubs only if complete behavior
   cannot be supplied.
4. Add shared KVO observers after confirming desired KVO semantics and
   lifetime/threading behavior.
5. Do not prioritize the legacy OpenStep byte-store/B-tree cluster unless a
   downstream project needs strict `NSByteStore.h` compatibility.  A separate
   compatibility module may be preferable to burdening the general Foundation
   implementation.

## Evidence and limitations

* The current macOS comparison uses the installed **macOS 26.2 SDK**, not a
  runtime probe; availability is compile-time SDK availability.
* Apple’s current [macOS 26 release notes]
  (https://developer.apple.com/documentation/macos-release-notes/macos-26-release-notes?changes=_4)
  describe the SDK as the current platform release and include Foundation
  changes.  They do not serve as a complete API reference, hence the direct
  header comparison.
* This audit intentionally does not claim behavioral, ABI, ARC, Swift
  overlay, locale-data, security, or framework-link compatibility.  Those
  require targeted tests on each supported platform.
* The existing `Documentation/General/OpenStepCompliance.gsdoc` is useful
  corroboration, but its own text says it was a best guess and dates from 2005;
  this document records what is present in this checkout today.
