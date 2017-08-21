%{
#include <stdio.h>

#include "std_types.h"

int yywrap (void)
{
  return 1;
}

#define error(arg,str) \
do { \
  printf ("ERROR: " arg " at line: %d\n%s\n", line_counter, str); \
  return E_BAD_SYNTAX; \
} while (0)
#define show_error(str) \
do { \
  printf ("Bad line is: \n%s\n", str); \
} while(0)

int line_counter = 1;
int current_level = 0;

static char *type_names[] = {
  [UINT8_t] = "uint8_t",
  [INT8_t] = "int8_t",
  [UINT16_t] = "uint16_t",
  [INT16_t] = "int16_t",
  [UINT32_t] = "uint32_t",
  [INT32_t]  = "int32_t",
  [UINT64_t] = "uint64_t",
  [INT64_t]  = "int64_t",
  [INT_t]    = "int",
  [UINT_t]   = "unsigned int",
  [FLOAT_t]  = "float",
  [DOUBLE_t] = "double",
  [STRING_t] = "char *",
};

/* Machine states */
enum mac_states {
  E_GOTO_LEVEL = 256,
  E_NEW_LEVEL,
  E_COUNT_LEVEL,
  E_NEW_ENUM,
  E_ENUM_TYPE_NAME,
  E_NEW_ENUM_VAL,
  E_DEFINE_ENUM,
  E_TYPE_NAME,
  E_FIELD_NAME,
  E_TYPE_IS_A_LIST,
  E_BAD_SYNTAX,
};

union shared_val {
  enum known_type type_name;
  char *str;
  int num_level;
};

union shared_val options = { .str = NULL, };

%}

/* Definition des etats */
%x NEW_LEVEL COUNT_LEVEL NEW_ENUM ENUM_VARNAME ENUM_VAL NEW_TYPE FLUSH_LINE UNSIGNED HANDLE_ERROR TEST_TYPE_LIST NEW_LEVEL_NAME COMMENT

%option outfile="xsdcfgfile_parser.c" header-file="xsdcfgfile_parser.h"

%%
<!--		{ BEGIN COMMENT; }
<COMMENT>-->	{ BEGIN 0; }
<COMMENT>[^\n]	;
\n		{ line_counter++; }
-		{
		printf ("beurk cant bear '-' char, at line %d\n", line_counter);
		return -1;
		}
<xs:element[[:space:]]*	{ current_level = 0; BEGIN NEW_ELEMENT; }
"["		{ current_level = 0; BEGIN NEW_LEVEL; return E_GOTO_LEVEL; }
^\t		{ current_level = 1; BEGIN COUNT_LEVEL; yyless(1); }
 /*[\t]*"enum "[ ]*	{ BEGIN NEW_ENUM; } */
 /*^enum		{ BEGIN NEW_ENUM; }*/
[\t]*enum[ ]*	{ BEGIN NEW_ENUM; }
 /*.		{ error("Unexpected char"); }*/
int8_t[ ]+	{
		options.type_name = INT8_t;
		BEGIN NEW_TYPE;
		return E_TYPE_NAME;
		}
uint8_t[ ]+	{
		options.type_name = UINT8_t;
		BEGIN NEW_TYPE;
		return E_TYPE_NAME; }
uint16_t[ ]+	{
		options.type_name = UINT16_t;
		BEGIN NEW_TYPE;
		return E_TYPE_NAME; }
int16_t[ ]+	{
		options.type_name = INT16_t;
		BEGIN NEW_TYPE;
		return E_TYPE_NAME;
		}
uint32_t[ ]+	{
		options.type_name = UINT32_t;
		BEGIN NEW_TYPE;
		return E_TYPE_NAME;
		}
int32_t[ ]+	{
		options.type_name = INT32_t;
		BEGIN NEW_TYPE;
		return E_TYPE_NAME;
		}
uint64_t[ ]+	{
		options.type_name = UINT64_t;
		BEGIN NEW_TYPE;
		return E_TYPE_NAME;
		}
int64_t[ ]+	{
		options.type_name = INT64_t;
		BEGIN NEW_TYPE;
		return E_TYPE_NAME;
		}
unsigned[ ]+	{
		printf ("Known unsigned at %d\n", line_counter);
		BEGIN UNSIGNED;
		}
