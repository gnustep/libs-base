#include "ObjectiveC2/runtime.h"

/* Make glibc export strdup() */

#if defined __GLIBC__
#define __USE_BSD 1
#endif

#undef __objc_INCLUDE_GNU
#undef __thread_INCLUDE_GNU
#undef __objc_api_INCLUDE_GNU
#undef __encoding_INCLUDE_GNU

#define objc_object objc_object_gnu
#define id object_ptr_gnu
#define IMP objc_imp_gnu
#define Method objc_method_gnu

#define object_copy  gnu_object_copy
#define object_dispose  gnu_object_dispose
#define objc_super gnu_objc_super
#define objc_msg_lookup gnu_objc_msg_lookup
#define objc_msg_lookup_super gnu_objc_msg_lookup_super
#define BOOL GNU_BOOL
#define SEL GNU_SEL
#define Protocol GNU_Protocol
#define Class GNU_Class

#undef YES
#undef NO
#undef Nil
#undef nil

#include <objc/objc.h>
#include <objc/objc-api.h>
#undef GNU_BOOL
#include <objc/encoding.h>
#undef Class
#undef Protocol
#undef SEL
#undef objc_msg_lookup
#undef objc_msg_lookup_super
#undef objc_super
#undef Method
#undef IMP
#undef id
#undef objc_object

// Reinstall definitions.
#undef YES
#undef NO
#undef Nil
#undef nil
#define YES ((BOOL)1)
#define NO ((BOOL)0)
#define nil ((id)_OBJC_NULL_PTR)
#define Nil ((Class)_OBJC_NULL_PTR)

#include <string.h>
#include <stdlib.h>
#include <assert.h>

/**
 * Private runtime function for updating a dtable.
 */
void __objc_update_dispatch_table_for_class(Class);
/**
 * Private runtime function for determining whether a class responds to a
 * selector.
 */
BOOL __objc_responds_to(id, SEL);
/**
 *  Runtime library constant for uninitialized dispatch table.
 */
extern struct sarray *__objc_uninstalled_dtable;
/**
 * Mutex used to protect the ObjC runtime library data structures.
 */
extern objc_mutex_t __objc_runtime_mutex;

/** 
 * Looks up the instance method in a specific class, without recursing into
 * superclasses.
 */
static Method
class_getInstanceMethodNonrecursive(Class aClass, SEL aSelector)
{
  struct objc_method_list *methods;
  const char *name = sel_get_name(aSelector);
  const char *types = sel_get_type(aSelector);

  for (methods = aClass->methods;
       methods != NULL; methods = methods->method_next)
    {
      int i;

      for (i = 0; i < methods->method_count; i++)
	{
	  Method_t method = &methods->method_list[i];

	  if (strcmp(sel_get_name(method->method_name), name) == 0)
	    {
	      if (NULL == types || strcmp(types, method->method_types) == 0)
		{
		  return method;
		}
	      // Return NULL if the method exists with this name but has the 
	      // wrong types
	      return NULL;
	    }
	}
    }
  return NULL;
}

static void
objc_updateDtableForClassContainingMethod(Method m)
{
  Class nextClass = Nil;
  void *state;
  SEL sel = method_getName(m);

  while (Nil != (nextClass = objc_next_class(&state)))
    {
      if (class_getInstanceMethodNonrecursive(nextClass, sel) == m)
	{
	  __objc_update_dispatch_table_for_class(nextClass);
	  return;
	}
    }
}


BOOL
class_addIvar(Class cls, const char *name,
  size_t size, uint8_t alignment, const char *types)
{
  struct objc_ivar_list *ivarlist;
  unsigned off;
  Ivar ivar;

  if (CLS_ISRESOLV(cls) || CLS_ISMETA(cls))
    {
      return NO;
    }

  if (class_getInstanceVariable(cls, name) != NULL)
    {
      return NO;
    }

  ivarlist = cls->ivars;

  if (NULL == ivarlist)
    {
      cls->ivars = objc_malloc(sizeof(struct objc_ivar_list));
      cls->ivars->ivar_count = 1;
    }
  else
    {
      ivarlist->ivar_count++;
      // objc_ivar_list contains one ivar.  Others follow it.
      cls->ivars = objc_realloc(ivarlist, sizeof(struct objc_ivar_list)
				+ (ivarlist->ivar_count -
				   1) * sizeof(struct objc_ivar));
    }

  ivar = &cls->ivars->ivar_list[cls->ivars->ivar_count - 1];
  ivar->ivar_name = strdup(name);
  ivar->ivar_type = strdup(types);
  // Round up the offset of the ivar so it is correctly aligned.
  off = cls->instance_size >> alignment;
  if (off << alignment != cls->instance_size)
    off = (off + 1) << alignment;
  ivar->ivar_offset = off;
  // Increase the instance size to make space for this.
  cls->instance_size = ivar->ivar_offset + size;
  return YES;
}

