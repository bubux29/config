%{
#include <stdio.h>

#include "config_types.h"

#include "str/strhelper.h"
#define _BLK_LOG_LEVEL hbsender_logLevel
#include "log/api/logger.h"
extern int hbsender_logLevel;

/*#define LOCAL static*/
#define LOCAL

int yywrap(void);

typedef enum {
  NEW_MONITOR = 256,
  NEW_MONITOR_NAME = 255,
  NEW_MONITOR_CONFIG = 254,
  NEW_MONITOR_DRIVER = 253,
  NEW_CHECK = 252,
  NEW_CHECK_NAME = 251,
  NEW_CHECK_CONFIG = 250,
  NEW_CHECK_PERIODE = 249,
  NEW_THRESHOLD = 248,
  NEW_THRESHOLD_COMP = 247,
  NEW_THRESHOLD_LEVEL = 246,
  NEW_THRESHOLD_KEY = 245,
  NEW_THRESHOLD_VAL = 244,
  NEW_AGE_THRESHOLD = 243,
  SYNTAX_ERROR = 1,
} etoken_t;

union lex_opt {
  char *str;
  int val;
};

static int line_counter = 1;
static int col_index = 0;
static char* snmp_options = NULL;
static union lex_opt options = { .str = NULL };
static int ret = 0;
%}

%x MONITOR SYNTAX_FILE_ERROR MONITOR_NAME MONITOR_CONFIG MONITOR_DRIVER CHECK CHECK_NAME CHECK_CONFIG CHECK_PERIODE THRESHOLD_KEY THRESHOLD_LEVEL THRESHOLD_COMP THRESHOLD_VAL THRESHOLD

%option outfile="config_lex.c" header-file="config_lex.h"

%%
\n	{ line_counter++; }
[ \t]			/* */
.	{ printf ("%s", yytext); }
^\[[ ]*monitor[ ]*\].*$	{ 
			BEGIN MONITOR;
			return NEW_MONITOR;
			}
<SYNTAX_FILE_ERROR>[^\n]+	{
				err ("Unexpected configuration line at %d:"
                                     "\'%s\'\n", line_counter, yytext);
				return SYNTAX_ERROR;
				}
<MONITOR>\n	{ line_counter++; }
<MONITOR>[- \t]	/* */
<MONITOR>.	{ BEGIN SYNTAX_FILE_ERROR; yymore(); }
<MONITOR>name[ ]*=[ ]*		{ BEGIN MONITOR_NAME; }
<MONITOR>driver[ ]*=[ ]*	{ BEGIN MONITOR_DRIVER; }
<MONITOR>config[ ]*=[ ]*	{ BEGIN MONITOR_CONFIG; }
<MONITOR_NAME>[^ \t\n]+	{
			options.str = strdup (yytext);
			BEGIN MONITOR;
			return NEW_MONITOR_NAME;
			}
<MONITOR_DRIVER>[^ \t\n]+	{
			options.str = strdup (yytext);
			BEGIN MONITOR;
			return NEW_MONITOR_DRIVER;
			}
<MONITOR_CONFIG>[^\t\n]+	{
			options.str = strdup (yytext);
			BEGIN MONITOR;
			return NEW_MONITOR_CONFIG;
			}
<MONITOR>\[[ ]*check[ ]*\]	{ BEGIN CHECK; return NEW_CHECK; }
<CHECK>name[ ]*=[ ]*	{ BEGIN CHECK_NAME; }
<CHECK>config[ ]*=[ ]*	{ BEGIN CHECK_CONFIG; }
<CHECK>periode[ ]*=[ ]*	{ BEGIN CHECK_PERIODE; }
<CHECK>\n	{ line_counter++; }
<CHECK>[- \t]	/* */
<CHECK>.	{ BEGIN SYNTAX_FILE_ERROR; yymore(); }
<CHECK_NAME>[^\n]+		{
			options.str = strdup (yytext);
			BEGIN CHECK;
			return NEW_CHECK_NAME;
			}