int[ ]+		{
		options.type_name = INT_t;
		BEGIN NEW_TYPE;
		return E_TYPE_NAME;
		}
char[ ]+	{
		options.type_name = INT8_t;
		BEGIN NEW_TYPE;
		return E_TYPE_NAME;
		}
<UNSIGNED>int[ ]+	{
			options.type_name = UINT_t;
			BEGIN NEW_TYPE;
			return E_TYPE_NAME;
			}
<UNSIGNED>char[ ]+	{
		options.type_name = UINT8_t;
		BEGIN NEW_TYPE;
		return E_TYPE_NAME;
		}
wuchar[ ]+	{
		options.type_name = UINT16_t;
		BEGIN NEW_TYPE;
		return E_TYPE_NAME;
		}
wchar[ ]+	{
		options.type_name = INT16_t;
		BEGIN NEW_TYPE;
		return E_TYPE_NAME;
		}
float_t[ ]+	{
		options.type_name = FLOAT_t;
		BEGIN NEW_TYPE;
		return E_TYPE_NAME;
		}
double_t[ ]+	{
		options.type_name = DOUBLE_t;
		BEGIN NEW_TYPE;
		return E_TYPE_NAME;
		}
<NEW_TYPE>[^ \t\n\[\]]+	{
			options.str = strdup (yytext);
			BEGIN TEST_TYPE_LIST;
			return E_FIELD_NAME;
			}
<NEW_TYPE>[ \t]+$	;
<NEW_TYPE>[^[:alpha:]]	{ BEGIN HANDLE_ERROR; yymore(); }
<TEST_TYPE_LIST>\[\]	{ BEGIN FLUSH_LINE; return E_TYPE_IS_A_LIST; }
<TEST_TYPE_LIST>.	{ /*yyless(0);*/ BEGIN FLUSH_LINE; }
<TEST_TYPE_LIST>\n	{ line_counter++; BEGIN 0; }
 /*<NEW_TYPE>\n	{
		yyless(0);
		line_counter++;
		BEGIN 0;
		return E_TYPE_VARNAME;
		} */
<COUNT_LEVEL>\t	{ current_level++; }
<COUNT_LEVEL>"["	{ BEGIN NEW_LEVEL; return E_GOTO_LEVEL; }
<COUNT_LEVEL>[^\[]	{ BEGIN 0;  yyless(0); } /* ce n'est pas un niveau */
<NEW_LEVEL>\n	{ BEGIN 0; line_counter++; }
<NEW_LEVEL>[ ]*	/* */
<NEW_LEVEL>"][^[:alpha:]*\n"	{ BEGIN HANDLE_ERROR; }
<NEW_LEVEL>"] "	{ printf ("end of parsing new_level\n"); BEGIN NEW_LEVEL_NAME; }
<NEW_LEVEL>[^ \]\n]*	{
			options.str = strdup (yytext);
			return E_NEW_LEVEL;
			}
