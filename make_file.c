#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "tupperware_types.h"

#define WF fprintf
#define FIELD_GLOB "field_name"
#define SHARED_VAL "shared_val"

static void _show_type ( struct type_desc *type, FILE *file )
{
  if ( type == NULL ) return;
  switch (type->type_ind) {
    case E_BASIC_TYPE:
      WF ( file, "%s ", type->type_name);
    break;
    case E_ENUM:
      WF ( file, "enum %s ", type->type_name);
    break;
    case E_STRUCT:
      WF ( file, "struct %s *", type->type_name);
    break;
  }
}

/*
 * Show one field inside a structure and define it as a pointer.
 */
static void _show_field ( struct field *field, FILE *file )
{
  if ( field == NULL ) return;
  WF (file, "\t");
  _show_type ( field->type, file );
  if ( field->is_a_list == 1 ) WF ( file, "*");
  WF ( file, " %s", field->field_name);
  WF ( file, ";\n");
}

/**************************************/
/** For header type file declaration **/
/**************************************/

void declare_complex_type ( struct type_desc *type, FILE *file )
{
  if (type != NULL) {
    switch (type->type_ind) {
      case E_ENUM:
        WF ( file, "enum %s;\n", type->type_name);
      break;
      case E_STRUCT:
        WF ( file, "struct %s;\n", type->type_name);
      break;
    }
  }
}

void show_enum ( struct type_desc *type, FILE *file )
{
  struct vals *pv;

  if ( type != NULL )
  switch (type->type_ind) {
    case E_ENUM:
      WF ( file, "enum %s {\n", type->type_name);
      pv  = type->u_desc.enum_desc.values;
      WF ( file, "\tE_IMPOSSIBLE_%s = -1,\n", type->TYPE_NAME );
      if ( pv != NULL ) {
        WF ( file, "\t%s = 1,\n", pv->enum_name);
      }
      for (pv = pv->next; pv != NULL; pv = pv->next) {
        WF ( file, "\t%s,\n", pv->enum_name);
      }
      WF ( file, "};\n\n");
    break;
  }
}

void show_struct ( struct type_desc *type, FILE *file )
{
  struct field *field;

  switch (type->type_ind) {
    case E_STRUCT:
      WF ( file, "struct %s {\n", type->type_name);
      for ( field = type->u_desc.struct_desc.list_of_fields; field != NULL;
            field = field->next ) {
        _show_field (field, file);
      }
      WF ( file, "};\n\n");
    break;
    default:
    break;
  }

}
void show_function ( struct type_desc *types, FILE *file, char *func )
{
  if (types == NULL || file == NULL || func == NULL) return;

  WF (file, "int %s ( FILE *streamin, struct %s **pconfig_out );\n",
           func, types->type_name );
}

void print_head ( const char *cfl, FILE *file )
{
  WF ( file,
"/**\n"
" * Beware, this is a generated prototype file, dont try to modify it by hand\n"
" * or else you'll lose the changes on next generation.\n"
" */\n" );
  WF (file, "#ifndef __%s__\n#define __%s__\n\n", cfl, cfl);
}

void print_bottom ( const char *cfl, FILE *file )
{
  WF (file, "\n#endif /* __%s__ */\n", cfl);
}

/******************************/
/** For lex file declaration **/
/******************************/
static int _append_or_not ( struct field *field, struct field ***plist_of_fields, unsigned int *size_of_list )
{
  struct field **pnew;
  unsigned int fieldindex = 0;

  if ( plist_of_fields == NULL || field == NULL || size_of_list == NULL )
    return -1;

  if ( *plist_of_fields == NULL ) {
    *plist_of_fields = (struct field **) calloc (1, sizeof(struct field*));
    if ( *plist_of_fields == NULL ) {
      printf ("running out of memory\n");
      return -2;
    }
    printf ("appending %s at %p\n", field->field_name, *plist_of_fields);
    *plist_of_fields[0] = field;
    *size_of_list += 1;
    return 0;
  }

  for ( fieldindex = 0; fieldindex < *size_of_list; fieldindex++ ) {
    if ( strcmp ( field->field_name, (*plist_of_fields)[fieldindex]->field_name) == 0 ) {
      if ( field->type == (*plist_of_fields)[fieldindex]->type ) {
        printf ("Have found already defined fieldname: %s\n", field->field_name);
        return 0;
      } else {
        printf ("Field with name <%s> already defined but with different type: %s/%s\n", field->field_name, field->type->type_name, (*plist_of_fields)[fieldindex]->type->type_name);
        return 1;
      }
    }
  }

  *size_of_list += 1;
  pnew = (struct field **) realloc ( *plist_of_fields, *size_of_list * sizeof(struct field*));
  if ( pnew == NULL ) {
    printf ("Out of mem\n");
    free ( plist_of_fields );
    return -2;
  }
  /*printf ("New allocated space at: %p (%d)\n", *plist_of_fields, *size_of_list);*/
  *plist_of_fields = pnew;
  (*plist_of_fields)[*size_of_list-1] = field;

  return 0;
}

