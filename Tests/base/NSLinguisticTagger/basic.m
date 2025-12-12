#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSLinguisticTagger.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSOrthography.h>

int main()
{
  NSLinguisticTagger *tagger;
  NSArray *schemes;
  NSArray *tags;
  NSArray *ranges;
  NSString *text;
  NSString *language;
  NSRange range;
  NSRange effectiveRange;
  NSLinguisticTag tag;
  NSOrthography *orthography;
  __block int enumerationCount;

  START_SET("NSLinguisticTagger basic");

  // Test instance creation
  schemes = [NSArray arrayWithObjects:
    NSLinguisticTagSchemeTokenType,
    NSLinguisticTagSchemeLexicalClass,
    nil];
  tagger = AUTORELEASE([[NSLinguisticTagger alloc] initWithTagSchemes: schemes
                                                               options: 0]);
  PASS(tagger != nil, "Can create NSLinguisticTagger instance");

  // Test tag schemes
  PASS([tagger tagSchemes] != nil, "Tag schemes property works");
  PASS([[tagger tagSchemes] count] == 2, "Tag schemes count correct");

  // Test string property
  text = @"Hello world!";
  [tagger setString: text];
  PASS([[tagger string] isEqual: text], "String property works");

  // Test available tag schemes for unit
  schemes = [NSLinguisticTagger availableTagSchemesForUnit: NSLinguisticTaggerUnitWord
                                                   language: @"en"];
  PASS(schemes != nil && [schemes count] > 0,
       "availableTagSchemesForUnit:language: returns schemes");

  // Test available tag schemes for language
  schemes = [NSLinguisticTagger availableTagSchemesForLanguage: @"en"];
  PASS(schemes != nil && [schemes count] > 0,
       "availableTagSchemesForLanguage: returns schemes");

  // Test dominant language detection
  language = [NSLinguisticTagger dominantLanguageForString: @"Hello world"];
  PASS(language != nil, "dominantLanguageForString: returns language");

  language = [tagger dominantLanguage];
  PASS(language != nil, "dominantLanguage property works");

  END_SET("NSLinguisticTagger basic");

  START_SET("NSLinguisticTagger tokenization");

  // Test token range detection
  schemes = [NSArray arrayWithObjects:
    NSLinguisticTagSchemeTokenType,
    NSLinguisticTagSchemeLexicalClass,
    nil];
  tagger = AUTORELEASE([[NSLinguisticTagger alloc] initWithTagSchemes: schemes
                                                               options: 0]);
  text = @"Hello world!";
  [tagger setString: text];

  range = [tagger tokenRangeAtIndex: 0 unit: NSLinguisticTaggerUnitWord];
  PASS(range.location == 0 && range.length == 5,
       "Token range at start of string (Hello)");

  range = [tagger tokenRangeAtIndex: 6 unit: NSLinguisticTaggerUnitWord];
  PASS(range.location == 6 && range.length == 5,
       "Token range in middle of string (world)");

  range = [tagger tokenRangeAtIndex: 11 unit: NSLinguisticTaggerUnitWord];
  PASS(range.location == 11 && range.length == 1,
       "Token range for punctuation (!)");

  // Test sentence range detection
  text = @"Hello world! How are you?";
  [tagger setString: text];

  range = [tagger sentenceRangeForRange: NSMakeRange(0, 0)];
  PASS(range.location == 0 && range.length > 0,
       "Sentence range from beginning");

  range = [tagger sentenceRangeForRange: NSMakeRange(15, 0)];
  PASS(range.location > 0,
       "Sentence range for second sentence");

  END_SET("NSLinguisticTagger tokenization");

  START_SET("NSLinguisticTagger tagging");

  schemes = [NSArray arrayWithObjects:
    NSLinguisticTagSchemeTokenType,
    NSLinguisticTagSchemeLexicalClass,
    nil];
  tagger = AUTORELEASE([[NSLinguisticTagger alloc] initWithTagSchemes: schemes
                                                               options: 0]);
  text = @"The quick brown fox.";
  [tagger setString: text];

  // Test tag at index
  tag = [tagger tagAtIndex: 0
                      unit: NSLinguisticTaggerUnitWord
                    scheme: NSLinguisticTagSchemeTokenType
                tokenRange: NULL];
  PASS(tag != nil, "tagAtIndex:unit:scheme:tokenRange: returns tag");

  // Test with token range
  tag = [tagger tagAtIndex: 0
                      unit: NSLinguisticTaggerUnitWord
                    scheme: NSLinguisticTagSchemeTokenType
                tokenRange: &range];
  PASS(tag != nil && range.location != NSNotFound,
       "tagAtIndex with tokenRange output works");

  // Test tags in range
  tags = [tagger tagsInRange: NSMakeRange(0, [text length])
                         unit: NSLinguisticTaggerUnitWord
                       scheme: NSLinguisticTagSchemeTokenType
                      options: 0
                  tokenRanges: NULL];
  PASS(tags != nil && [tags count] > 0,
       "tagsInRange:unit:scheme:options:tokenRanges: returns tags");

  // Test with token ranges output
  ranges = nil;
  tags = [tagger tagsInRange: NSMakeRange(0, [text length])
                         unit: NSLinguisticTaggerUnitWord
                       scheme: NSLinguisticTagSchemeTokenType
                      options: 0
                  tokenRanges: &ranges];
  PASS(ranges != nil && [ranges count] == [tags count],
       "Token ranges output matches tag count");

  // Test lexical class scheme
  tag = [tagger tagAtIndex: 19
                      unit: NSLinguisticTaggerUnitWord
                    scheme: NSLinguisticTagSchemeLexicalClass
                tokenRange: NULL];
  PASS(tag != nil, "LexicalClass scheme returns tag");

  END_SET("NSLinguisticTagger tagging");

  START_SET("NSLinguisticTagger enumeration");

  schemes = [NSArray arrayWithObjects:
    NSLinguisticTagSchemeTokenType,
    NSLinguisticTagSchemeLexicalClass,
    nil];
  tagger = AUTORELEASE([[NSLinguisticTagger alloc] initWithTagSchemes: schemes
                                                               options: 0]);
  text = @"Hello world!";
  [tagger setString: text];

  enumerationCount = 0;
  [tagger enumerateTagsInRange: NSMakeRange(0, [text length])
                           unit: NSLinguisticTaggerUnitWord
                         scheme: NSLinguisticTagSchemeTokenType
                        options: 0
                     usingBlock: ^(NSLinguisticTag t, NSRange r, BOOL *stop) {
    enumerationCount++;
  }];
  PASS(enumerationCount > 0, "Enumeration with block works");

  // Test enumeration with options
  enumerationCount = 0;
  [tagger enumerateTagsInRange: NSMakeRange(0, [text length])
                           unit: NSLinguisticTaggerUnitWord
                         scheme: NSLinguisticTagSchemeTokenType
                        options: NSLinguisticTaggerOmitPunctuation
                     usingBlock: ^(NSLinguisticTag t, NSRange r, BOOL *stop) {
    enumerationCount++;
  }];
  PASS(enumerationCount >= 2, "Enumeration with OmitPunctuation works");

  // Test enumeration stop
  enumerationCount = 0;
  [tagger enumerateTagsInRange: NSMakeRange(0, [text length])
                           unit: NSLinguisticTaggerUnitWord
                         scheme: NSLinguisticTagSchemeTokenType
                        options: 0
                     usingBlock: ^(NSLinguisticTag t, NSRange r, BOOL *stop) {
    enumerationCount++;
    *stop = YES;
  }];
  PASS(enumerationCount == 1, "Enumeration stops when stop is set");

  END_SET("NSLinguisticTagger enumeration");

  START_SET("NSLinguisticTagger class methods");

  text = @"The quick brown fox.";
  range = NSMakeRange(0, [text length]);

  // Test class method for single tag
  tag = [NSLinguisticTagger tagForString: text
                                 atIndex: 0
                                    unit: NSLinguisticTaggerUnitWord
                                  scheme: NSLinguisticTagSchemeTokenType
                             orthography: nil
                              tokenRange: NULL];
  PASS(tag != nil, "Class method tagForString:atIndex:... works");

  // Test class method for tags array
  tags = [NSLinguisticTagger tagsForString: text
                                     range: range
                                      unit: NSLinguisticTaggerUnitWord
                                    scheme: NSLinguisticTagSchemeTokenType
                                   options: 0
                               orthography: nil
                               tokenRanges: NULL];
  PASS(tags != nil && [tags count] > 0,
       "Class method tagsForString:range:... works");

  // Test class enumeration method
  enumerationCount = 0;
  [NSLinguisticTagger enumerateTagsForString: text
                                       range: range
                                        unit: NSLinguisticTaggerUnitWord
                                      scheme: NSLinguisticTagSchemeTokenType
                                     options: 0
                                 orthography: nil
                                  usingBlock: ^(NSLinguisticTag t, NSRange r, BOOL *stop) {
    enumerationCount++;
  }];
  PASS(enumerationCount > 0, "Class enumeration method works");

  END_SET("NSLinguisticTagger class methods");

  START_SET("NSLinguisticTagger orthography");

  schemes = [NSArray arrayWithObjects:
    NSLinguisticTagSchemeTokenType,
    NSLinguisticTagSchemeLexicalClass,
    nil];
  tagger = AUTORELEASE([[NSLinguisticTagger alloc] initWithTagSchemes: schemes
                                                               options: 0]);
  text = @"Hello world!";
  [tagger setString: text];

  // Test orthography setting
  orthography = [NSOrthography orthographyWithDominantScript: @"Latn"
                                                 languageMap: [NSDictionary dictionaryWithObject: [NSArray arrayWithObject: @"en"]
                                                                                          forKey: @"Latn"]];
  if (orthography != nil)
    {
      [tagger setOrthography: orthography range: NSMakeRange(0, [text length])];
      
      orthography = [tagger orthographyAtIndex: 0 effectiveRange: &effectiveRange];
      PASS(orthography != nil, "setOrthography:range: and orthographyAtIndex:effectiveRange: work");
    }
  else
    {
      SKIP("NSOrthography creation not available");
    }

  END_SET("NSLinguisticTagger orthography");

  START_SET("NSLinguisticTagger NSString category");

  text = @"Hello world!";
  range = NSMakeRange(0, [text length]);

  // Test NSString category method
  tags = [text linguisticTagsInRange: range
                               scheme: NSLinguisticTagSchemeTokenType
                              options: 0
                          orthography: nil
                          tokenRanges: NULL];
  PASS(tags != nil && [tags count] > 0,
       "NSString linguisticTagsInRange:... works");

  // Test NSString enumeration
  enumerationCount = 0;
  [text enumerateLinguisticTagsInRange: range
                                 scheme: NSLinguisticTagSchemeTokenType
                                options: 0
                            orthography: nil
                             usingBlock: ^(NSLinguisticTag t, NSRange r, NSRange s, BOOL *stop) {
    enumerationCount++;
  }];
  PASS(enumerationCount > 0,
       "NSString enumerateLinguisticTagsInRange:... works");

  END_SET("NSLinguisticTagger NSString category");

  return 0;
}
