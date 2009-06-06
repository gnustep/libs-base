/** Implementation of GSFFIInvocation for GNUStep
   Copyright (C) 2000 Free Software Foundation, Inc.

   Written: Adam Fedor <fedor@gnu.org>
   Date: Apr 2002

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.
   */
#import "Foundation/NSException.h"
#import "Foundation/NSCoder.h"
#import "Foundation/NSDistantObject.h"
#import "Foundation/NSData.h"
#import "Foundation/NSDebug.h"
#import "GSInvocation.h"
#import <config.h>
#import <objc/objc-api.h>
#import "cifframe.h"
#import "mframe.h"
#import "GSPrivate.h"

#ifndef INLINE
#define INLINE inline
#endif

typedef struct _NSInvocation_t {
  @defs(NSInvocation)
} NSInvocation_t;

/* Function that implements the actual forwarding */
typedef void (*ffi_closure_fun) (ffi_cif*,void*,void**,void*);

typedef void (*f_fun) ();

static void GSFFIInvocationCallback(ffi_cif*, void*, void **, void*);

/*
 * If we are using the GNU ObjC runtime we could
 * simplify this function quite a lot because this
 * function is already present in the ObjC runtime.
 * However, it is not part of the public API, so
 * we work around it.
 */

static INLINE GSMethod
gs_method_for_receiver_and_selector (id receiver, SEL sel)
{
  if (receiver)
    {
      return GSGetMethod((GSObjCIsInstance(receiver)
                          ? GSObjCClass(receiver) : (Class)receiver),
                         sel,
                         GSObjCIsInstance(receiver),
                         YES);
    }

  return METHOD_NULL;
}


/*
 * Selectors are not unique, and not all selectors have
 * type information.  This method tries to find the
 * best equivalent selector with type information.
 *
 * the conversion sel -> name -> sel
 * is not what we want.  However
 * I can not see a way to dispose of the
 * name, except if we can access the
 * internal data structures of the runtime.
 *
 * If we can access the private data structures
 * we can also check for incompatible
 * return types between all equivalent selectors.
 */

static INLINE SEL
gs_find_best_typed_sel (SEL sel)
{
  if (!sel_get_type (sel))
    {
      const char *name = GSNameFromSelector(sel);

      if (name)
	{
	  SEL tmp_sel = sel_get_any_typed_uid (name);
	  if (sel_get_type (tmp_sel))
	    return tmp_sel;
	}
    }
  return sel;
}

/*
 * Take the receiver into account for finding the best
 * selector.  That is, we look if the receiver
 * implements the selector and the implementation
 * selector has type info.  If both conditions
 * are satisfied, return this selector.
 *
 * In all other cases fallback
 * to gs_find_best_typed_sel ().
 */
static INLINE SEL
gs_find_by_receiver_best_typed_sel (id receiver, SEL sel)
{
  if (sel_get_type (sel))
    return sel;

  if (receiver)
    {
      GSMethod method;

      method = gs_method_for_receiver_and_selector (receiver, sel);
      /* CHECKME:  Can we assume that:
	 (a) method_name is a selector (compare libobjc header files)
	 (b) this selector IS really typed?
	 At the moment I assume (a) but not (b)
         not assuming (b) is the reason for
         calling gs_find_best_typed_sel () even
         if we have an implementation.
      */
      if (method)
	sel = method->method_name;
    }
  return gs_find_best_typed_sel (sel);
}

@implementation GSFFIInvocation

