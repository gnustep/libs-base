#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSString.h>

#if defined(__has_extension) && __has_extension(blocks)
int main (int argc, const char * argv[])
{
  NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
  START_SET("Enumerate substrings by lines");

  NSString* s1 = @"Line 1\nLine 2";
  __block NSUInteger currentIteration = 0;
  [s1 enumerateSubstringsInRange:(NSRange){
    .location = 0,
    .length = [s1 length]
  }                      options: NSStringEnumerationByLines 
                      usingBlock: ^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
    NSLog(@"Substring range: {.location=%ld, .length=%ld}", substringRange.location, substringRange.length);
    NSLog(@"Enclosing range: {.location=%ld, .length=%ld}", enclosingRange.location, enclosingRange.length);
    NSLog(@"Substring: %@", substring);
    // *stop = YES;
    if(currentIteration == 0) PASS([substring isEqual: @"Line 1"], "First line of \"Line 1\\nLine 2\" is \"Line 1\"");
    if(currentIteration == 1) PASS([substring isEqual: @"Line 2"], "Second line of \"Line 1\\nLine 2\" is \"Line 2\"");
    currentIteration++;
  }]; 
  PASS(currentIteration == 2, "There are only two lines in \"Line 1\\nLine 2\"");
  END_SET("Enumerate substrings by lines");

  START_SET("Enumerate substrings by paragraphs");

  NSString* s1 = @"Paragraph 1\nParagraph 2";
  __block NSUInteger currentIteration = 0;
  [s1 enumerateSubstringsInRange:(NSRange){
    .location = 0,
    .length = [s1 length]
  }                      options: NSStringEnumerationByParagraphs 
                      usingBlock: ^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
    NSLog(@"Substring range: {.location=%ld, .length=%ld}", substringRange.location, substringRange.length);
    NSLog(@"Enclosing range: {.location=%ld, .length=%ld}", enclosingRange.location, enclosingRange.length);
    NSLog(@"Substring: %@", substring);
    // *stop = YES;
    if(currentIteration == 0) PASS([substring isEqual: @"Paragraph 1"], "First paragraph of \"Paragraph 1\\nParagraph 2\" is \"Paragraph 1\"");
    if(currentIteration == 1) PASS([substring isEqual: @"Paragraph 2"], "Second paragraph of \"Paragraph 1\\nParagraph 2\" is \"Paragraph 2\"");
    currentIteration++;
  }]; 
  PASS(currentIteration == 2, "There are only two paragraphs in \"Paragraph 1\\nParagraph 2\"");
  END_SET("Enumerate substrings by paragraphs");

  START_SET("Enumerate substrings by words");

  NSString* s1 = @"Word1 word2.";
  __block NSUInteger currentIteration = 0;
  [s1 enumerateSubstringsInRange:(NSRange){
    .location = 0,
    .length = [s1 length]
  }                      options: NSStringEnumerationByWords
                      usingBlock: ^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
    NSLog(@"Substring range: {.location=%ld, .length=%ld}", substringRange.location, substringRange.length);
    NSLog(@"Enclosing range: {.location=%ld, .length=%ld}", enclosingRange.location, enclosingRange.length);
    NSLog(@"Substring: %@", substring);
    // *stop = YES;
    if(currentIteration == 0) PASS([substring isEqual: @"Word1"], "First word of \"Word1 word2.\" is \"Word1\"");
    if(currentIteration == 1) PASS([substring isEqual: @"word2"], "Second word of \"Word1 word2.\" is \"word2\"");
    currentIteration++;
  }]; 
  PASS(currentIteration == 2, "There are only two words in \"Word1 word2.\"");
  END_SET("Enumerate substrings by words");

  START_SET("Enumerate substrings by sentences");

  NSString* s1 = @"Sentence 1. Sentence 2.";
  __block NSUInteger currentIteration = 0;
  [s1 enumerateSubstringsInRange:(NSRange){
    .location = 0,
    .length = [s1 length]
  }                      options: NSStringEnumerationBySentences
                      usingBlock: ^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
    NSLog(@"Substring range: {.location=%ld, .length=%ld}", substringRange.location, substringRange.length);
    NSLog(@"Enclosing range: {.location=%ld, .length=%ld}", enclosingRange.location, enclosingRange.length);
    NSLog(@"Substring: %@", substring);
    // *stop = YES;
    if(currentIteration == 0) PASS([substring isEqual: @"Sentence 1. "], "First sentence of \"Sentence 1. Sentence 2.\" is \"Sentence 1. \"");
    if(currentIteration == 1) PASS([substring isEqual: @"Sentence 2."], "Second sentence of \"Sentence 1. Sentence 2.\" is \"Sentence 2.\"");
    currentIteration++;
  }]; 
  PASS(currentIteration == 2, "There are only two sentences in \"Sentence 1. Sentence 2.");
  END_SET("Enumerate substrings by sentences");

  [pool drain];
  
  return 0;
}
#else
int main (int argc, const char * argv[])
{
  return 0;
}
#endif