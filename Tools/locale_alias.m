/* locale_alias - Test program to create a file of locale to language name
                  aliases

  Written: Adam Fedor <fedor@gnu.org>
  Date: Oct 2000

  AFAIK: This only works on machines that support setlocale.
  The files created may require hand editing.
*/

#include <stdio.h>
#include <string.h>
#include <dirent.h>
#include <ctype.h>
#include <locale.h>
#include <Foundation/Foundation.h>
#include <base/GSLocale.h>

#define MAXSTRING 100

static int debug=1;

NSMutableDictionary *dict;

int
loc_read_file(const char *dir, const char *file)
{
  FILE *fp;
  char name[1000], *s;
  char buf[1000];
  char locale[MAXSTRING], language[MAXSTRING], country[MAXSTRING];

  if (strcmp(file, "POSIX") == 0)
    return 0;

  sprintf(name, "%s/%s", dir, file);
  fp = fopen(name, "r");
  if (fp == NULL)
    return -1;

  language[0] = '\0';
  country[0] = '\0';
  while (1)
    {
      fgets(buf, MAXSTRING, fp);
      if (strstr(buf, "anguage") != NULL)
	{
	  sscanf(&buf[2], "%s", language);
	}
      if ((s = strstr(buf, "ocale for")) != NULL)
	{
	  strcpy(country, s+10);
	  s = strchr(country, '\n');
	  if (s)
	    *s = '\0';
	}
      if (strlen(language) > 0)
	break;
    }

  strcpy(locale, file);
  if (strlen(country) > 0 && strcmp(country, language) != 0)
    {
      strcat(country, language);
      [dict setObject: [NSString stringWithCString: country] 
	    forKey: [NSString stringWithCString: locale]];
    }
  locale[2] = '\0';
  [dict setObject: [NSString stringWithCString: language] 
	forKey: [NSString stringWithCString: locale]];
  fclose(fp);
  return 0;
}

/* Go through all the files in the directory */
int
loc_get_files(const char *dir)
{
  struct dirent *dp;
  DIR *dirp;

  dirp = opendir(dir);
  while ((dp = readdir(dirp)) != NULL)
    {
      if (isalpha((dp->d_name)[0]))
	{
	  if (debug)
	    printf(" checking %s ...\n", dp->d_name);
	  loc_read_file(dir, dp->d_name);
	}
    }
  closedir(dirp);
  return 0;
}

int
main(int argc, char *argv[])
{
  NSString *lang;
  char *l;
  CREATE_AUTORELEASE_POOL(pool);

  l = setlocale(LC_ALL, "");
  printf("Locale is %s\n", l);

  /* Create Locale.aliases */
  dict = [NSMutableDictionary dictionary];
  loc_get_files("/usr/share/i18n/locales");
  [dict writeToFile: @"Locale.aliases" atomically: NO];

  /* Write out a skeleton file from the current locale */
  dict = GSDomainFromDefaultLocale();
  lang = GSLanguageFromLocale(GSSetLocale(NULL));
  if (lang == nil)
    lang = @"Locale";
  if (dict)
    [dict writeToFile: lang atomically: NO];

  DESTROY(pool);
  return 0;
}