<NEW_LEVEL_NAME>\n	{ BEGIN 0; line_counter++; }
<NEW_LEVEL_NAME>[ ]+	;
<NEW_LEVEL_NAME>[^\n\[]+	{
				options.str = strdup (yytext);
				BEGIN TEST_TYPE_LIST;
				return E_FIELD_NAME;
				}
<FLUSH_LINE>[^ \t\n]	{
			BEGIN HANDLE_ERROR;
			yymore();
			}
<FLUSH_LINE>[ \t]*	;
<FLUSH_LINE>\n		{
			line_counter++;
			BEGIN 0;
			}
<NEW_ENUM>=	{ error ("Unexpected token", yytext); }
<NEW_ENUM>[^ ]+	{ options.str = strdup(yytext); BEGIN ENUM_VARNAME; return E_NEW_ENUM; }
<ENUM_VARNAME>[^ =]+	{ options.str = strdup (yytext); BEGIN ENUM_VAL; return E_FIELD_NAME; }
<ENUM_VAL>["]	;
<ENUM_VAL>[ ]*=[ ]*	{ return E_DEFINE_ENUM; }
<ENUM_VAL>\|	;
<ENUM_VAL>[^"\|\n]+	{ options.str = strdup(yytext); return E_NEW_ENUM_VAL; }
<ENUM_VAL>\n	{ BEGIN 0; line_counter++; }
.		{ BEGIN HANDLE_ERROR; yymore(); }
<HANDLE_ERROR>\n	{ error("OhoNo! Unexpected token", yytext); }
<HANDLE_ERROR>[^\n]	{ yymore(); }
%%

#define APPEND_TO_LIST(father,list,son,pq) \
do { \
  if ((father)->list == NULL) { \
    (father)->list = son; \
  } else { \
    for ( pq = (father)->list; pq->next != NULL; pq = pq->next ) ;\
    pq->next = son; \
  } \
  pq = son; \
\
} while (0);

/* TODO: This function shall be used to check validity of structure member
 * name
 */
static char *_to_variable_name ( char *name )
{
  char *varname = NULL, *c;

  if ( name != NULL ) {
    varname = strndup ( name, 32 );
  }

  if ( varname != NULL ) {
    for ( c = varname; *c != '\0'; c++ ) {
      if ( isspace (*c) ) *c = '_';
    }
  }

  return varname;
}

static char *_to_uppername ( char *name )
{
  char *NAME = NULL, *c ;

  if ( name == NULL ) return NAME;

  NAME = strndup (name, 32);
  if ( NAME == NULL ) return NAME;
  /* TODO: take care of wide chars... if any in UTF-8 mode */
#define TOUPPER(c) ((c) >= 'a' && (c) <= 'z') ? ((c) - 'a' + 'A') :  \
                   ((c) >= 'A' && (c) <= 'Z' ) ? (c) : \
                   ((c) >= '0' && (c) <= '9') ? (c): '_'
  for ( c = NAME; *c != '\0'; c++ ) {
    *c = TOUPPER(*c);
  }

  return NAME;
}

char *to_enum_val ( char *cap )
{
  size_t len;
  char *enum_type;
 
  enum_type = (char*) calloc ( strlen(cap), sizeof(char));
  if ( enum_type != NULL ) {
    sprintf (enum_type, "E_%s", cap);
  }

  return enum_type;
}

struct vals *new_vals ( char *name )
{
  struct vals *p = (struct vals *) calloc(sizeof(struct vals), 1);

  p->name = name;
  p->enum_name = to_enum_val (name);
  return p;
}
static struct type_desc * new_type ( char *name, enum type_indicator type )
{
  struct type_desc *p = (struct type_desc *) calloc (1, sizeof (*p));

  if ( p != NULL ) {
    p->type_name = name;
    p->TYPE_NAME = _to_uppername (name);
    p->variable_name = _to_variable_name (name);
    p->has_been_defined = 0;
    p->type_ind = type;
  }

  return p;
}

static struct type_desc * find_or_add_type ( struct type_desc **list_head, enum type_indicator type, char *name )
{
  struct type_desc *prun, *last;

  if ( list_head == NULL ) return NULL;
  if ( *list_head == NULL ) {
    prun = new_type (name, type);
    *list_head = prun;
    return prun;
  }

  for ( prun = *list_head; prun != NULL; last = prun, prun = prun->next ) {
    if ( strcmp (prun->type_name, name) == 0 ) {
      /* Just a lil' control */
      if ( prun->type_ind != type ) {
        fprintf (stderr, "ERROR: same type name defined twice and different\n");
      }
      return prun;
    }
  }

  prun = new_type(name, type);
  last->next = prun;
  return prun;
}

static struct field * new_field ( struct type_desc ** list_of_type, char *typename, enum type_indicator type )
{
  struct field *p = (struct field *) calloc (1, sizeof(*p));

  p->type = find_or_add_type ( list_of_type, type, typename );
  if ( p->type == NULL ) {
    free (p);
    p = NULL;
  }

  return p;
}

static void append_field_to_type ( struct field *pf, struct type_desc *td )
{
  struct field *prun;

  if ( pf == NULL || td == NULL ) {
    return ;
  }

  prun = td->u_desc.struct_desc.list_of_fields; 
  if ( prun == NULL ) {
    td->u_desc.struct_desc.list_of_fields = pf;
  } else {
    for (; prun->next != NULL; prun = prun->next ) { };
    prun->next = pf;
  }
  td->has_been_defined = 1;
  return;
}

int main (int argc, char **argv)
{
  enum mac_states token;
  int ret = 0;
  struct field *head, *p, *at_level;
  struct vals *vals_runner = NULL, *pvalues = NULL;
  struct type_desc *list_of_types = NULL, *etype = NULL;
  char *headerfilename = "/tmp/aware_types.h";
  char *lexfilename = "/tmp/toto.l";
  char *makefilename = "/tmp/Makefile";
  char *lexoutfilename = "toto.c";
  char *lexoutheaderfilename = "toto.h";
  char *mainexfilename = "/tmp/main_ex.c";
  char *c;
  const char *cc = "AWARE_TYPES_H";
  char *config_functionname = "parse_config";
  FILE *header, *lex_file, *makefile, *mainexfile;

  yyin = stdin;

  /* Defining root of tree */
  head = new_field (&list_of_types, "root", E_STRUCT);
  if (head == NULL)
    return EXIT_FAILURE;
  head->father = head;
  head->level_index = -1;

  at_level = head;
  while (ret == 0 && (token = yylex())) {
    switch (token) {
      case E_GOTO_LEVEL:
        printf ("at %d, got to go to level %d from %d\n", line_counter, current_level, at_level->level_index);
        if (current_level <= at_level->level_index) {
          at_level = at_level->father;
          while (current_level <= at_level->level_index && at_level != head) {
            at_level = at_level->father;
          }
        } else if ( current_level > (at_level->level_index + 1 ) ) {
          printf ("Oho, error in level range (%d/%d) at line %d\n", current_level, at_level->level_index, line_counter);
          ret = 1;
        } else {
          printf ("Finally on level: %d\n", at_level->level_index);
        }
      break;
      case E_NEW_LEVEL:
        printf ("New level : %s (%d)\n", options.str, current_level);
        p = new_field(&list_of_types, options.str, E_STRUCT);
        if ( p == NULL ) {
          printf ("Error at line %d\n", line_counter);
          ret = 1;
        } else {
          p->level_index = current_level;
          p->father = at_level;
          at_level = p;
        }
      break;
      case E_NEW_ENUM:
        printf ("new enum: %s : ", options.str);
        p = new_field(&list_of_types, options.str, E_ENUM);
        if ( p == NULL ) {
          printf ("Error at line %d\n", line_counter);
          ret = 1;
        } else {
          p->level_index = current_level;
          p->father = at_level;
        }
        break;
      case E_NEW_ENUM_VAL:
        printf (" %s", options.str);
        pvalues = new_vals(options.str);
        APPEND_TO_LIST(&(p->type->u_desc.enum_desc), values, pvalues, vals_runner);
      break;
      case E_FIELD_NAME:
        printf ("%s", options.str);
        p->field_name = options.str;
        p->FIELD_NAME = _to_uppername(p->field_name);
        printf (" (to be append to struct: %s)\n", p->father->type->type_name);
        append_field_to_type ( p, p->father->type );
      break;
      case E_DEFINE_ENUM:
        /* Just to check if enum has not been already defined */
        if (p->type->has_been_defined == 1) {
          printf ("Error: defining enum %s twice at line %d\n", p->type->type_name, line_counter);
          ret = 1;
        }
      break;
      case E_TYPE_NAME:
        p = new_field(&list_of_types, type_names[options.type_name], E_BASIC_TYPE);
        if ( p == NULL ) {
          printf ("Error at line %d\n", line_counter);
          ret = 1;
        } else {
          p->level_index = current_level;
          p->father = at_level;
        }
      break;
      case E_TYPE_IS_A_LIST:
        p->is_a_list = 1;
        break;
      case E_BAD_SYNTAX:
        ret = -1;
        break;
      default:
      break;
    }
  }

  printf ("\nHere is what I have found:\n");
  header = fopen ( headerfilename, "w" );
  lex_file = fopen ( lexfilename, "w" );
  makefile = fopen ( makefilename, "w" );
  mainexfile = fopen ( mainexfilename, "w" );
  make_header ( header, cc, list_of_types, config_functionname );
  make_lex_file ( lex_file, list_of_types, headerfilename, config_functionname, lexoutfilename, lexoutheaderfilename );
  make_lex_makefile ( makefile, ((c = strrchr ( mainexfilename, '/' ) ) == NULL )? mainexfilename : c + 1, lexfilename, headerfilename, lexoutfilename, lexoutheaderfilename );
  make_lex_main_example ( mainexfile, config_functionname, lexoutheaderfilename, list_of_types );
  fclose ( header ); fclose ( lex_file ); fclose ( mainexfile ); fclose ( makefile );
  return 0;
}