BOOL
class_addMethod(Class cls, SEL name, IMP imp, const char *types)
{
  const char *methodName = sel_get_name(name);
  struct objc_method_list *methods;

  for (methods = cls->methods; methods != NULL;
       methods = methods->method_next)
    {
      int i;

      for (i = 0; i < methods->method_count; i++)
	{
	  Method_t method = &methods->method_list[i];

	  if (strcmp(sel_get_name(method->method_name), methodName) == 0)
	    {
	      return NO;
	    }
	}
    }

  methods = objc_malloc(sizeof(struct objc_method_list));
  methods->method_next = cls->methods;
  cls->methods = methods;

  methods->method_count = 1;
  methods->method_list[0].method_name
    = sel_register_typed_name(methodName, types);
  methods->method_list[0].method_types = strdup(types);
  methods->method_list[0].method_imp = (objc_imp_gnu) imp;

  if (CLS_ISRESOLV(cls))
    {
      __objc_update_dispatch_table_for_class(cls);
    }

  return YES;
}

BOOL
class_addProtocol(Class cls, Protocol * protocol)
{
  struct objc_protocol_list *protocols;

  if (class_conformsToProtocol(cls, protocol))
    {
      return NO;
    }
  protocols = cls->protocols;
  protocols = objc_malloc(sizeof(struct objc_protocol_list));
  if (protocols == NULL)
    {
      return NO;
    }
  protocols->next = cls->protocols;
  protocols->count = 1;
  protocols->list[0] = protocol;
  cls->protocols = protocols;

  return YES;
}

BOOL
class_conformsToProtocol(Class cls, Protocol * protocol)
{
  struct objc_protocol_list *protocols;

  for (protocols = cls->protocols;
       protocols != NULL; protocols = protocols->next)
    {
      int i;

      for (i = 0; i < protocols->count; i++)
	{
	  if (strcmp(protocols->list[i]->protocol_name,
		     protocol->protocol_name) == 0)
	    {
	      return YES;
	    }
	}
    }
  return NO;
}

Ivar *
class_copyIvarList(Class cls, unsigned int *outCount)
{
  struct objc_ivar_list *ivarlist = cls->ivars;
  unsigned int count = 0;
  unsigned int i;
  Ivar *list;

  if (ivarlist != NULL)
    {
      count = ivarlist->ivar_count;
    }
  if (outCount != NULL)
    {
      *outCount = count;
    }
  if (count == 0)
    {
      return NULL;
    }

  list = malloc(count * sizeof(struct objc_ivar *));
  for (i = 0; i < ivarlist->ivar_count; i++)
    {
      list[i] = &(ivarlist->ivar_list[i]);
    }
  return list;
}

Method *
class_copyMethodList(Class cls, unsigned int *outCount)
{
  unsigned int count = 0;
  Method *list;
  Method *copyDest;
  struct objc_method_list *methods;

  for (methods = cls->methods; methods != NULL;
       methods = methods->method_next)
    {
      count += methods->method_count;
    }
  if (outCount != NULL)
    {
      *outCount = count;
    }
  if (count == 0)
    {
      return NULL;
    }

  list = malloc(count * sizeof(struct objc_method *));
  copyDest = list;

  for (methods = cls->methods; methods != NULL;
       methods = methods->method_next)
    {
      unsigned int i;

      for (i = 0; i < methods->method_count; i++)
	{
	  copyDest[i] = &(methods->method_list[i]);
	}
      copyDest += methods->method_count;
    }

  return list;
}