static IMP gs_objc_msg_forward2 (id receiver, SEL sel)
{
  cifframe_t            *cframe;
  ffi_closure           *cclosure;
  NSMethodSignature     *sig;
  GSCodeBuffer          *memory;

  sig = [receiver methodSignatureForSelector: sel];

  if (sig == nil)
    {
      const char	*sel_type;

      /* Determine the method types so we can construct the frame. We may not
	 get the right one, though. What to do then? Perhaps it can be fixed up
	 in the callback, but only under limited circumstances.
       */
      sel_type = sel_get_type (sel);
      if (sel_type)
	{
	  sig = [NSMethodSignature signatureWithObjCTypes: sel_type];
	}
      else
	{
	  static NSMethodSignature *def = nil;

	  /*
	   * Default signature is for a method returning an object.
	   */
	  if (def == nil)
	    {
	      def = RETAIN([NSMethodSignature signatureWithObjCTypes: "@@:"]);
	    }
	  sig = def;
	}
    }

  NSCAssert1(sig, @"No signature for selector %@", NSStringFromSelector(sel));

  /* Construct the frame and closure. */
  /* Note: We malloc cframe here, but it's passed to GSFFIInvocationCallback
     where it becomes owned by the callback invocation, so we don't have to
     worry about freeing it */
  cframe = cifframe_from_info([sig methodInfo], [sig numberOfArguments], NULL);
  /* Autorelease the closure through GSAutoreleasedBuffer */

  memory = [GSCodeBuffer memoryWithSize: sizeof(ffi_closure)];
  cclosure = [memory buffer];
  if (cframe == NULL || cclosure == NULL)
    {
      [NSException raise: NSMallocException format: @"Allocating closure"];
    }
  if (ffi_prep_closure(cclosure, &(cframe->cif),
    GSFFIInvocationCallback, cframe) != FFI_OK)
    {
      [NSException raise: NSGenericException format: @"Preping closure"];
    }
  [memory protect];

  return (IMP)cclosure;
}

static __attribute__ ((__unused__))
IMP gs_objc_msg_forward (SEL sel)
{
  return gs_objc_msg_forward2 (nil, sel);
}

+ (void) load
{
#if	HAVE_FORWARD2
  __objc_msg_forward2 = gs_objc_msg_forward2;
#else
  __objc_msg_forward = gs_objc_msg_forward;
#endif
}

- (id) initWithArgframe: (arglist_t)frame selector: (SEL)aSelector
{
  /* We should never get here */
  NSDeallocateObject(self);
  [NSException raise: NSInternalInconsistencyException
	      format: @"Runtime incorrectly configured to pass argframes"];
  return nil;
}

/*
 *	This is the designated initialiser.
 */
- (id) initWithMethodSignature: (NSMethodSignature*)aSignature
{
  if (aSignature == nil)
    {
      RELEASE(self);
      return nil;
    }
  _sig = RETAIN(aSignature);
  _numArgs = [aSignature numberOfArguments];
  _info = [aSignature methodInfo];
  _cframe = cifframe_from_info(_info, _numArgs, &_retval);
  return self;
}

/* Initializer used when we get a callback. uses the data provided by
   the callback. The cifframe was allocated by the forwarding function,
   but we own it now so we can free it */
- (id) initWithCallback: (ffi_cif *)cif
		returnp: (void *)retp
		 values: (void **)vals
		  frame: (cifframe_t *)frame
	      signature: (NSMethodSignature*)aSignature
{
  int i;

  _sig = RETAIN(aSignature);
  _numArgs = [aSignature numberOfArguments];
  _info = [aSignature methodInfo];
  _cframe = frame;
  ((cifframe_t *)_cframe)->cif = *cif;

  /* Copy the arguments into our frame so that they are preserved
   * in the NSInvocation if the stack is changed before the
   * invocation is used.
   */
  for (i = 0; i < ((cifframe_t *)_cframe)->nargs; i++)
    {
      memcpy(((cifframe_t *)_cframe)->values[i], vals[i],
             ((cifframe_t *)_cframe)->arg_types[i]->size);
    }
  _retval = retp;
  return self;
}

- (void) _storeRetval
{
  _retval = _cframe + retval_offset_from_info (_info, _numArgs);
}

/*
 * This is implemented as a function so it can be used by other
 * routines (like the DO forwarding)
 */
