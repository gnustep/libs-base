#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSString.h>
#import <Foundation/NSCharacterSet.h>

BOOL testUrlCharacterSetEncoding(
  NSString* decodedString,
  NSString* encodedString,
  NSCharacterSet* allowedCharacterSet)
{
  NSString	*testString
    = [decodedString stringByAddingPercentEncodingWithAllowedCharacters:
	allowedCharacterSet];
//  NSLog(@"String by adding percent, done. test=%@ decoded=%@", testString, decodedString);
  return [encodedString isEqualToString: testString];
}

int main (int argc, const char * argv[])
{
  NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

  NSString *urlDecodedString = @"Only alphabetic characters should be allowed and not encoded. !@#$%^&*()_+-=";
  NSString *urlEncodedString =
    @"Only%20alphabetic%20characters%20should%20be%20allowed%20and%20not%20encoded%2E%20%21%40%23%24%25%5E%26%2A%28%29%5F%2B%2D%3D";
  NSCharacterSet *allowedCharacterSet = [NSCharacterSet alphanumericCharacterSet];
  PASS(testUrlCharacterSetEncoding(urlDecodedString, urlEncodedString, allowedCharacterSet), "alphanumericCharacterSet");  
       
  urlDecodedString = @"https://www.microsoft.com/en-us/!@#$%^&*()_";
  urlEncodedString = @"https://www.microsoft.com/en-us/!@%23$%25%5E&*()_";
  allowedCharacterSet = [NSCharacterSet URLFragmentAllowedCharacterSet];
  PASS(testUrlCharacterSetEncoding(urlDecodedString, urlEncodedString, allowedCharacterSet), "fragmentCharacterSet");  
  
  urlDecodedString = @"All alphabetic characters should be encoded. Symbols should not be: !@#$%^&*()_+-=";
  urlEncodedString = @"%41%6C%6C %61%6C%70%68%61%62%65%74%69%63 %63%68%61%72%61%63%74%65%72%73 %73%68%6F%75%6C%64 %62%65 "
    @"%65%6E%63%6F%64%65%64. %53%79%6D%62%6F%6C%73 %73%68%6F%75%6C%64 %6E%6F%74 %62%65: !@#$%^&*()_+-=";
  allowedCharacterSet = [[NSCharacterSet alphanumericCharacterSet] invertedSet];
  PASS(testUrlCharacterSetEncoding(urlDecodedString, urlEncodedString, allowedCharacterSet), "inverted");  

  urlDecodedString = @"Here are some Emojis: \U0001F601 \U0001F602 \U0001F638 Emojis done."; // Multibyte encoded characters
  urlEncodedString = @"Here%20are%20some%20Emojis:%20%F0%9F%98%81%20%F0%9F%98%82%20%F0%9F%98%B8%20Emojis%20done.";
  allowedCharacterSet = [NSCharacterSet URLFragmentAllowedCharacterSet];
  PASS(testUrlCharacterSetEncoding(urlDecodedString, urlEncodedString, allowedCharacterSet), "fragmentCharacterSet emojis");  

  urlDecodedString = @"\1";
  urlEncodedString = @"%01";
  allowedCharacterSet = [NSCharacterSet alphanumericCharacterSet];
  PASS(testUrlCharacterSetEncoding(urlDecodedString, urlEncodedString, allowedCharacterSet), "alphanumericCharacterSet");  

  urlDecodedString = @"All alphabetic characters should be encoded. Symbols should not be: !@#$%^&*()_+-=";
  urlEncodedString = @"%41%6C%6C %61%6C%70%68%61%62%65%74%69%63 %63%68%61%72%61%63%74%65%72%73 %73%68%6F%75%6C%64 %62%65 "
    @"%65%6E%63%6F%64%65%64. %53%79%6D%62%6F%6C%73 %73%68%6F%75%6C%64 %6E%6F%74 %62%65: !@#$%^&*()_+-=";
  NSString *result = [urlEncodedString stringByRemovingPercentEncoding];
  PASS([urlDecodedString isEqualToString: result], "stringByRemovingPercentEncoding");
  // NSLog(@"Result = \"%@\",\ndecodedString = \"%@\",\nencodedString = \"%@\"", result, urlDecodedString, urlEncodedString);
  [pool drain];
  return 0;
}