static int _make_uniq_field_list ( struct type_desc *list_of_types,
                                   struct field ***list_of_uniq_fields,
                                   unsigned int *pnb_uniq_fields )
{
  struct type_desc *etype;
  struct field *efield;

  if ( list_of_types == NULL || list_of_uniq_fields == NULL || pnb_uniq_fields == NULL )
    return 1;

  for ( etype = list_of_types; etype != NULL; etype = etype->next ) {
    if ( etype->type_ind == E_STRUCT ) {
      for ( efield = etype->u_desc.struct_desc.list_of_fields;
            efield != NULL;
            efield = efield->next ) {
        if ( _append_or_not ( efield, list_of_uniq_fields, pnb_uniq_fields ) > 0 ) {
          error ("ERR: You've specified at least twice the same field name (%s), but they have been declared with two different types\n    which is not fine to parse!\n     Please use another name for one of these fields\n");
          return 1;
        }
      }
    }
  }

  return 0;
}

static void _do_lex_header ( FILE *file, struct field **list_of_uniq_fields, unsigned int nb_uniq_fields, struct type_desc *list_of_types, char *header_filename )
{
  struct type_desc *etype;
  struct field *efield;
  char *name_to_zeroise = NULL;
  unsigned int u_field;

  if ( file == NULL || header_filename == NULL || list_of_types == NULL ) return;

  /* List any header */
  WF ( file, "%%{\n"
"#include <stdio.h>\n"
"#include \"%s\"\n"
"\n"
"int yywrap(void);\n"
"\n"
"static int line_counter = 1;\n"
"static int level_counter = 0;\n"
"\n",
    (strrchr( header_filename, '/' )) + 1 );

  WF ( file, "union lex_opt {\n" );

  WF ( file, "  char * str;\n" );
  for ( etype = list_of_types->next; etype != NULL; etype = etype->next ) {
    if ( etype->type_ind == E_ENUM ) {
      WF ( file, "  enum %s e_%s;\n", etype->type_name, etype->type_name );
    } else if ( etype->type_ind == E_BASIC_TYPE ) {
      WF ( file, "  %s e_%s;\n", etype->type_name, etype->TYPE_NAME );
    }
    name_to_zeroise = etype->type_name;
  }

  WF ( file, "};\n" );

  /* do a list of uniq field name, in order not to have multiple declaration of
   * same enum
   */
  WF ( file, "enum lex_return {\n" );
  for ( u_field = 0; u_field < nb_uniq_fields; u_field++ ) {
    WF ( file, "  E_%s,\n", list_of_uniq_fields[u_field]->FIELD_NAME );
  }
  WF ( file, "};\n" );

  /* Declare and zeroise the shared value */
  if ( name_to_zeroise != NULL )
    WF ( file, "\nunion lex_opt %s = { .%s = NULL };\n", SHARED_VAL, name_to_zeroise );

  WF ( file, "enum lex_return %s = -1;\n\n", FIELD_GLOB );

  WF ( file, 
"\n"
"%%}\n" );
}

static void _do_lex_state_defs ( FILE * file, struct type_desc *list_of_types, char *lexoutfilename, char *lexoutheaderfilename )
{
  struct type_desc *etype;
  struct field *field;

  if ( list_of_types == NULL || list_of_types->next == NULL ) return;

  WF ( file, "\n" "%%x SYNTAX_FILE_ERROR CLOSE_LINE " );
  /* dont care of ROOT ! */
  for ( etype = list_of_types->next; etype != NULL; etype = etype->next ) {
    if ( etype->type_ind != E_STRUCT )
      WF ( file, "%s ", etype->TYPE_NAME );
#if 0
    if ( etype->type_ind == E_STRUCT ) {
      WF ( file, "%s ", etype->TYPE_NAME );
      for ( field = etype->u_desc.struct_desc.list_of_fields;
            field != NULL;
            field = field->next ) {
        if ( field->type->type_ind == E_BASIC_TYPE ) {
          WF ( file, "%s_%s ", etype->TYPE_NAME, field->FIELD_NAME );
        }
      }
    }
#endif
  }

  WF ( file, "\n\n" );
}

static void _do_lex_options ( FILE *file, char *lexoutfilename, char *lexoutheaderfilename )
{

  if ( file == NULL || lexoutfilename == NULL || lexoutheaderfilename == NULL )
    return;

  WF ( file, "%%option outfile=\"%s\" header-file=\"%s\"\n\n", lexoutfilename, lexoutheaderfilename );
}