void
GSFFIInvokeWithTargetAndImp(NSInvocation *_inv, id anObject, IMP imp)
{
  NSInvocation_t	*inv = (NSInvocation_t*)_inv;

  /* Do it */
  ffi_call(inv->_cframe, (f_fun)imp, (inv->_retval),
	   ((cifframe_t *)inv->_cframe)->values);

  /* Don't decode the return value here (?) */
}

- (void) invokeWithTarget: (id)anObject
{
  id		old_target;
  IMP		imp;

  CLEAR_RETURN_VALUE_IF_OBJECT;
  _validReturn = NO;

  /*
   *	A message to a nil object returns nil.
   */
  if (anObject == nil)
    {
      if (_retval)
        memset(_retval, '\0', _info[0].size);	/* Clear return value */
      _validReturn = YES;
      return;
    }

  NSAssert(_selector != 0, @"you must set the selector before invoking");

  /*
   *	Temporarily set new target and copy it (and the selector) into the
   *	_cframe.
   */
  old_target = RETAIN(_target);
  [self setTarget: anObject];

  cifframe_set_arg((cifframe_t *)_cframe, 0, &_target, _info[1].size);
  cifframe_set_arg((cifframe_t *)_cframe, 1, &_selector, _info[2].size);

  if (_sendToSuper == YES)
    {
      Super	s;

      s.self = _target;
      if (GSObjCIsInstance(_target))
	s.class = GSObjCSuper(GSObjCClass(_target));
      else
	s.class = GSObjCSuper((Class)_target);
      imp = objc_msg_lookup_super(&s, _selector);
    }
  else
    {
      GSMethod method;
      method = GSGetMethod((GSObjCIsInstance(_target)
                            ? (Class)GSObjCClass(_target)
                            : (Class)_target),
                           _selector,
                           GSObjCIsInstance(_target),
                           YES);
      imp = method_get_imp(method);
      /*
       * If fast lookup failed, we may be forwarding or something ...
       */
      if (imp == 0)
	{
	  imp = objc_msg_lookup(_target, _selector);
	}
    }

  [self setTarget: old_target];
  RELEASE(old_target);

  GSFFIInvokeWithTargetAndImp(self, anObject, imp);

  /* Decode the return value */
  if (*_info[0].type != _C_VOID)
    cifframe_decode_arg(_info[0].type, _retval);

  RETAIN_RETURN_VALUE;
  _validReturn = YES;
}

- (void*) returnFrame: (arglist_t)argFrame
{
  return _retval;
}
@end

/*
 * Return YES if the selector contains protocol qualifiers.
 */
static BOOL
gs_protocol_selector(const char *types)
{
  if (types == 0)
    {
      return NO;
    }
  while (*types != '\0')
    {
      if (*types == '-')
	{
	  types++;
	}
      if (*types == '+' || isdigit(*types))
	{
	  types = objc_skip_offset(types);
	}
      while (*types == _C_CONST || *types == _C_GCINVISIBLE)
	{
	  types++;
	}
      if (*types == _C_IN
	|| *types == _C_INOUT
	|| *types == _C_OUT
	|| *types == _C_BYCOPY
	|| *types == _C_BYREF
	|| *types == _C_ONEWAY)
	{
	  return YES;
	}
      if (*types == '\0')
	{
	  return NO;
	}
      types = objc_skip_typespec(types);
    }
  return NO;
}