<CHECK_CONFIG>[^\n]+	{
			options.str = strdup (yytext);
			BEGIN CHECK;
			return NEW_CHECK_CONFIG;
			}
<CHECK_PERIODE>[^\n]+	{
			options.str = strdup(yytext);
			BEGIN CHECK;
			return NEW_CHECK_PERIODE;
			}
<CHECK>\[[ ]*check[ ]*\]	{
				err ("Bad configuration, missing thresholds at line %d\n", line_counter);
				return SYNTAX_ERROR;
				}
<CHECK>\[[ ]*age_threshold[ ]*\]	{
				BEGIN THRESHOLD;
				return NEW_AGE_THRESHOLD;
				}
<CHECK>\[[ ]*threshold[ ]*\]	{
			BEGIN THRESHOLD;
			return NEW_THRESHOLD;
			}
<THRESHOLD>\[[ ]*threshold[ ]*\]	{
			BEGIN THRESHOLD;
			/*printf ("New threshold coming in\n");*/
			return NEW_THRESHOLD;
			}
<THRESHOLD>\n	{ line_counter++; }
<THRESHOLD>[- \t]	/* */
<THRESHOLD>.	{ BEGIN SYNTAX_FILE_ERROR; yymore(); }
<THRESHOLD>\[[ ]*check[ ]*\] {
			BEGIN CHECK;
			return NEW_CHECK;
			}
<THRESHOLD>\[[ ]*monitor[ ]*\] {
			BEGIN MONITOR;
			return NEW_MONITOR;
			}
<THRESHOLD>threshold[ ]*=[ ]*	{ BEGIN THRESHOLD_COMP; }
<THRESHOLD>level[ ]*=[ ]*	{ BEGIN THRESHOLD_LEVEL; }
<THRESHOLD>key[ ]*=[ ]*	{ BEGIN THRESHOLD_KEY; }
<THRESHOLD_COMP>"<"		{
			BEGIN THRESHOLD_VAL;
			options.val = E_HBS_INF;
			return NEW_THRESHOLD_COMP;
			}
<THRESHOLD_COMP>">"		{
			BEGIN THRESHOLD_VAL;
			options.val = E_HBS_SUP;
			return NEW_THRESHOLD_COMP;
			}
<THRESHOLD_COMP>"=="		{
			BEGIN THRESHOLD_VAL;
			options.val = E_HBS_EQU;
			return NEW_THRESHOLD_COMP;
			}
<THRESHOLD_COMP>.	{ BEGIN SYNTAX_FILE_ERROR; yymore(); }
<THRESHOLD_VAL>[^\n]+	{
			options.str = strdup (yytext);
			BEGIN THRESHOLD;
			return NEW_THRESHOLD_VAL;
			}
<THRESHOLD_LEVEL>"warning"	{
			options.val = E_HB_WARNING;
			BEGIN THRESHOLD;
			return NEW_THRESHOLD_LEVEL;
			}
<THRESHOLD_LEVEL>"failure"	{
			options.val = E_HB_ALERT;
			BEGIN THRESHOLD;
			return NEW_THRESHOLD_LEVEL;
			}
<THRESHOLD_LEVEL>.	{ BEGIN SYNTAX_FILE_ERROR; yymore(); }
<THRESHOLD_KEY>[^\n]+	{
			options.str = strdup(yytext);
			BEGIN THRESHOLD;
			return NEW_THRESHOLD_KEY;
			}
.	;
%%


int yywrap(void)
{
  return 1;
}

struct hbs_driver *new_support ( char *name )
{
  struct hbs_driver *p = (struct hbs_driver*) calloc (sizeof(struct hbs_driver), 1);

  p->config_name = name;
  return p;
}

struct hbs_check *new_check ( char *name )
{
  struct hbs_check *p = (struct hbs_check*) calloc (sizeof(struct hbs_check), 1);