Protocol **
class_copyProtocolList(Class cls, unsigned int *outCount)
{
  struct objc_protocol_list *protocolList = cls->protocols;
  struct objc_protocol_list *list;
  int listSize = 0;
  Protocol **protocols;
  int index;

  for (list = protocolList; list != NULL; list = list->next)
    {
      listSize += list->count;
    }
  if (listSize == 0)
    {
      *outCount = 0;
      return NULL;
    }

  protocols = calloc(listSize, sizeof(Protocol *) + 1);
  index = 0;
  for (list = protocolList; list != NULL; list = list->next)
    {
      memcpy(&protocols[index], list->list, list->count * sizeof(Protocol *));
      index += list->count;
    }
  protocols[listSize] = NULL;
  *outCount = listSize + 1;
  return protocols;
}

id
class_createInstance(Class cls, size_t extraBytes)
{
  id obj = objc_malloc(cls->instance_size + extraBytes);
  obj->isa = cls;
  return obj;
}

Method
class_getInstanceMethod(Class aClass, SEL aSelector)
{
  Method method = class_getInstanceMethodNonrecursive(aClass, aSelector);

  if (method == NULL)
    {
      // TODO: Check if this should be NULL or aClass
      Class superclass = class_getSuperclass(aClass);

      if (superclass == NULL)
	{
	  return NULL;
	}
      return class_getInstanceMethod(superclass, aSelector);
    }
  return method;
}

Method
class_getClassMethod(Class aClass, SEL aSelector)
{
  return class_getInstanceMethod(aClass->class_pointer, aSelector);
}

Ivar
class_getClassVariable(Class cls, const char *name)
{
  assert(0 && "Class variables not implemented");
  return NULL;
}

size_t
class_getInstanceSize(Class cls)
{
  return cls->instance_size;
}

Ivar
class_getInstanceVariable(Class cls, const char *name)
{
  if (name != NULL)
    {
      while (cls != Nil)
	{
	  struct objc_ivar_list *ivarlist = cls->ivars;

	  if (ivarlist != NULL)
	    {
	      int i;

	      for (i = 0; i < ivarlist->ivar_count; i++)
		{
		  Ivar ivar = &ivarlist->ivar_list[i];

		  if (strcmp(ivar->ivar_name, name) == 0)
		    {
		      return ivar;
		    }
		}
	    }
	  cls = class_getSuperclass(cls);
	}
    }
  return NULL;
}

// The format of the char* is undocumented.  This function is only ever used in
// conjunction with class_setIvarLayout().
const char *
class_getIvarLayout(Class cls)
{
  return (char *) cls->ivars;
}

IMP
class_getMethodImplementation(Class cls, SEL name)
{
  struct objc_object_gnu obj = { cls };
  return (IMP) objc_msg_lookup((id) & obj, name);
}

IMP
class_getMethodImplementation_stret(Class cls, SEL name)
{
  struct objc_object_gnu obj = { cls };
  return (IMP) objc_msg_lookup((id) & obj, name);
}

const char *
class_getName(Class cls)
{
  return class_get_class_name(cls);
}

void __objc_resolve_class_links(void);

Class
class_getSuperclass(Class cls)
{
  if (!CLS_ISRESOLV(cls))
    {
      /* This class is not yet resolved ... so lookup superclass by name.
       * We need to allow for this case because we might doing a lookup in
       * a class which has not yet been registered with the runtime and
       * which might have ivars or methods added after this call (so we
       * mustn't resolve this class now).
       */
      return (Class)objc_getClass((const char*)cls->super_class);
    }
  return cls->super_class;
}

int
class_getVersion(Class theClass)
{
  return class_get_version(theClass);
}

const char *
class_getWeakIvarLayout(Class cls)
{
  assert(0 && "Weak ivars not supported");
  return NULL;
}

BOOL
class_isMetaClass(Class cls)
{
  return CLS_ISMETA(cls);
}

IMP
class_replaceMethod(Class cls, SEL name, IMP imp, const char *types)
{
  Method method = class_getInstanceMethodNonrecursive(cls, name);
  IMP old;

  if (method == NULL)
    {
      class_addMethod(cls, name, imp, types);
      return NULL;
    }
  old = (IMP) method->method_imp;
  method->method_imp = (objc_imp_gnu) imp;
  return old;
}