static void _do_lex_easy_symbol ( FILE *file )
{
  WF ( file, "S\t[[:space:]]\n" );
  WF ( file, "NN\t[^\\n]\n" );

  WF ( file, "\n" );
}

static void _do_lex_extra_rules ( FILE *file )
{
  if ( file != NULL )
    WF ( file,
"<CLOSE_LINE>[^[:space:]]\t{ BEGIN SYNTAX_FILE_ERROR; }\n"
"<CLOSE_LINE>[^\\n]\t;/* nothing to do */\n"
"<CLOSE_LINE>\\n\t{ line_counter++; return %s; }\n"
".\t\t{ BEGIN SYNTAX_FILE_ERROR; yymore(); }\n"
"<SYNTAX_FILE_ERROR>\\n\t{ error(\"OhoNo! Unexpected token at line %%d: %%s\", line_counter, yytext); }\n"
"<SYNTAX_FILE_ERROR>[^\\n]\t{ yymore(); }\n",
FIELD_GLOB
    );
}

static void _do_lex_begin_rules ( FILE *file )
{
  if ( file == NULL ) return;
  WF ( file,
"%%%%\n"
"\\n\t\t{ line_counter++; }\n"
"^\\t\t\t;\n"
  );

}

static void _do_lex_machine_state ( FILE *file, struct type_desc * list_of_types, struct field **list_of_uniq_fields, unsigned int nb_fields )
{
  struct type_desc *etype;
  struct field *field;
  struct vals *val;
  unsigned int u_field;

  if ( file == NULL || list_of_types == NULL ) return;

  _do_lex_begin_rules ( file );

  /* Let's have a special case with the root structure, since we should be out
   * of any level...
   */
  for ( u_field = 0; u_field < nb_fields; u_field++ ) {
    field = list_of_uniq_fields[u_field];
    if ( field->type->type_ind == E_STRUCT ) {
      /* If field is a substruct, we have to indicate to machine state
       * handler that a new function able to parse that struct shall be
       * called
       */
      WF ( file, "\\[%s\\]\t\t{ BEGIN CLOSE_LINE; %s = E_%s; }\n", field->field_name, FIELD_GLOB, field->FIELD_NAME );
      WF ( file, "\\[\\/%s\\]\t\t{ BEGIN CLOSE_LINE; %s = E_END_DEF_STRUCT; }\n", field->field_name, FIELD_GLOB );
    } else if ( field->type->type_ind == E_BASIC_TYPE && field->type->u_desc.type_desc == STRING_t ) {
      /* If field is of type "string_t", we have to remove the '"' sign
       * from the start and the end of the string
       */
      WF ( file, "%s{S}*={S}*\"\t\t{ %s.str = strdup(yytext); return E_%s; }\n", field->field_name, SHARED_VAL, field->FIELD_NAME );
    } else {
      /* If field is of type "simple", meaning int, float..., well we
       * shall parse directly what happens next to the '=' sign
       */
      WF ( file, "%s{S}*={S}*\t\t{ BEGIN %s; %s = E_%s; }\n", field->field_name, field->type->TYPE_NAME, FIELD_GLOB, field->FIELD_NAME );
    }
  }

  for ( etype = list_of_types; etype != NULL; etype = etype->next ) {
    WF ( file, "\t/* Parsing %s %s vals */\n", (etype->type_ind == E_STRUCT) ? "struct" : (etype->type_ind == E_ENUM ) ? "enum" : "basic type", etype->type_name );
    if ( etype->type_ind == E_BASIC_TYPE && etype->u_desc.type_desc != STRING_t ) {
      WF ( file, "<%s>[^[:space:]\\n]+\t\t{ BEGIN CLOSE_LINE; %s.str = strdup (yytext); return %s; }\n", etype->TYPE_NAME, SHARED_VAL, FIELD_GLOB);
    } else if ( etype->type_ind == E_BASIC_TYPE ) { /* it remains string_t */
      WF ( file, "<%s>.*[^\\]\"\t\t{ BEGIN CLOSE_LINE; %s.str = strdup (yytext); return E_%s; }\n", etype->TYPE_NAME, SHARED_VAL, etype->TYPE_NAME );
    } else if ( etype->type_ind == E_ENUM ) {
      for ( val = etype->u_desc.enum_desc.values; val != NULL; val = val->next ) {
        WF ( file, "<%s>\"%s\"\t\t{ BEGIN CLOSE_LINE; %s.e_%s = %s; return %s; }\n", etype->TYPE_NAME, val->name, SHARED_VAL, etype->type_name, val->enum_name, FIELD_GLOB );
      }
      WF ( file, "<%s>.\t\t{ BEGIN SYNTAX_FILE_ERROR; }\n", etype->TYPE_NAME );
    }
  }

  _do_lex_extra_rules ( file );
  WF ( file, "%%%%\n");
}

