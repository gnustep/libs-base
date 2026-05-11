#import <Foundation/Foundation.h>

#import "Testing.h"

/*
 * Tests for rangeOfComposedCharacterSequenceAtIndex.
 *
 * Each test probes one or more indices in a UTF-16 string and verifies that
 * the returned range matches the expected grapheme-cluster boundary, exactly
 * mirroring what -[NSString rangeOfComposedCharacterSequenceAtIndex:] would
 * return on Apple platforms.
 */

/* ------------------------------------------------------------------ helpers */

static BOOL range_eq(NSRange a, NSRange b) {
  return a.location == b.location && a.length == b.length ? YES : NO;
}


static void check(const char *label,
  const uint16_t *buf, size_t buf_len,
  int probe_index,
  NSRange expected)
{
  NSString *s = [NSString stringWithCharacters: buf length: buf_len];

  NSRange got = [s rangeOfComposedCharacterSequenceAtIndex: probe_index];

  PASS(range_eq(got, expected), "%s at index %d" , label, probe_index)
  if (!testPassed)
    {
      NSLog(@"Got %@ expected %@", NSStringFromRange(got), NSStringFromRange(expected));
    }
}

/* ------------------------------------------------------------------ tests -- */

/* Helper: length of a uint16_t literal array */
#define ULEN(arr) (sizeof(arr)/sizeof((arr)[0]))

static int	i;

/*
 * 1. Plain ASCII — every code point is its own grapheme cluster.
 *    "Hello" → 5 clusters, each length 1.
 */
static void test_ascii(void)
{
  puts("\n[1] Plain ASCII");
  static const uint16_t buf[] = { 'H','e','l','l','o' };
  size_t n = ULEN(buf);
  for (i = 0; i < n; ++i)
      check("ASCII", buf, n, i, (NSRange){i, 1});
}

/*
 * 2. Combining diacritics (NFD form).
 *    "é" = U+0065 U+0301 (e + combining acute) → one cluster of length 2.
 *    Probing index 0 or 1 should both return {0, 2}.
 */
static void test_combining_diacritic(void) {
    puts("\n[2] Combining diacritic (NFD é = U+0065 U+0301)");
    static const uint16_t buf[] = { 0x0065, 0x0301 };
    size_t n = ULEN(buf);
    check("e+combining-acute idx=0", buf, n, 0, (NSRange){0, 2});
    check("e+combining-acute idx=1", buf, n, 1, (NSRange){0, 2});
}

/*
 * 3. Multiple clusters with combining marks.
 *    "àé" in NFD: U+0061 U+0300  U+0065 U+0301
 *    Clusters: [0,2) and [2,2).
 */
static void test_multiple_combining(void) {
    puts("\n[3] Multiple NFD clusters (à é)");
    /* à   = U+0061 U+0300,  é = U+0065 U+0301 */
    static const uint16_t buf[] = { 0x0061, 0x0300, 0x0065, 0x0301 };
    size_t n = ULEN(buf);
    check("à idx=0", buf, n, 0, (NSRange){0, 2});
    check("à idx=1", buf, n, 1, (NSRange){0, 2});
    check("é idx=2", buf, n, 2, (NSRange){2, 2});
    check("é idx=3", buf, n, 3, (NSRange){2, 2});
}

/*
 * 4. Emoji with surrogate pair.
 *    U+1F600 GRINNING FACE encoded as surrogate pair: U+D83D U+DE00.
 *    Both code units belong to the same cluster {0,2}.
 */
static void test_surrogate_pair_emoji(void) {
    puts("\n[4] Surrogate pair emoji (U+1F600)");
    static const uint16_t buf[] = { 0xD83D, 0xDE00 };
    size_t n = ULEN(buf);
    check("😀 lead surrogate  idx=0", buf, n, 0, (NSRange){0, 2});
    check("😀 trail surrogate idx=1", buf, n, 1, (NSRange){0, 2});
}

/*
 * 5. Emoji + variation selector.
 *    U+2764 HEAVY BLACK HEART + U+FE0F VARIATION SELECTOR-16 → one cluster.
 *    Both BMP, no surrogates; cluster length = 2.
 */
static void test_emoji_variation_selector(void) {
    puts("\n[5] Emoji + variation selector (❤️ = U+2764 U+FE0F)");
    static const uint16_t buf[] = { 0x2764, 0xFE0F };
    size_t n = ULEN(buf);
    check("❤️ idx=0", buf, n, 0, (NSRange){0, 2});
    check("❤️ idx=1", buf, n, 1, (NSRange){0, 2});
}

/*
 * 6. Emoji modifier sequence.
 *    U+1F44B WAVING HAND SIGN + U+1F3FD EMOJI MODIFIER FITZPATRICK TYPE-4.
 *    Each is a surrogate pair, so the buffer is 4 code units, 1 cluster.
 *    👋 = D83D DC4B,  🏽 = D83C DFFد
 */
