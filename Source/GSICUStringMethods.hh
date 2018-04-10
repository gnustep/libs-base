
- (instancetype)initWithCharacters: (const unichar *)characters
                            length: (NSUInteger)aLength
{
  str.setTo((const char16_t *)characters, aLength);
  return self;
}

- (id) initWithCharactersNoCopy: (unichar*)characters
                         length: (NSUInteger)aLength
                   freeWhenDone: (BOOL)flag
{
  SetUnicodeStringWithCharacters(str, characters, aLength, flag);
  return self;
}

- (id) initWithBytesNoCopy: (void*)bytes
                    length: (NSUInteger)length
                  encoding: (NSStringEncoding)encoding
              freeWhenDone: (BOOL)flag
{
  if (!SetUnicodeStringWithBytesNoCopy(str, bytes, length, encoding, flag))
    {
      [self release];
      return nil;
    }
  return self;
}


- (id) initWithCStringNoCopy: (char*)characters
                      length: (NSUInteger)aLength
                freeWhenDone: (BOOL)flag
{
  UnicodeString tmp(characters, aLength);
  str = std::move(tmp);
  // Always free early here, because we're converting the text to the internal
  // representation.
  if (flag)
    {
      free(characters);
    }
  return self;
}


- (NSUInteger)length
{
  return str.length();
}

- (unichar)characterAtIndex: (NSUInteger)anIndex
{
  CHECK_INDEX_RANGE_ERROR(anIndex, str.length());
  return str[anIndex];
}

- (void)getCharacters: (unichar *)aBuffer
                range: (NSRange)aRange
{
  GS_RANGE_CHECK(aRange, str.length());
  str.extractBetween(aRange.location, aRange.location + aRange.length, (char16_t*)aBuffer);
}

- (const char*)UTF8String
{
  NSDataByteSink sink;
  str.toUTF8(sink);
  NSData *d = sink.finalise();
  return (const char *)[d bytes];
}

- (NSRange) rangeOfComposedCharacterSequenceAtIndex: (NSUInteger)anIndex
{
  CHECK_INDEX_RANGE_ERROR(anIndex, str.length());
  unichar c = str[anIndex];
  // Special case for CR and LF.  Unicode treats the CR LF sequence as a single
  // grapheme cluster, but we don't.
  if ((c == 0xa) || (c == 0xd))
    {
      return NSMakeRange(anIndex, 1);
    }
  auto *bi = get_thread_break_iterator();
  NSAssert(bi != nullptr, @"Failed to access per-thread character break iterator");
  bi->setText(str);
  NSRange r;
  if (bi->isBoundary(anIndex))
    {
      r = NSMakeRange(anIndex, bi->following(anIndex)-anIndex);
    }
  else
    {
      auto start = bi->preceding(anIndex);
      auto end = bi->next();
      r = NSMakeRange(start, end-start);
    }
  return r;
}

- (BOOL)isEqualToString: (NSString*)aString
{
  NSStringUnicodeString other(aString);
  return str == other;
}

- (NSComparisonResult)compare: (NSString *)aString
                      options: (NSStringCompareOptions)mask
                        range: (NSRange)aRange
                       locale: (id)aLocale
{
  GS_RANGE_CHECK(aRange, str.length());
  // FIXME: Non-default Locale
  Collator *coll = get_default_collator();
  icu::UnicodeString substring = str.tempSubString(aRange.location, aRange.length);
  NSStringUnicodeString other(aString);
  UErrorCode status = U_ZERO_ERROR;
  coll->setStrength(mask & NSCaseInsensitiveSearch
                      ? Collator::SECONDARY
                      : Collator::TERTIARY);
  coll->setAttribute(UCOL_NUMERIC_COLLATION,
                     mask & NSNumericSearch ? UCOL_ON : UCOL_OFF,
                     status);
  switch (coll->compare(str, other))
    {
      case Collator::LESS:
        return NSOrderedAscending;
      case Collator::EQUAL:
        return NSOrderedSame;
      case Collator::GREATER:
        return NSOrderedDescending;
    }
  __builtin_unreachable();
}

- (id)copyWithZone: (NSZone*)aZone
{
  STRING_CLASS *other = [STRING_CLASS allocWithZone: aZone];
  other->str = str;
  return other;
}

- (icu::UnicodeString*)_icuInternalString
{
  return &str;
}

#undef STRING_CLASS
