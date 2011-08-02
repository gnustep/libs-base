#import <Foundation/Foundation.h>
#import "ObjectTesting.h"


int main(void)
{
	[NSAutoreleasePool new];
	// Simple test JSON, used for all of the examples
	NSString *json = @"\
   {\
      \"Image\": {\
          \"Width\":  800,\
          \"Height\": 600,\
          \"Title\":  \"View from 15th Floor\",\
          \"Thumbnail\": {\
              \"Url\":    \"http://www.example.com/image/481989943\",\
              \"Height\": 125,\
              \"Width\":  \"100\"\
          },\
      },\
      \"IDs\": [116, 943, 234, 38793],\
      \"escapeTest\": \"\\\"\\u0001\"\
  }";
	NSStringEncoding encs[] = {NSUTF8StringEncoding, NSUTF16LittleEndianStringEncoding, NSUTF16BigEndianStringEncoding, NSUTF32LittleEndianStringEncoding, NSUTF32BigEndianStringEncoding};
	id obj;
        int i;

	for (i=0 ; i<(sizeof(encs) / sizeof(NSStringEncoding)) ; i++)
	{
		NSData *data = [json dataUsingEncoding: encs[i]];
		NSError *e;
		id tmp = [NSJSONSerialization JSONObjectWithData: data options: 0 error: &e];
		if (i > 0)
		{
			PASS([tmp isEqual: obj], "Decoding in different encodings give the same result");
		}
		obj = tmp;
	}
	PASS([obj count] == 3, "Decoded dictionary had the right number of elements");
	PASS([NSJSONSerialization isValidJSONObject: obj], "Can serialise deserialised JSON");
	NSData *data = [NSJSONSerialization dataWithJSONObject: obj options: NSJSONWritingPrettyPrinted error: 0];
	PASS([obj isEqual: [NSJSONSerialization JSONObjectWithData: data options: 0 error: 0]], "Round trip worked with pretty printing");
	data = [NSJSONSerialization dataWithJSONObject: obj options: 0 error: 0];
	PASS([obj isEqual: [NSJSONSerialization JSONObjectWithData: data options: 0 error: 0]], "Round trip worked with ugly printing");
	PASS([obj isEqual: [NSJSONSerialization JSONObjectWithStream: [NSInputStream inputStreamWithData:data] options: 0 error: 0]], "Round trip worked through stream");
	return 0;
}