static void test_emoji_modifier(void) {
    puts("\n[6] Emoji + skin-tone modifier (👋🏽, 4 code units)");
    /* U+1F44B → D83D DC4B,  U+1F3FD → D83C DFFD */
    static const uint16_t buf[] = { 0xD83D, 0xDC4B, 0xD83C, 0xDFFD };
    size_t n = ULEN(buf);
    for (i = 0; i < n; ++i)
        check("👋🏽", buf, n, i, (NSRange){0, 4});
}

/*
 * 7. Regional indicator pair (flag emoji).
 *    🇺🇸 = U+1F1FA U+1F1F8.
 *    Each is a surrogate pair: D83C DDFA  D83C DDF8 → 4 code units, 1 cluster.
 */
static void test_flag_emoji(void) {
    puts("\n[7] Flag emoji 🇺🇸 (regional indicator pair, 4 code units)");
    static const uint16_t buf[] = { 0xD83C, 0xDDFA, 0xD83C, 0xDDF8 };
    size_t n = ULEN(buf);
    for (i = 0; i < n; ++i)
        check("🇺🇸", buf, n, i, (NSRange){0, 4});
}

/*
 * 8. ZWJ sequence: man + ZWJ + laptop.
 *    👨 U+1F468 (D83D DC68) + U+200D ZWJ + 💻 U+1F4BB (D83D DCBB)
 *    = 5 code units, 1 grapheme cluster.
 */
static void test_zwj_sequence(void) {
    puts("\n[8] ZWJ sequence 👨‍💻 (man+zwj+laptop, 5 code units)");
    static const uint16_t buf[] = {
        0xD83D, 0xDC68,   /* U+1F468 MAN         */
        0x200D,           /* ZWJ                  */
        0xD83D, 0xDCBB    /* U+1F4BB LAPTOP       */
    };
    size_t n = ULEN(buf);
    for (i = 0; i < n; ++i)
        check("👨‍💻", buf, n, i, (NSRange){0, 5});
}

/*
 * 9. Hangul syllable — precomposed (NFC).
 *    U+AC00 가 is a single precomposed Hangul syllable → cluster {0,1}.
 */
static void test_hangul_precomposed(void) {
    puts("\n[9] Hangul precomposed syllable 가 (U+AC00)");
    static const uint16_t buf[] = { 0xAC00 };
    check("가", buf, 1, 0, (NSRange){0, 1});
}

/*
 * 10. Hangul jamo (NFD-like): L + V + T decomposed.
 *     가 decomposed: U+1100 (ᄀ) + U+1161 (ᅡ) → 2-unit cluster.
 *     (T is optional; we test L+V here.)
 */
static void test_hangul_jamo(void) {
    puts("\n[10] Hangul jamo L+V (ᄀ U+1100 + ᅡ U+1161)");
    static const uint16_t buf[] = { 0x1100, 0x1161 };
    size_t n = ULEN(buf);
    check("가 idx=0", buf, n, 0, (NSRange){0, 2});
    check("가 idx=1", buf, n, 1, (NSRange){0, 2});
}

/*
 * 11. Mixed content: ASCII + emoji + combining + ASCII.
 *     "A😀éB" in NFD:
 *       A        → U+0041              [0,1)
 *       😀       → D83D DE00           [1,3)
 *       é (NFD)  → U+0065 U+0301      [3,5)
 *       B        → U+0042              [5,6)
 */
static void test_mixed(void) {
    puts("\n[11] Mixed: A + 😀 + é(NFD) + B");
    static const uint16_t buf[] = {
        0x0041,               /* A  */
        0xD83D, 0xDE00,       /* 😀 */
        0x0065, 0x0301,       /* é  */
        0x0042                /* B  */
    };
    size_t n = ULEN(buf);
    check("A",   buf, n, 0, (NSRange){0, 1});
    check("😀 lead",  buf, n, 1, (NSRange){1, 2});
    check("😀 trail", buf, n, 2, (NSRange){1, 2});
    check("é base",   buf, n, 3, (NSRange){3, 2});
    check("é comb",   buf, n, 4, (NSRange){3, 2});
    check("B",        buf, n, 5, (NSRange){5, 1});
}

/*
 * 12. Single BMP character — edge case with len=1.
 */
static void test_single_char(void) {
    puts("\n[12] Single BMP character");
    static const uint16_t buf[] = { 0x03A9 }; /* Ω */
    check("Ω", buf, 1, 0, (NSRange){0, 1});
}

/* ------------------------------------------------------------------ main --- */

int
main(void)
{
  ENTER_POOL

  test_ascii();
  test_combining_diacritic();
  test_multiple_combining();
  test_surrogate_pair_emoji();
  test_emoji_variation_selector();
  test_emoji_modifier();
  test_flag_emoji();
  test_zwj_sequence();
  test_hangul_precomposed();
  test_hangul_jamo();
  test_mixed();
  test_single_char();

  LEAVE_POOL
  return 0;
}
