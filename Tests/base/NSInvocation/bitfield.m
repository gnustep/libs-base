/* Passing and returning a structure that contains bitfields through an
 * NSInvocation.  This exercises cifframe_type's handling of the _C_BFLD ('b')
 * type encoding, which used to abort with "Unknown type in sig", and the
 * NSMethodSignature sizing of such a structure.  Checking the round-tripped
 * values confirms the structure is laid out correctly for the call, not
 * merely that the abort is gone.
 */

#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

typedef struct {
  unsigned int	a: 3;
  unsigned int	b: 5;
  unsigned int	c: 7;
} BitStruct;

/* A run of single-bit fields, as found in the NSView "rflags" structure. */
typedef struct {
  unsigned int	f0: 1, f1: 1, f2: 1, f3: 1, f4: 1,
		f5: 1, f6: 1, f7: 1, f8: 1, f9: 1;
} FlagStruct;

/* Wide enough that the two fields occupy separate storage units. */
typedef struct {
  unsigned int	a: 20;
  unsigned int	b: 20;
} WideStruct;

@interface BitTarget : NSObject
- (BitStruct) transform: (BitStruct)input;
- (FlagStruct) flip: (FlagStruct)input;
- (WideStruct) swap: (WideStruct)input;
@end

@implementation BitTarget
- (BitStruct) transform: (BitStruct)input
{
  BitStruct	output;

  output.a = input.c & 7;
  output.b = input.b;
  output.c = input.a;
  return output;
}
- (FlagStruct) flip: (FlagStruct)input
{
  input.f0 = !input.f0;
  return input;
}
- (WideStruct) swap: (WideStruct)input
{
  WideStruct	output;

  output.a = input.b;
  output.b = input.a;
  return output;
}
@end

int main(void)
{
  START_SET("bitfield structure through NSInvocation")
    BitTarget		*t = [[[BitTarget alloc] init] autorelease];
    BitStruct		input = { 5, 20, 100 };
    BitStruct		output;
    FlagStruct		fin;
    FlagStruct		fout;
    WideStruct		win;
    WideStruct		wout;
    NSMethodSignature	*sig;
    NSInvocation	*inv;

    sig = [t methodSignatureForSelector: @selector(transform:)];
    PASS(sig != nil, "a signature containing a bitfield struct is created");
    PASS([sig methodReturnLength] == sizeof(BitStruct),
      "the return length of a bitfield struct is correct");

    inv = [NSInvocation invocationWithMethodSignature: sig];
    PASS(inv != nil,
      "an invocation for a bitfield struct is built without aborting");

    [inv setSelector: @selector(transform:)];
    [inv setTarget: t];
    [inv setArgument: &input atIndex: 2];
    [inv invoke];

    memset(&output, 0, sizeof(output));
    [inv getReturnValue: &output];
    PASS(output.a == (input.c & 7) && output.b == input.b && output.c == input.a,
      "a bitfield structure round-trips through the invocation");

    memset(&fin, 0, sizeof(fin));
    fin.f3 = 1;
    fin.f9 = 1;
    sig = [t methodSignatureForSelector: @selector(flip:)];
    inv = [NSInvocation invocationWithMethodSignature: sig];
    [inv setSelector: @selector(flip:)];
    [inv setTarget: t];
    [inv setArgument: &fin atIndex: 2];
    [inv invoke];

    memset(&fout, 0, sizeof(fout));
    [inv getReturnValue: &fout];
    PASS(fout.f0 == 1 && fout.f1 == 0 && fout.f3 == 1 && fout.f9 == 1,
      "a run of single-bit fields round-trips through the invocation");

    win.a = 0xABCDE;
    win.b = 0x12345;
    sig = [t methodSignatureForSelector: @selector(swap:)];
    inv = [NSInvocation invocationWithMethodSignature: sig];
    [inv setSelector: @selector(swap:)];
    [inv setTarget: t];
    [inv setArgument: &win atIndex: 2];
    [inv invoke];

    memset(&wout, 0, sizeof(wout));
    [inv getReturnValue: &wout];
    PASS(wout.a == 0x12345 && wout.b == 0xABCDE,
      "a bitfield struct spanning two storage units round-trips");
  END_SET("bitfield structure through NSInvocation")

  return 0;
}