  p->check_name = name;
  p->next = NULL;
  return p;
}

struct hbs_check_threshold *new_check_threshold ( void )
{
  struct hbs_check_threshold *p = (struct hbs_check_threshold*) calloc (sizeof(struct hbs_check_threshold), 1);

  return p;
}

#define APPEND_TO_LIST_(list,new_elem,cursor,test) \
do {                                                                           \
                                                                               \
  if (list == NULL) return -1;                                                 \
                                                                               \
  if (*list == NULL) {                                                         \
    debug ("Creating new list at %p", new_elem);                               \
    *list = new_elem;                                                          \
    new_elem->next = NULL;                                                     \
  } else {                                                                     \
    debug ("Appending to %p", *list);                                          \
    for ( cursor = *list; test; cursor = cursor->next ) ;                      \
    new_elem->next = cursor->next;                                             \
    cursor->next = new_elem;                                                   \
  }                                                                            \
} while (0)

#define TEST_SIMPLE(c) ( c != NULL )
#define TEST_SORT(c,n,field) ( c != NULL && c->field > n->field )

#define APPEND_TO_LIST(list,cursor,new_elem) \
                      APPEND_TO_LIST_(list,new_elem,cursor,TEST_SIMPLE(cursor->next))

#define APPEND_TO_LIST_SORTED(list,new_elem,cursor,field)  \
  APPEND_TO_LIST_(list,new_elem,cursor,TEST_SORT(cursor->next,new_elem,field))

LOCAL int append_new_support ( struct hbs_driver **plist, struct hbs_driver *new )
{
  struct hbs_driver *p;

  APPEND_TO_LIST(plist,p,new);

  return 0;
}

LOCAL int append_new_check ( struct hbs_check **plist, struct hbs_check *new )
{
  struct hbs_check *p;

  APPEND_TO_LIST(plist,p,new);

  return 0;
}

LOCAL int append_new_check_threshold ( struct hbs_check_threshold **plist, struct hbs_check_threshold *new )
{
  struct hbs_check_threshold *p;

  APPEND_TO_LIST(plist,p,new);

  return 0;
}

LOCAL int append_new_check_sorted ( struct hbs_check **plist, struct hbs_check *new )
{
  struct hbs_check *p;

  APPEND_TO_LIST_SORTED(plist,p,new,check_periode);

  return 0;
}

#define ADD_NEW_(p,elem,str,val,ret,func)                                      \
  ret = func( &val, str, NULL, 0 );                                            \
  free(str);                                                                   \
  if (ret != 0) {                                                              \
    fprintf (stderr, "Line malformed at : %d\n%s\n", line_counter, val);       \
  } else {                                                                     \
    ADD_NEW_ELEM(p, elem, val, ret);                                           \
  }

#define ADD_NEW_INT_ELEM(p,elem,str,val,ret) \
                                  ADD_NEW_(p,elem,str,val,ret,get_int)
#define ADD_NEW_UINT_ELEM(p,elem,str,val,ret) \
                                  ADD_NEW_(p,elem,str,val,ret,get_uint)