BOOL
class_respondsToSelector(Class cls, SEL sel)
{
  return __objc_responds_to((id) & cls, sel);
}

void
class_setIvarLayout(Class cls, const char *layout)
{
  struct objc_ivar_list *list = (struct objc_ivar_list *) layout;
  size_t listsize = sizeof(struct objc_ivar_list) +
    sizeof(struct objc_ivar) * (list->ivar_count - 1);
  cls->ivars = malloc(listsize);
  memcpy(cls->ivars, list, listsize);
}

OBJC_DEPRECATED Class
class_setSuperclass(Class cls, Class newSuper)
{
  Class oldSuper = cls->super_class;
  cls->super_class = newSuper;
  return oldSuper;
}

void
class_setVersion(Class theClass, int version)
{
  class_set_version(theClass, version);
}

void
class_setWeakIvarLayout(Class cls, const char *layout)
{
  assert(0 && "Not implemented");
}

const char *
ivar_getName(Ivar ivar)
{
  return ivar->ivar_name;
}

ptrdiff_t
ivar_getOffset(Ivar ivar)
{
  return ivar->ivar_offset;
}

const char *
ivar_getTypeEncoding(Ivar ivar)
{
  return ivar->ivar_type;
}

static size_t
lengthOfTypeEncoding(const char *types)
{
  const char *end = objc_skip_argspec(types);
  size_t length;

  end--;
  while (isdigit(*end))
    {
      end--;
    }
  length = end - types + 1;
  return length;
}

static char *
copyTypeEncoding(const char *types)
{
  size_t length = lengthOfTypeEncoding(types);
  char *copy = malloc(length + 1);

  memcpy(copy, types, length);
  copy[length] = '\0';
  return copy;
}

static const char *
findParameterStart(const char *types, unsigned int index)
{
  unsigned int i;

  for (i = 0; i < index; i++)
    {
      types = objc_skip_argspec(types);
      if ('\0' == *types)
	{
	  return NULL;
	}
    }
  return types;
}

char *
method_copyArgumentType(Method method, unsigned int index)
{
  const char *types = findParameterStart(method->method_types, index);

  if (NULL == types)
    {
      return NULL;
    }
  return copyTypeEncoding(types);
}

char *
method_copyReturnType(Method method)
{
  return copyTypeEncoding(method->method_types);
}

void
method_exchangeImplementations(Method m1, Method m2)
{
  IMP tmp = (IMP) m1->method_imp;

  m1->method_imp = m2->method_imp;
  m2->method_imp = (objc_imp_gnu) tmp;
  objc_updateDtableForClassContainingMethod(m1);
  objc_updateDtableForClassContainingMethod(m2);
}

void
method_getArgumentType(Method method,
		       unsigned int index, char *dst, size_t dst_len)
{
  const char *types;
  size_t length;

  types = findParameterStart(method->method_types, index);
  if (NULL == types)
    {
      strncpy(dst, "", dst_len);
      return;
    }
  length = lengthOfTypeEncoding(types);
  if (length < dst_len)
    {
      memcpy(dst, types, length);
      dst[length] = '\0';
    }
  else
    {
      memcpy(dst, types, dst_len);
    }
}

IMP
method_getImplementation(Method method)
{
  return (IMP) method->method_imp;
}

SEL
method_getName(Method method)
{
  return method->method_name;
}

unsigned
method_getNumberOfArguments(Method method)
{
  const char *types = method->method_types;
  unsigned int count = 0;

  while ('\0' != *types)
    {
      types = objc_skip_argspec(types);
      count++;
    }
  return count - 1;
}

void
method_getReturnType(Method method, char *dst, size_t dst_len)
{
  //TODO: Coped and pasted code.  Factor it out.
  const char *types = method->method_types;
  size_t length = lengthOfTypeEncoding(types);

  if (length < dst_len)
    {
      memcpy(dst, types, length);
      dst[length] = '\0';
    }
  else
    {
      memcpy(dst, types, dst_len);
    }
}

const char *
method_getTypeEncoding(Method method)
{
  return method->method_types;
}