static void _do_lex_string_to_basic ( FILE *file, struct type_desc *list_of_types )
{
  struct type_desc *etype;

  for ( etype = list_of_types; etype != NULL; etype = etype->next ) {
    if ( etype->type_ind == E_BASIC_TYPE ) {

    }
  }
}

static void _do_lex_parse_funcs ( FILE *file, struct type_desc *list_of_types )
{
  struct type_desc *etype;
  struct field *field;

  if ( file == NULL || list_of_types == NULL ) return;

  for ( etype = list_of_types; etype != NULL; etype = etype->next ) {
    if ( etype->type_ind == E_STRUCT ) {
      WF ( file, "static struct %s * _parse_%s ( FILE *in )\n{\n", etype->type_name, etype->TYPE_NAME );
      WF ( file, "  int ret;\n  enum lex_return token;\n");
      WF ( file, "  struct %s *p = calloc (1, sizeof(*p));\n\n", etype->type_name);
      WF ( file, "  /** TODO: do an init of the structure according to what is inside */\n");
      WF ( file, "  if ( ! p ) return NULL;\n\n");
      WF ( file, "  while (ret == 0 && (token = yylex())) {\n" );
      WF ( file, "    switch ( token ) {\n" );
      for  ( field = etype->u_desc.struct_desc.list_of_fields; field != NULL; field = field->next ) {
        WF ( file, "      case E_%s:\n", field->FIELD_NAME );
        if ( field->type->type_ind == E_ENUM ) {
          WF ( file, "         p->%s = %s.e_%s;\n", field->field_name, SHARED_VAL, field->type->type_name );
        } else if ( field->type->type_ind == E_STRUCT ) {
          WF ( file, "         p->%s = _parse_%s();\n", field->field_name, field->type->TYPE_NAME );
          WF ( file, "         if ( p->%s == NULL ) {\n", field->field_name );
          WF ( file, "           ret = 1; /* The error has been told by function */\n" );
          WF ( file, "         }\n" );
        }
        WF ( file, "      break;\n" );
      }
      WF ( file, "      default:\n");
      WF ( file, "        ret = 1;\n" );
      WF ( file, "        error ( \"ERROR: unexpected token at line %%d: %%s\\n\", line_counter, yytext() );\n");
      WF ( file, "  }\n\n" );
      WF ( file ,"  /** TODO: integrity check if any value is missing */\n" );
      WF ( file, "  return ret;\n");
      WF ( file, "}\n\n" );
    }
  }
}

/************************/
/** EXPORTED PROTOYPES **/
/************************/

int make_header ( FILE *header, char *cc, struct type_desc *list_of_types, char *config_functionname )
{
  struct type_desc *etype;

  if ( header == NULL || cc == NULL || list_of_types == NULL || config_functionname == NULL ) return -1;

  print_head ( cc, header );
  fprintf (header, "\n#include <inttypes.h>\n");
  fprintf (header, "#include <stdio.h>\n\n");
  fprintf (header, "/*\n  First of all, declare any complex type that may be used further.\n  This lazy C technique avoids sorting the declarations\n*/\n");
  for ( etype = list_of_types; etype != NULL; etype = etype->next ) {
    declare_complex_type(etype, header);
  }
  fprintf (header, "\n\n"
"/**********************/\n"
"/** TYPE DEFINITIONS **/\n"
"/**********************/\n");
  for ( etype = list_of_types; etype != NULL; etype = etype->next ) {
    show_enum(etype, header);
  }
  for ( etype = list_of_types; etype != NULL; etype = etype->next ) {
    show_struct(etype, header);
  }
  fprintf (header, "\n\n"
"/************************/\n"
"/** FUNCTION PROTOTYPE **/\n"
"/************************/\n");
  show_function (list_of_types, header, config_functionname);
  print_bottom(cc, header);

  return 0;
}

int make_lex_file ( FILE *file, struct type_desc *types, char *header_filename, char *config_functionname, char *lexoutfilename, char *lexoutheaderfilename )
{
  struct field **list_of_fields;
  unsigned int nb_fields = 0;
  int ret;

  if ( file == NULL || types == NULL || header_filename == NULL ) return -1;

  ret = _make_uniq_field_list ( types, &list_of_fields, &nb_fields );
  _do_lex_header ( file, list_of_fields, nb_fields, types, header_filename );
  _do_lex_state_defs ( file, types, lexoutfilename, lexoutheaderfilename );
  _do_lex_options ( file, lexoutfilename, lexoutheaderfilename );
  _do_lex_easy_symbol ( file );
  _do_lex_machine_state ( file, types, list_of_fields, nb_fields );
  _do_lex_string_to_basic ( file, types );
  _do_lex_parse_funcs ( file, types );
}
