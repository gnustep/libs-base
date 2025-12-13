/* Implementation of class NSLinguisticTagger
   Copyright (C) 2019 Free Software Foundation, Inc.
   
   By: Gregory John Casamento <greg.casamento@#gmail.com>
   Date: Sat Nov  2 21:37:50 EDT 2019

   This file is part of the GNUstep Library.
   
   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
*/

#import "Foundation/NSLinguisticTagger.h"
#import "Foundation/NSRange.h"
#import "Foundation/NSString.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSOrthography.h"
#import "Foundation/NSCharacterSet.h"
#import "Foundation/NSValue.h"
#import "Foundation/NSLocale.h"
#import "GNUstepBase/NSObject+GNUstepBase.h"

// Helper function to detect if character is sentence terminator
static BOOL isSentenceTerminator(unichar c)
{
  return (c == '.' || c == '!' || c == '?' || c == 0x3002 || c == 0xFF01 || c == 0xFF1F);
}

// Helper function to determine token type
static NSLinguisticTag tokenTypeForCharacter(unichar c)
{
  if ([[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember: c])
    return NSLinguisticTagWhitespace;
  if ([[NSCharacterSet punctuationCharacterSet] characterIsMember: c])
    return NSLinguisticTagPunctuation;
  if ([[NSCharacterSet alphanumericCharacterSet] characterIsMember: c])
    return NSLinguisticTagWord;
  return NSLinguisticTagOther;
}


NSLinguisticTagScheme const NSLinguisticTagSchemeTokenType = @"NSLinguisticTagSchemeTokenType";
NSLinguisticTagScheme const NSLinguisticTagSchemeLexicalClass = @"NSLinguisticTagSchemeLexicalClass";
NSLinguisticTagScheme const NSLinguisticTagSchemeNameType = @"NSLinguisticTagSchemeNameType";
NSLinguisticTagScheme const NSLinguisticTagSchemeNameTypeOrLexicalClass = @"NSLinguisticTagSchemeNameTypeOrLexicalClass";
NSLinguisticTagScheme const NSLinguisticTagSchemeLemma = @"NSLinguisticTagSchemeLemma";
NSLinguisticTagScheme const NSLinguisticTagSchemeLanguage = @"NSLinguisticTagSchemeLanguage";
NSLinguisticTagScheme const NSLinguisticTagSchemeScript = @"NSLinguisticTagSchemeScript";

/* Tags for NSLinguisticTagSchemeTokenType */
NSLinguisticTag const NSLinguisticTagWord = @"NSLinguisticTagWord";                          
NSLinguisticTag const NSLinguisticTagPunctuation = @"NSLinguisticTagPunctuation";                   
NSLinguisticTag const NSLinguisticTagWhitespace = @"NSLinguisticTagWhitespae";                    
NSLinguisticTag const NSLinguisticTagOther = @"NSLinguisticTagOther";

/* Tags for NSLinguisticTagSchemeLexicalClass */
NSLinguisticTag const NSLinguisticTagNoun = @"NSLinguisticTagNoun";
NSLinguisticTag const NSLinguisticTagVerb = @"NSLinguisticTagVerb";  
NSLinguisticTag const NSLinguisticTagAdjective = @"NSLinguisticTagAdjective";  
NSLinguisticTag const NSLinguisticTagAdverb  = @"NSLinguisticTagAdverb";  
NSLinguisticTag const NSLinguisticTagPronoun = @"NSLinguisticTagPronoun";  
NSLinguisticTag const NSLinguisticTagDeterminer  = @"NSLinguisticTagDeterminer";  
NSLinguisticTag const NSLinguisticTagParticle  = @"NSLinguisticTagParticle";  
NSLinguisticTag const NSLinguisticTagPreposition  = @"NSLinguisticTagPrepostion";  
NSLinguisticTag const NSLinguisticTagNumber  = @"NSLinguisticTagNumber";  
NSLinguisticTag const NSLinguisticTagConjunction  = @"NSLinguisticTagConjunction";  
NSLinguisticTag const NSLinguisticTagInterjection  = @"NSLinguisticTagInterjection";  
NSLinguisticTag const NSLinguisticTagClassifier  = @"NSLinguisticTagClassifier";  
NSLinguisticTag const NSLinguisticTagIdiom = @"NSLinguisticTagIdiom";  
NSLinguisticTag const NSLinguisticTagOtherWord = @"NSLinguisticTagOtherWord";  
NSLinguisticTag const NSLinguisticTagSentenceTerminator = @"NSLinguisticTagSentenceTerminator";  
NSLinguisticTag const NSLinguisticTagOpenQuote = @"NSLinguisticTagOpenQuote";  
NSLinguisticTag const NSLinguisticTagCloseQuote = @"NSLinguisticTagCloseQuote";  
NSLinguisticTag const NSLinguisticTagOpenParenthesis = @"NSLinguisticTagOpenParenthesis";  
NSLinguisticTag const NSLinguisticTagCloseParenthesis = @"NSLinguisticTagCloseParenthesis";  
NSLinguisticTag const NSLinguisticTagWordJoiner = @"NSLinguisticTagWordJoiner";  
NSLinguisticTag const NSLinguisticTagDash = @"NSLinguisticTagDash";  
NSLinguisticTag const NSLinguisticTagOtherPunctuation = @"NSLinguisticTagOtherPunctuation";  
NSLinguisticTag const NSLinguisticTagParagraphBreak = @"NSLinguisticTagParagraphBreak";  
NSLinguisticTag const NSLinguisticTagOtherWhitespace = @"NSLinguisticTagOtherWhitespace";  

/* Tags for NSLinguisticTagSchemeNameType */
NSLinguisticTag const NSLinguisticTagPersonalName = @"NSLinguisticTagPersonalName";  
NSLinguisticTag const NSLinguisticTagPlaceName = @"NSLinguisticTagPlaceName";  
NSLinguisticTag const NSLinguisticTagOrganizationName = @"NSLinguisticTagOrganizationName";  

@implementation NSLinguisticTagger

- (instancetype) initWithTagSchemes: (NSArray *)tagSchemes
                            options: (NSUInteger)opts
{
  self = [super init];
  if (self != nil)
    {
      ASSIGNCOPY(_schemes, tagSchemes);
      _options = opts;
      _string = nil;
      _dominantLanguage = nil;
      _tokenArray = nil;
      _orthographyArray = nil;
    }
  return self; 
}

- (void) dealloc
{
  RELEASE(_schemes);
  RELEASE(_string);
  RELEASE(_dominantLanguage);
  RELEASE(_tokenArray);
  RELEASE(_orthographyArray);
  [super dealloc];
}

- (NSArray *) tagSchemes
{
  return _schemes;
}

- (NSString *) string
{
  return _string;
}

- (void) setString: (NSString *)string
{
  ASSIGNCOPY(_string, string);
}
  
+ (NSArray *) availableTagSchemesForUnit: (NSLinguisticTaggerUnit)unit
                                language: (NSString *)language
{
  // Basic implementation - return commonly supported schemes
  NSMutableArray *schemes = [NSMutableArray array];
  
  [schemes addObject: NSLinguisticTagSchemeTokenType];
  [schemes addObject: NSLinguisticTagSchemeLexicalClass];
  
  if (unit == NSLinguisticTaggerUnitWord || unit == NSLinguisticTaggerUnitSentence)
    {
      [schemes addObject: NSLinguisticTagSchemeNameType];
      [schemes addObject: NSLinguisticTagSchemeNameTypeOrLexicalClass];
      [schemes addObject: NSLinguisticTagSchemeLemma];
    }
  
  [schemes addObject: NSLinguisticTagSchemeLanguage];
  [schemes addObject: NSLinguisticTagSchemeScript];
  
  return schemes;
}

+ (NSArray *) availableTagSchemesForLanguage: (NSString *)language
{
  // Return all available schemes for any language
  return [NSArray arrayWithObjects:
    NSLinguisticTagSchemeTokenType,
    NSLinguisticTagSchemeLexicalClass,
    NSLinguisticTagSchemeNameType,
    NSLinguisticTagSchemeNameTypeOrLexicalClass,
    NSLinguisticTagSchemeLemma,
    NSLinguisticTagSchemeLanguage,
    NSLinguisticTagSchemeScript,
    nil];
}

- (void) setOrthography: (NSOrthography *)orthography
                  range: (NSRange)range
{
  NSDictionary *entry;
  
  if (_orthographyArray == nil)
    {
      _orthographyArray = [[NSMutableArray alloc] init];
    }
  
  entry = [NSDictionary dictionaryWithObjectsAndKeys:
    orthography, @"orthography",
    [NSValue valueWithRange: range], @"range",
    nil];
  
  [(NSMutableArray *)_orthographyArray addObject: entry];
}
  
- (NSOrthography *) orthographyAtIndex: (NSUInteger)charIndex
                        effectiveRange: (NSRangePointer)effectiveRange
{
  if (_orthographyArray != nil)
    {
      NSEnumerator *enumerator;
      NSDictionary *entry;
      NSRange range;
      
      enumerator = [_orthographyArray objectEnumerator];
      while ((entry = [enumerator nextObject]))
        {
          range = [[entry objectForKey: @"range"] rangeValue];
          if (NSLocationInRange(charIndex, range))
            {
              if (effectiveRange != NULL)
                *effectiveRange = range;
              return [entry objectForKey: @"orthography"];
            }
        }
    }
  
  // Return default orthography based on dominant language
  if (effectiveRange != NULL && _string != nil)
    *effectiveRange = NSMakeRange(0, [_string length]);
    
  return nil;
}

- (void) stringEditedInRange: (NSRange)newRange
              changeInLength: (NSInteger)delta
{
  // Invalidate cached analysis for edited region
  DESTROY(_tokenArray);
  DESTROY(_dominantLanguage);
  
  // Adjust orthography ranges if necessary
  if (_orthographyArray != nil && delta != 0)
    {
      NSMutableArray *adjusted;
      NSEnumerator *enumerator;
      NSDictionary *entry;
      NSRange range;
      
      adjusted = [NSMutableArray array];
      enumerator = [_orthographyArray objectEnumerator];
      while ((entry = [enumerator nextObject]))
        {
          range = [[entry objectForKey: @"range"] rangeValue];
          
          // If range is before edit, keep as-is
          if (NSMaxRange(range) <= newRange.location)
            {
              [adjusted addObject: entry];
            }
          // If range is after edit, adjust location
          else if (range.location >= NSMaxRange(newRange))
            {
              NSDictionary *newEntry;
              
              range.location += delta;
              newEntry = [NSDictionary dictionaryWithObjectsAndKeys:
                [entry objectForKey: @"orthography"], @"orthography",
                [NSValue valueWithRange: range], @"range",
                nil];
              [adjusted addObject: newEntry];
            }
          // Range overlaps or contains edit - remove it
        }
      ASSIGN(_orthographyArray, adjusted);
    }
}
  
- (NSRange) tokenRangeAtIndex: (NSUInteger)charIndex
                         unit: (NSLinguisticTaggerUnit)unit
{
  NSUInteger length;
  NSUInteger start;
  NSUInteger end;
  NSCharacterSet *wordChars;
  unichar c;
  
  if (_string == nil || charIndex >= [_string length])
    return NSMakeRange(NSNotFound, 0);
    
  length = [_string length];
  start = charIndex;
  end = charIndex;
  
  if (unit == NSLinguisticTaggerUnitWord)
    {
      wordChars = [NSCharacterSet alphanumericCharacterSet];
      c = [_string characterAtIndex: charIndex];
      
      if (![wordChars characterIsMember: c])
        {
          // Single character token for non-word characters
          return NSMakeRange(charIndex, 1);
        }
      
      // Find start of word
      while (start > 0)
        {
          unichar prev = [_string characterAtIndex: start - 1];
          if (![wordChars characterIsMember: prev])
            break;
          start--;
        }
      
      // Find end of word
      while (end < length)
        {
          unichar next = [_string characterAtIndex: end];
          if (![wordChars characterIsMember: next])
            break;
          end++;
        }
      
      return NSMakeRange(start, end - start);
    }
  else if (unit == NSLinguisticTaggerUnitSentence)
    {
      return [self sentenceRangeForRange: NSMakeRange(charIndex, 0)];
    }
  else if (unit == NSLinguisticTaggerUnitParagraph)
    {
      return [_string paragraphRangeForRange: NSMakeRange(charIndex, 0)];
    }
  else if (unit == NSLinguisticTaggerUnitDocument)
    {
      return NSMakeRange(0, length);
    }
  
  return NSMakeRange(charIndex, 1);
}
  
- (NSRange) sentenceRangeForRange: (NSRange)range
{
  NSUInteger length;
  NSUInteger start;
  NSUInteger end;
  unichar c;
  
  if (_string == nil || range.location >= [_string length])
    return NSMakeRange(NSNotFound, 0);
    
  length = [_string length];
  start = range.location;
  end = NSMaxRange(range);
  
  // Find start of sentence - look backwards for sentence terminator or start of string
  while (start > 0)
    {
      c = [_string characterAtIndex: start - 1];
      if (isSentenceTerminator(c))
        {
          // Skip whitespace after terminator
          while (start < length && [[NSCharacterSet whitespaceAndNewlineCharacterSet] 
                                   characterIsMember: [_string characterAtIndex: start]])
            start++;
          break;
        }
      start--;
    }
  
  // Find end of sentence - look forward for sentence terminator
  while (end < length)
    {
      unichar c = [_string characterAtIndex: end];
      if (isSentenceTerminator(c))
        {
          end++;
          // Include trailing whitespace
          while (end < length && [[NSCharacterSet whitespaceCharacterSet] 
                                 characterIsMember: [_string characterAtIndex: end]])
            end++;
          break;
        }
      end++;
    }
  
  return NSMakeRange(start, end - start);
}

- (void) enumerateTagsInRange: (NSRange)range
                         unit: (NSLinguisticTaggerUnit)unit
                       scheme: (NSLinguisticTagScheme)scheme
                      options: (NSLinguisticTaggerOptions)options
                   usingBlock: (GSLinguisticTagRangeBoolBlock)blockHandler
{
  NSUInteger currentPos;
  NSUInteger maxPos;
  BOOL stop;
  
  if (_string == nil || blockHandler == nil)
    return;
    
  currentPos = range.location;
  maxPos = NSMaxRange(range);
  stop = NO;
  
  while (currentPos < maxPos && !stop)
    {
      NSRange tokenRange;
      NSUInteger diff;
      NSLinguisticTag tag;
      BOOL shouldSkip;
      
      tokenRange = [self tokenRangeAtIndex: currentPos unit: unit];
      if (tokenRange.location == NSNotFound || tokenRange.location >= maxPos)
        break;
        
      // Adjust token range to fit within requested range
      if (tokenRange.location < range.location)
        {
          diff = range.location - tokenRange.location;
          tokenRange.location = range.location;
          tokenRange.length = (tokenRange.length > diff) ? tokenRange.length - diff : 0;
        }
      if (NSMaxRange(tokenRange) > maxPos)
        {
          tokenRange.length = maxPos - tokenRange.location;
        }
      
      if (tokenRange.length > 0)
        {
          tag = [self tagAtIndex: tokenRange.location
                            unit: unit
                          scheme: scheme
                      tokenRange: NULL];
          
          // Apply option filters
          shouldSkip = NO;
          if ([tag isEqualToString: NSLinguisticTagWord] && 
              (options & NSLinguisticTaggerOmitWords))
            shouldSkip = YES;
          if ([tag isEqualToString: NSLinguisticTagPunctuation] && 
              (options & NSLinguisticTaggerOmitPunctuation))
            shouldSkip = YES;
          if ([tag isEqualToString: NSLinguisticTagWhitespace] && 
              (options & NSLinguisticTaggerOmitWhitespace))
            shouldSkip = YES;
          if ([tag isEqualToString: NSLinguisticTagOther] && 
              (options & NSLinguisticTaggerOmitOther))
            shouldSkip = YES;
          
          if (!shouldSkip && tag != nil)
            {
              blockHandler(tag, tokenRange, &stop);
            }
        }
      
      currentPos = NSMaxRange(tokenRange);
    }
}

- (NSLinguisticTag) tagAtIndex: (NSUInteger)charIndex
                          unit: (NSLinguisticTaggerUnit)unit
                        scheme: (NSLinguisticTagScheme)scheme
                    tokenRange: (NSRangePointer)tokenRange
{
  NSRange range;
  unichar c;
  
  if (_string == nil || charIndex >= [_string length])
    return nil;
    
  range = [self tokenRangeAtIndex: charIndex unit: unit];
  if (tokenRange != NULL)
    *tokenRange = range;
    
  if (range.location == NSNotFound || range.length == 0)
    return nil;
    
  c = [_string characterAtIndex: range.location];
  
  // Handle different schemes
  if ([scheme isEqualToString: NSLinguisticTagSchemeTokenType])
    {
      return tokenTypeForCharacter(c);
    }
  else if ([scheme isEqualToString: NSLinguisticTagSchemeLexicalClass])
    {
      // Basic lexical classification
      if ([[NSCharacterSet decimalDigitCharacterSet] characterIsMember: c])
        return NSLinguisticTagNumber;
      if (isSentenceTerminator(c))
        return NSLinguisticTagSentenceTerminator;
      if (c == '(' || c == '[' || c == '{')
        return NSLinguisticTagOpenParenthesis;
      if (c == ')' || c == ']' || c == '}')
        return NSLinguisticTagCloseParenthesis;
      if (c == '-' || c == 0x2013 || c == 0x2014)
        return NSLinguisticTagDash;
      if ([[NSCharacterSet whitespaceCharacterSet] characterIsMember: c])
        return NSLinguisticTagOtherWhitespace;
      if ([[NSCharacterSet punctuationCharacterSet] characterIsMember: c])
        return NSLinguisticTagOtherPunctuation;
      if ([[NSCharacterSet alphanumericCharacterSet] characterIsMember: c])
        return NSLinguisticTagOtherWord;
      return NSLinguisticTagOther;
    }
  else if ([scheme isEqualToString: NSLinguisticTagSchemeLanguage])
    {
      return [self dominantLanguage];
    }
  
  return nil;
}

- (NSArray *) tagsInRange: (NSRange)range
                     unit: (NSLinguisticTaggerUnit)unit
                   scheme: (NSLinguisticTagScheme)scheme
                  options: (NSLinguisticTaggerOptions)options
              tokenRanges: (NSArray **)tokenRanges
{
  NSMutableArray *tags;
  NSMutableArray *ranges;
  NSUInteger currentPos;
  NSUInteger maxPos;
  
  if (_string == nil || range.location >= [_string length])
    return [NSArray array];
    
  tags = [NSMutableArray array];
  ranges = tokenRanges != NULL ? [NSMutableArray array] : nil;
  currentPos = range.location;
  maxPos = NSMaxRange(range);
  
  while (currentPos < maxPos)
    {
      NSRange tokenRange;
      NSLinguisticTag tag;
      NSUInteger diff;
      
      tag = [self tagAtIndex: currentPos
                        unit: unit
                      scheme: scheme
                  tokenRange: &tokenRange];
      
      if (tokenRange.location == NSNotFound || tokenRange.location >= maxPos)
        break;
        
      // Adjust token range to fit within requested range
      if (tokenRange.location < range.location)
        {
          diff = range.location - tokenRange.location;
          tokenRange.location = range.location;
          tokenRange.length = (tokenRange.length > diff) ? tokenRange.length - diff : 0;
        }
      if (NSMaxRange(tokenRange) > maxPos)
        {
          tokenRange.length = maxPos - tokenRange.location;
        }
      
      if (tag != nil && tokenRange.length > 0)
        {
          [tags addObject: tag];
          if (ranges != nil)
            [ranges addObject: [NSValue valueWithRange: tokenRange]];
        }
      
      currentPos = NSMaxRange(tokenRange);
      if (currentPos <= range.location) // Prevent infinite loop
        currentPos = range.location + 1;
    }
  
  if (tokenRanges != NULL)
    *tokenRanges = ranges;
    
  return tags;
}

- (void) enumerateTagsInRange: (NSRange)range
                       scheme: (NSLinguisticTagScheme)tagScheme
                      options: (NSLinguisticTaggerOptions)opts
                   usingBlock: (GSLinguisticTagRangeRangeBoolBlock)blockHandler
{
  NSUInteger currentPos;
  NSUInteger maxPos;
  BOOL stop;
  
  if (_string == nil || blockHandler == nil)
    return;
    
  currentPos = range.location;
  maxPos = NSMaxRange(range);
  stop = NO;
  
  while (currentPos < maxPos && !stop)
    {
      NSRange tokenRange;
      NSRange sentenceRange;
      NSLinguisticTag tag;
      
      sentenceRange = [self sentenceRangeForRange: NSMakeRange(currentPos, 0)];
      tag = [self tagAtIndex: currentPos
                      scheme: tagScheme
                  tokenRange: &tokenRange
               sentenceRange: NULL];
      
      if (tokenRange.location == NSNotFound || tokenRange.location >= maxPos)
        break;
        
      if (tag != nil)
        {
          blockHandler(tag, tokenRange, sentenceRange, &stop);
        }
      
      currentPos = NSMaxRange(tokenRange);
      if (currentPos <= range.location)
        currentPos = range.location + 1;
    }
}

- (NSLinguisticTag) tagAtIndex: (NSUInteger)charIndex
                        scheme: (NSLinguisticTagScheme)scheme
                    tokenRange: (NSRangePointer)tokenRange
                 sentenceRange: (NSRangePointer)sentenceRange
{
  if (sentenceRange != NULL)
    *sentenceRange = [self sentenceRangeForRange: NSMakeRange(charIndex, 0)];
    
  return [self tagAtIndex: charIndex
                     unit: NSLinguisticTaggerUnitWord
                   scheme: scheme
               tokenRange: tokenRange];
}
  
- (NSArray *) tagsInRange: (NSRange)range
                   scheme: (NSString *)tagScheme
                  options: (NSLinguisticTaggerOptions)opts
              tokenRanges: (NSArray **)tokenRanges
{
  return [self tagsInRange: range
                      unit: NSLinguisticTaggerUnitWord
                    scheme: tagScheme
                   options: opts
               tokenRanges: tokenRanges];
}

- (NSString *) dominantLanguage
{
  if (_dominantLanguage == nil && _string != nil)
    {
      _dominantLanguage = RETAIN([[self class] dominantLanguageForString: _string]);
    }
  return _dominantLanguage;
}

+ (NSString *) dominantLanguageForString: (NSString *)string
{
  NSUInteger length;
  NSUInteger latinCount;
  NSUInteger cjkCount;
  NSUInteger arabicCount;
  NSUInteger cyrillicCount;
  NSUInteger i;
  unichar c;
  NSString *localeLanguage;
  
  if (string == nil || [string length] == 0)
    return nil;
    
  // Simple heuristic based on character ranges
  length = [string length];
  latinCount = 0;
  cjkCount = 0;
  arabicCount = 0;
  cyrillicCount = 0;
  
  for (i = 0; i < length && i < 1000; i++)
    {
      c = [string characterAtIndex: i];
      
      if ((c >= 0x0041 && c <= 0x007A) || (c >= 0x00C0 && c <= 0x024F))
        latinCount++;
      else if ((c >= 0x4E00 && c <= 0x9FFF) || (c >= 0x3400 && c <= 0x4DBF))
        cjkCount++;
      else if (c >= 0x0600 && c <= 0x06FF)
        arabicCount++;
      else if (c >= 0x0400 && c <= 0x04FF)
        cyrillicCount++;
    }
  
  if (cjkCount > latinCount && cjkCount > arabicCount)
    return @"zh";
  if (arabicCount > latinCount)
    return @"ar";
  if (cyrillicCount > latinCount)
    return @"ru";
  
  // Default to current locale's language or English
  localeLanguage = [[NSLocale currentLocale] objectForKey: NSLocaleLanguageCode];
  return localeLanguage != nil ? localeLanguage : @"en";
}

+ (NSLinguisticTag) tagForString: (NSString *)string
                         atIndex: (NSUInteger)charIndex
                            unit: (NSLinguisticTaggerUnit)unit
                          scheme: (NSLinguisticTagScheme)scheme
                     orthography: (NSOrthography *)orthography
                      tokenRange: (NSRangePointer)tokenRange
{
  NSLinguisticTagger *tagger;
  NSLinguisticTag tag;
  
  tagger = [[NSLinguisticTagger alloc] 
            initWithTagSchemes: [NSArray arrayWithObject: scheme] options: 0];
  [tagger setString: string];
  
  if (orthography != nil)
    {
      [tagger setOrthography: orthography 
                       range: NSMakeRange(0, [string length])];
    }
  
  tag = [tagger tagAtIndex: charIndex
                      unit: unit
                    scheme: scheme
                tokenRange: tokenRange];
  RELEASE(tagger);
  
  return tag;
}
  
+ (NSArray *)tagsForString: (NSString *)string
                     range: (NSRange)range
                      unit: (NSLinguisticTaggerUnit)unit
                    scheme: (NSLinguisticTagScheme)scheme
                   options: (NSLinguisticTaggerOptions)options
               orthography: (NSOrthography *)orthography
               tokenRanges: (NSArray **)tokenRanges
{
  NSLinguisticTagger *tagger;
  NSArray *tags;
  
  tagger = [[NSLinguisticTagger alloc] 
            initWithTagSchemes: [NSArray arrayWithObject: scheme] options: options];
  [tagger setString: string];
  
  if (orthography != nil)
    {
      [tagger setOrthography: orthography range: range];
    }
  
  tags = [tagger tagsInRange: range
                         unit: unit
                       scheme: scheme
                      options: options
                  tokenRanges: tokenRanges];
  RELEASE(tagger);
  
  return tags;
}

+ (void) enumerateTagsForString: (NSString *)string
                          range: (NSRange)range
                           unit: (NSLinguisticTaggerUnit)unit
                         scheme: (NSLinguisticTagScheme)scheme
                        options: (NSLinguisticTaggerOptions)options
                    orthography: (NSOrthography *)orthography
                     usingBlock: (GSLinguisticTagRangeBoolBlock)block
{
  NSLinguisticTagger *tagger = [[NSLinguisticTagger alloc] 
                                initWithTagSchemes: [NSArray arrayWithObject: scheme] options: options];
  [tagger setString: string];
  
  if (orthography != nil)
    {
      [tagger setOrthography: orthography range: range];
    }
  
  [tagger enumerateTagsInRange: range
                          unit: unit
                        scheme: scheme
                       options: options
                    usingBlock: block];
  
  RELEASE(tagger);
}
  

- (NSArray *) possibleTagsAtIndex: (NSUInteger)charIndex
                           scheme: (NSString *)tagScheme
                       tokenRange: (NSRangePointer)tokenRange
                    sentenceRange: (NSRangePointer)sentenceRange
                           scores: (NSArray **)scores
{
  // Get the primary tag
  NSLinguisticTag tag = [self tagAtIndex: charIndex
                                  scheme: tagScheme
                              tokenRange: tokenRange
                           sentenceRange: sentenceRange];
  
  if (tag == nil)
    {
      if (scores != NULL)
        *scores = [NSArray array];
      return [NSArray array];
    }
  
  // Return the tag with a confidence score of 1.0
  if (scores != NULL)
    *scores = [NSArray arrayWithObject: [NSNumber numberWithDouble: 1.0]];
    
  return [NSArray arrayWithObject: tag];
}
@end


@implementation NSString (NSLinguisticAnalysis)

- (NSArray *) linguisticTagsInRange: (NSRange)range
                             scheme: (NSLinguisticTagScheme)scheme
                            options: (NSLinguisticTaggerOptions)options
                        orthography: (NSOrthography *)orthography
                        tokenRanges: (NSArray **)tokenRanges
{
  return [NSLinguisticTagger tagsForString: self
                                     range: range
                                      unit: NSLinguisticTaggerUnitWord
                                    scheme: scheme
                                   options: options
                               orthography: orthography
                               tokenRanges: tokenRanges];
}

- (void) enumerateLinguisticTagsInRange: (NSRange)range
                                 scheme: (NSLinguisticTagScheme)scheme
                                options: (NSLinguisticTaggerOptions)options
                            orthography: (NSOrthography *)orthography
                             usingBlock: (GSLinguisticTagRangeRangeBoolBlock)block
{
  NSLinguisticTagger *tagger = [[NSLinguisticTagger alloc] 
                                initWithTagSchemes: [NSArray arrayWithObject: scheme] options: options];
  [tagger setString: self];
  
  if (orthography != nil)
    {
      [tagger setOrthography: orthography range: range];
    }
  
  [tagger enumerateTagsInRange: range
                        scheme: scheme
                       options: options
                    usingBlock: block];
  
  RELEASE(tagger);
}

@end

