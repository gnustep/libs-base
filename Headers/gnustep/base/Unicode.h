#ifndef __Unicode_h_OBJECTS_INCLUDE
#define __Unicode_h_OBJECTS_INCLUDE

unichar encode_chartouni(char c, NSStringEncoding enc);
char encode_unitochar(unichar u, NSStringEncoding enc);
unichar chartouni(char c);
char unitochar(unichar u);
int strtoustr(unichar * u1,const char *s1,int size);
int ustrtostr(char *s2,unichar *u1,int size);
int uslen (unichar *u);
unichar uni_tolower(unichar ch);
unichar uni_toupper(unichar ch);
unsigned char uni_cop(unichar u);
BOOL uni_isnonsp(unichar u);
unichar *uni_is_decomp(unichar u);

#endif /* __Unicode_h_OBJECTS_INCLUDE */