IMP
method_setImplementation(Method method, IMP imp)
{
  IMP old = (IMP) method->method_imp;

  method->method_imp = (objc_imp_gnu) old;
  objc_updateDtableForClassContainingMethod(method);
  return old;
}

id
objc_getClass(const char *name)
{
  return (id) objc_get_class(name);
}

int
objc_getClassList(Class * buffer, int bufferLen)
{
  int count = 0;

  if (buffer == NULL)
    {
      void *state = NULL;
      while (Nil != objc_next_class(&state))
	{
	  count++;
	}
    }
  else
    {
      Class nextClass;
      void *state = NULL;

      while (Nil != (nextClass = objc_next_class(&state)) && bufferLen > 0)
	{
	  count++;
	  bufferLen--;
	  *(buffer++) = nextClass;
	}
    }
  return count;
}

id
objc_getMetaClass(const char *name)
{
  Class cls = (Class) objc_getClass(name);
  return cls == Nil ? nil : (id) cls->class_pointer;
}

id
objc_getRequiredClass(const char *name)
{
  id cls = objc_getClass(name);

  if (nil == cls)
    {
      abort();
    }
  return cls;
}

id
objc_lookUpClass(const char *name)
{
  // TODO: Check these are the right way around.
  return (id) objc_lookup_class(name);
}

static void
freeMethodLists(Class aClass)
{
  struct objc_method_list *methods = aClass->methods;
  struct objc_method_list *current;

  while (methods != NULL)
    {
      int i;

      for (i = 0; i < methods->method_count; i++)
	{
	  free((void *) methods->method_list[i].method_types);
	}
      current = methods;
      methods = methods->method_next;
      free(current);
    }
}

static void
freeIvarLists(Class aClass)
{
  struct objc_ivar_list *ivarlist = aClass->ivars;
  int i;

  if (NULL == ivarlist)
    {
      return;
    }

  for (i = 0; i < ivarlist->ivar_count; i++)
    {
      Ivar ivar = &ivarlist->ivar_list[i];

      free((void *) ivar->ivar_type);
      free((void *) ivar->ivar_name);
    }
  free(ivarlist);
}

/*
 * Removes a class from the subclass list found on its super class.
 * Must be called with the objc runtime mutex locked.
 */
static inline void
safe_remove_from_subclass_list(Class cls)
{
  Class sub = cls->super_class->subclass_list;

  if (sub == cls)
    {
      cls->super_class->subclass_list = cls->sibling_class;
    }
  else
    {
      while (sub != NULL)
	{
	  if (sub->sibling_class == cls)
	    {
	      sub->sibling_class = cls->sibling_class;
	      break;
	    }
	  sub = sub->sibling_class;
	}
    }
}

void
objc_disposeClassPair(Class cls)
{
  Class meta = ((id) cls)->isa;

  // Remove from the runtime system so nothing tries updating the dtable
  // while we are freeing the class.
  objc_mutex_lock(__objc_runtime_mutex);
  safe_remove_from_subclass_list(meta);
  safe_remove_from_subclass_list(cls);
  objc_mutex_unlock(__objc_runtime_mutex);

  // Free the method and ivar lists.
  freeMethodLists(cls);
  freeMethodLists(meta);
  freeIvarLists(cls);

  // Free the class and metaclass
  free(meta);
  free(cls);
}

Class
objc_allocateClassPair(Class superclass, const char *name, size_t extraBytes)
{
  Class newClass;
  Class metaClass;

  // Check the class doesn't already exist.
  if (nil != objc_lookUpClass(name))
    {
      return Nil;
    }

  newClass = calloc(1, sizeof(struct objc_class) + extraBytes);

  if (Nil == newClass)
    {
      return Nil;
    }

  // Create the metaclass
  metaClass = calloc(1, sizeof(struct objc_class));

  // Initialize the metaclass
  metaClass->class_pointer = superclass->class_pointer->class_pointer;
  metaClass->super_class = superclass->class_pointer;
  metaClass->name = strdup(name);
  metaClass->info = _CLS_META;
  metaClass->dtable = __objc_uninstalled_dtable;
  metaClass->instance_size = sizeof(struct objc_class);

  // Set up the new class
  newClass->class_pointer = metaClass;
  // Set the superclass pointer to the name.  The runtime will fix this when
  // the class links are resolved.
  newClass->super_class = (Class) superclass->name;
  newClass->name = strdup(name);
  newClass->info = _CLS_CLASS;
  newClass->dtable = __objc_uninstalled_dtable;
  newClass->instance_size = superclass->instance_size;

  return newClass;
}