static void
GSFFIInvocationCallback(ffi_cif *cif, void *retp, void **args, void *user)
{
  id			obj;
  SEL			selector;
  GSFFIInvocation	*invocation;
  NSMethodSignature	*sig;
  GSMethod              fwdInvMethod;

  obj      = *(id *)args[0];
  selector = *(SEL *)args[1];

  fwdInvMethod = gs_method_for_receiver_and_selector
    (obj, @selector (forwardInvocation:));

  if (!fwdInvMethod)
    {
      [NSException raise: NSInvalidArgumentException
		   format: @"GSFFIInvocation: Class '%s'(%s) does not respond"
		           @" to forwardInvocation: for '%s'",
		   GSClassNameFromObject(obj),
		   GSObjCIsInstance(obj) ? "instance" : "class",
		   selector ? GSNameFromSelector(selector) : "(null)"];
    }

  sig = nil;
  if (gs_protocol_selector(sel_get_type(selector)) == YES)
    {
      sig = [NSMethodSignature signatureWithObjCTypes: sel_get_type(selector)];
    }
  if (sig == nil)
    {
      sig = [obj methodSignatureForSelector: selector];
    }

  /*
   * If we got a method signature from the receiving object,
   * ensure that the selector we are using matches the types.
   */
  if (sig != nil)
    {
      const char	*receiverTypes = [sig methodType];
      const char	*runtimeTypes = sel_get_type (selector);

      if (runtimeTypes == 0 || strcmp(receiverTypes, runtimeTypes) != 0)
	{
	  const char	*runtimeName = GSNameFromSelector(selector);

	  selector = sel_get_typed_uid (runtimeName, receiverTypes);
	  if (selector == 0)
	    {
	      selector = sel_register_typed_name (runtimeName, receiverTypes);
	    }
	  if (runtimeTypes != 0)
	    {
	      /*
	       * FIXME ... if we have a typed selector, it probably came
	       * from the compiler, and the types of the proxied method
	       * MUST match those that the compiler supplied on the stack
	       * and the type it expects to retrieve from the stack.
	       * We should therefore discriminate between signatures where
	       * type qalifiers and sizes differ, and those where the
	       * actual types differ.
	       */
	      NSDebugFLog(@"Changed type signature '%s' to '%s' for '%s'",
		runtimeTypes, receiverTypes, runtimeName);
	    }
	}
    }

  if (sig == nil)
    {
      selector = gs_find_best_typed_sel (selector);

      if (sel_get_type (selector) != 0)
    {
      sig = [NSMethodSignature signatureWithObjCTypes: sel_get_type(selector)];
    }
    }

  if (sig == nil)
    {
      [NSException raise: NSInvalidArgumentException
                   format: @"Can not determine type information for %s[%s %s]",
                   GSObjCIsInstance(obj) ? "-" : "+",
	 GSClassNameFromObject(obj),
	 selector ? GSNameFromSelector(selector) : "(null)"];
    }

  invocation = [[GSFFIInvocation alloc] initWithCallback: cif
					returnp: retp
					values: args
 					frame: user
					signature: sig];
  IF_NO_GC([invocation autorelease];)
  [invocation setTarget: obj];
  [invocation setSelector: selector];

  /*
   * Now do it.
   * The next line is equivalent to
   *
   *   [obj forwardInvocation: invocation];
   *
   * but we have already the GSMethod for forwardInvocation
   * so the line below is somewhat faster. */
  fwdInvMethod->method_imp (obj, fwdInvMethod->method_name, invocation);

  /* Autorelease the invocation's return value (if it's an object) and
     mark it as invalid, so it won't be released later. We have to do
     this since the return value (retp) really belongs to the closure
     not the invocation so it will be demallocd at the end of this call
  */
  if ([sig methodReturnType] && *[sig methodReturnType] == _C_ID
    && ((NSInvocation_t *)invocation)->_validReturn == YES)
    {
      IF_NO_GC([*(id *)retp autorelease];)
      ((NSInvocation_t *)invocation)->_validReturn = NO;
    }

  /* We need to (re)encode the return type for it's trip back. */
  if (retp)
    cifframe_encode_arg([sig methodReturnType], retp);
}

@implementation NSInvocation (DistantCoding)

/* An internal method used to help NSConnections code invocations
   to send over the wire */