#define ADD_NEW_ELEM(p,elem,new,ret)                                           \
  do {                                                                         \
    ret = 0;                                                                   \
    if (p != NULL) {                                                           \
      if (p->elem == (typeof(p->elem)) 0) {                                    \
        p->elem = new;                                                         \
      } else {                                                                 \
        fprintf( stderr,                                                       \
                 "Oups, strange allocation, %s defined twice at line %d\n",    \
                 #elem, line_counter);                                         \
        ret = -1;                                                              \
      }                                                                        \
    } else {                                                                   \
          fprintf ( stderr, "Strange case\n" );                                \
          ret = -1;                                                            \
    }                                                                          \
  } while(0)

int hbs_config_parser ( FILE *stream, struct hbs_configuration **pconfig_out )
{
  int ret = 0;
  struct hbs_check_threshold *pthreshold = NULL;
  struct hbs_check *pcheck = NULL;
  struct hbs_driver *pdriver = NULL;
  etoken_t toktok;
  int vald;

  yyin = stream;
  if ( pconfig_out == NULL ) {
    return -1;
  } else {
    *pconfig_out = (struct hbs_configuration*) calloc (1, sizeof(struct hbs_configuration));
    if ( *pconfig_out == NULL ) {
      fatal ( "Out of memory for configuration..." );
      return -2;
    }
  }

  info ("Beginning of configuration file parsing");
  while ( ret == 0 && (( toktok = yylex() ) > 0) ) {
    switch (toktok) {
      case NEW_MONITOR:
        pdriver = new_support ( NULL );
        ret = append_new_support (&(*pconfig_out)->drivers, pdriver);
        debug ("Appending new support at %p", (*pconfig_out)->drivers);
      break;
      case NEW_MONITOR_NAME:
        ADD_NEW_ELEM(pdriver, config_name, options.str, ret);
        debug ("Appending new support name: %s", pdriver->config_name);
      break;
      case NEW_MONITOR_CONFIG:
        ADD_NEW_ELEM(pdriver, config_params, options.str, ret);
        debug ("Appending new support config: %s", pdriver->config_params);
      break;
      case NEW_MONITOR_DRIVER:
        ADD_NEW_ELEM(pdriver, driver_name, options.str, ret);
        debug ("Appending new support driver name: %s", pdriver->driver_name);
        break;
      case NEW_CHECK:
        pcheck = new_check ( NULL );
        debug ("Creating new check at %p\n", pcheck);
        ret = append_new_check (&pdriver->check_list, pcheck);
      break;
      case NEW_CHECK_NAME:
        ADD_NEW_ELEM(pcheck, check_name, options.str, ret);
      break;
      case NEW_CHECK_CONFIG:
        ADD_NEW_ELEM(pcheck, check_config, options.str, ret);
      break;
      case NEW_CHECK_PERIODE:
        ADD_NEW_INT_ELEM(pcheck, check_periode, options.str, vald, ret);
      break;
      case NEW_THRESHOLD:
        pthreshold = new_check_threshold();
        debug ("Appending to check at %p\n", pcheck);
        ret = append_new_check_threshold(&pcheck->threshold_list, pthreshold);
      break;
      case NEW_AGE_THRESHOLD:
        pthreshold = new_check_threshold();
        ret = append_new_check_threshold(&pcheck->check_age, pthreshold);
      break;
      case NEW_THRESHOLD_COMP:
        ADD_NEW_ELEM(pthreshold, threshold_comparator, options.val, ret);
      break;
      case NEW_THRESHOLD_LEVEL:
        ADD_NEW_ELEM(pthreshold, threshold_level, options.val, ret);
      break;
      case NEW_THRESHOLD_KEY:
        ADD_NEW_UINT_ELEM(pthreshold, threshold_key, options.str, vald, ret);
      break;
      case NEW_THRESHOLD_VAL:
        ret = get_int(&vald, options.str, NULL, 0);
        if ( ret == 0 ) {
          free (options.str);
          ADD_NEW_ELEM(pthreshold, threshold_value.data.val, vald, ret);
          pthreshold->threshold_value.type = E_HBS_TYPE_INT;
        } else { /* If we cannot get an int out of cmdline,
                  * this means we'll consider it as a string...
                  */
          ADD_NEW_ELEM( pthreshold, threshold_value.data.str, options.str, ret );
          pthreshold->threshold_value.type = E_HBS_TYPE_STR;
        }
      break;
      case SYNTAX_ERROR:
        fprintf (stderr, "Warning, bad configuration file syntax at line %d\n", line_counter);
        ret = -1;
      break;
      default:
      break;
    }
  }

  return ret;
}