Class
objc_allocateMetaClass(Class superclass, size_t extraBytes)
{
  Class metaClass = calloc(1, sizeof(struct objc_class) + extraBytes);

  // Initialize the metaclass
  metaClass->class_pointer = superclass->class_pointer->class_pointer;
  metaClass->super_class = superclass->class_pointer;
  metaClass->name = "hidden class"; //strdup(superclass->name);
  metaClass->info = _CLS_RESOLV | _CLS_INITIALIZED | _CLS_META;
  metaClass->dtable = __objc_uninstalled_dtable;
  metaClass->instance_size = sizeof(struct objc_class);

  return metaClass;
}

void *
object_getIndexedIvars(id obj)
{
  if (class_isMetaClass(obj->isa))
    {
      return ((char *) obj) + sizeof(struct objc_class);
    }
  return ((char *) obj) + obj->isa->instance_size;
}

Class
object_getClass(id obj)
{
  if (nil != obj)
    {
      return obj->isa;
    }
  return Nil;
}

Class
object_setClass(id obj, Class cls)
{
  if (nil != obj)
    {
      Class oldClass = obj->isa;

      obj->isa = cls;
      return oldClass;
    }
  return Nil;
}

const char *
object_getClassName(id obj)
{
  return class_getName(object_getClass(obj));
}

void __objc_add_class_to_hash(Class cls);
void __objc_resolve_class_links(void);

void
objc_registerClassPair(Class cls)
{
  Class metaClass = cls->class_pointer;

  // Initialize the dispatch table for the class and metaclass.
  __objc_update_dispatch_table_for_class(metaClass);
  __objc_update_dispatch_table_for_class(cls);
  __objc_add_class_to_hash(cls);
  // Add pointer from super class
  __objc_resolve_class_links();
}

static id
objectNew(id cls)
{
  static SEL newSel = NULL;
  IMP newIMP;

  if (NULL == newSel)
    {
      newSel = sel_get_uid("new");
    }
  newIMP = (IMP) objc_msg_lookup((void *) cls, newSel);
  return newIMP((id) cls, newSel);
}

Protocol *
objc_getProtocol(const char *name)
{
  // Protocols are not centrally registered in the GNU runtime.
  Protocol *protocol = (Protocol *) (objectNew(objc_getClass("Protocol")));

  protocol->protocol_name = (char *) name;
  return protocol;
}

BOOL
protocol_conformsToProtocol(Protocol * p, Protocol * other)
{
  return NO;
}

struct objc_method_description *
protocol_copyMethodDescriptionList(Protocol * p,
				   BOOL isRequiredMethod,
				   BOOL isInstanceMethod, unsigned int *count)
{
  *count = 0;
  return NULL;
}

Protocol **
protocol_copyProtocolList(Protocol * p, unsigned int *count)
{
  *count = 0;
  return NULL;
}

const char *
protocol_getName(Protocol * p)
{
  if (NULL != p)
    {
      return p->protocol_name;
    }
  return NULL;
}

BOOL
protocol_isEqual(Protocol * p, Protocol * other)
{
  if (NULL == p || NULL == other)
    {
      return NO;
    }
  if (p == other || 0 == strcmp(p->protocol_name, other->protocol_name))
    {
      return YES;
    }
  return NO;
}

const char *
sel_getName(SEL sel)
{
  if (sel == 0)
    return "<null selector>";
  return sel_get_name(sel);
}

SEL
sel_getUid(const char *selName)
{
  if (selName == 0)
    return 0;
  return sel_get_uid(selName);
}

BOOL
sel_isEqual(SEL sel1, SEL sel2)
{
  return sel_eq(sel1, sel2) ? YES : NO;
}

SEL
sel_registerName(const char *selName)
{
  if (selName == 0)
    return 0;
  return sel_register_name(selName);
}