- (BOOL) encodeWithDistantCoder: (NSCoder*)coder passPointers: (BOOL)passp
{
  int		i;
  BOOL		out_parameters = NO;
  const char	*type = [_sig methodType];

  [coder encodeValueOfObjCType: @encode(char*) at: &type];

  for (i = 0; i < _numArgs; i++)
    {
      int		flags = _info[i+1].qual;
      const char	*type = _info[i+1].type;
      void		*datum;

      if (i == 0)
	{
	  datum = &_target;
	}
      else if (i == 1)
	{
	  datum = &_selector;
	}
      else
	{
	  datum = cifframe_arg_addr((cifframe_t *)_cframe, i);
	}

      /*
       * Decide how, (or whether or not), to encode the argument
       * depending on its FLAGS and TYPE.  Only the first two cases
       * involve parameters that may potentially be passed by
       * reference, and thus only the first two may change the value
       * of OUT_PARAMETERS.
       */

      switch (*type)
	{
	  case _C_ID:
	    if (flags & _F_BYCOPY)
	      {
		[coder encodeBycopyObject: *(id*)datum];
	      }
#ifdef	_F_BYREF
	    else if (flags & _F_BYREF)
	      {
		[coder encodeByrefObject: *(id*)datum];
	      }
#endif
	    else
	      {
		[coder encodeObject: *(id*)datum];
	      }
	    break;
	  case _C_CHARPTR:
	    /*
	     * Handle a (char*) argument.
	     * If the char* is qualified as an OUT parameter, or if it
	     * not explicitly qualified as an IN parameter, then we will
	     * have to get this char* again after the method is run,
	     * because the method may have changed it.  Set
	     * OUT_PARAMETERS accordingly.
	     */
	    if ((flags & _F_OUT) || !(flags & _F_IN))
	      {
		out_parameters = YES;
	      }
	    /*
	     * If the char* is qualified as an IN parameter, or not
	     * explicity qualified as an OUT parameter, then encode
	     * it.
	     */
	    if ((flags & _F_IN) || !(flags & _F_OUT))
	      {
		[coder encodeValueOfObjCType: type at: datum];
	      }
	    break;

	  case _C_PTR:
	    /*
	     * If the pointer's value is qualified as an OUT parameter,
	     * or if it not explicitly qualified as an IN parameter,
	     * then we will have to get the value pointed to again after
	     * the method is run, because the method may have changed
	     * it.  Set OUT_PARAMETERS accordingly.
	     */
	    if ((flags & _F_OUT) || !(flags & _F_IN))
	      {
		out_parameters = YES;
	      }
	    if (passp)
	      {
		if ((flags & _F_IN) || !(flags & _F_OUT))
		  {
		    [coder encodeValueOfObjCType: type at: datum];
		  }
	      }
	    else
	      {
		/*
		 * Handle an argument that is a pointer to a non-char.  But
		 * (void*) and (anything**) is not allowed.
		 * The argument is a pointer to something; increment TYPE
		 * so we can see what it is a pointer to.
		 */
		type++;
		/*
		 * If the pointer's value is qualified as an IN parameter,
		 * or not explicity qualified as an OUT parameter, then
		 * encode it.
		 */
		if ((flags & _F_IN) || !(flags & _F_OUT))
		  {
		    [coder encodeValueOfObjCType: type at: *(void**)datum];
		  }
	      }
	    break;

	  case _C_STRUCT_B:
	  case _C_UNION_B:
	  case _C_ARY_B:
	    /*
	     * Handle struct and array arguments.
	     * Whether DATUM points to the data, or points to a pointer
	     * that points to the data, depends on the value of
	     * CALLFRAME_STRUCT_BYREF.  Do the right thing
	     * so that ENCODER gets a pointer to directly to the data.
	     */
	    [coder encodeValueOfObjCType: type at: datum];
	    break;

	  default:
	    /* Handle arguments of all other types. */
	    [coder encodeValueOfObjCType: type at: datum];
	}
    }

  /*
   * Return a BOOL indicating whether or not there are parameters that
   * were passed by reference; we will need to get those values again
   * after the method has finished executing because the execution of
   * the method may have changed them.
   */
  return out_parameters;
}

@end
