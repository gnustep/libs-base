#import "Testing.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSCharacterSet.h>
#import <Foundation/NSData.h>

int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
  NSCharacterSet *theSet,*iSet;
  NSData *data1 = nil;
  unichar ch;
  theSet = [NSCharacterSet alphanumericCharacterSet];
  PASS([theSet characterIsMember: 'A'] &&
       [theSet characterIsMember: 'Z'] &&
       [theSet characterIsMember: 'a'] &&
       [theSet characterIsMember: 'z'] &&
       [theSet characterIsMember: '9'] &&
       [theSet characterIsMember: '0'] &&
       ![theSet characterIsMember: '#'] &&
       ![theSet characterIsMember: ' '] &&
       ![theSet characterIsMember: '\n'],
       "Check some characters from alphanumericCharacterSet");
  
  theSet = [NSCharacterSet lowercaseLetterCharacterSet];
  PASS(![theSet characterIsMember: 'A'] &&
       ![theSet characterIsMember: 'Z'] &&
       [theSet characterIsMember: 'a'] &&
       [theSet characterIsMember: 'z'] &&
       ![theSet characterIsMember: '9'] &&
       ![theSet characterIsMember: '0'] &&
       ![theSet characterIsMember: '#'] &&
       ![theSet characterIsMember: ' '] &&
       ![theSet characterIsMember: '\n'],
       "Check some characters from lowercaseLetterCharacterSet");
  
  theSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
  PASS(![theSet characterIsMember: 'A'] &&
       ![theSet characterIsMember: 'Z'] &&
       ![theSet characterIsMember: 'a'] &&
       ![theSet characterIsMember: 'z'] &&
       ![theSet characterIsMember: '9'] &&
       ![theSet characterIsMember: '0'] &&
       ![theSet characterIsMember: '#'] &&
       [theSet characterIsMember: ' '] &&
       [theSet characterIsMember: '\n'] &&
       [theSet characterIsMember: '\t'],
       "Check some characters from whitespaceAndNewlineCharacterSet");
  
  PASS([theSet characterIsMember: 0x00A0], "a non-break-space is whitespace");

  data1 = [theSet bitmapRepresentation];
  PASS(data1 != nil && [data1 isKindOfClass: [NSData class]],
       "-bitmapRepresentation works");
  
  iSet = [theSet invertedSet]; 
  PASS([iSet characterIsMember: 'A'] &&
       [iSet characterIsMember: 'Z'] &&
       [iSet characterIsMember: 'a'] &&
       [iSet characterIsMember: 'z'] &&
       [iSet characterIsMember: '9'] &&
       [iSet characterIsMember: '0'] &&
       [iSet characterIsMember: '#'] &&
       ![iSet characterIsMember: ' '] &&
       ![iSet characterIsMember: '\n'] &&
       ![iSet characterIsMember: '\t'],
       "-invertedSet works");
  {
    NSCharacterSet *firstSet,*secondSet,*thirdSet,*fourthSet;
    firstSet = [NSCharacterSet decimalDigitCharacterSet];
    secondSet = [NSCharacterSet decimalDigitCharacterSet];
    thirdSet = nil;
    fourthSet = [NSMutableCharacterSet decimalDigitCharacterSet];
    thirdSet = [[firstSet class] decimalDigitCharacterSet];
    PASS (firstSet == secondSet && 
          firstSet == thirdSet && 
	  firstSet != fourthSet,
	  "Caching of standard sets");
  }

  theSet = [NSCharacterSet characterSetWithCharactersInString:@"Not a set"];
  PASS(theSet != nil && [theSet isKindOfClass: [NSCharacterSet class]],
       "Create custom set with characterSetWithCharactersInString:");
  
  PASS([theSet characterIsMember: ' '] &&
       [theSet characterIsMember: 'N'] &&
       [theSet characterIsMember: 'o'] &&
       ![theSet characterIsMember: 'A'] &&
       ![theSet characterIsMember: '#'],
       "Check custom set");


  
  [arp release]; arp = nil;
  return 0;
}

