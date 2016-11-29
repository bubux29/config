#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "tupperware_types.h"

#define WF fprintf
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

/************************/
/** EXPORTED PROTOYPES **/
/************************/

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
static int _append_or_not ( const char *fieldname, const char ***plist_of_fields, unsigned int size_of_list )
{
  const char **pnew;
  unsigned int fieldindex = 0;

  if ( plist_of_fields == NULL || fieldname == NULL ) return -1;

  if ( *plist_of_fields == NULL ) {
    *plist_of_fields = (const char **) calloc (1, sizeof(char*));
    if ( *plist_of_fields == NULL ) {
      printf ("running out of memory\n");
      return -2;
    }
    printf ("appending %s at %p\n", fieldname, *plist_of_fields);
    *plist_of_fields[0] = fieldname;
    return 0;
  }

  for ( fieldindex = 0; fieldindex < size_of_list; fieldindex++ ) {
    if ( strcmp ( fieldname, (*plist_of_fields)[fieldindex]) == 0 ) {
      printf ("Have found already defined fieldname: %s\n", fieldname);
      return 1;
    }
  }

  printf ("appending fieldname: %s at %p + %u\n", fieldname, *plist_of_fields, size_of_list );
  pnew = (const char **) realloc ( *plist_of_fields, ( ++size_of_list ) * sizeof(char*));
  if ( pnew == NULL ) {
    printf ("Out of mem\n");
    free ( plist_of_fields );
    return -2;
  }
  printf ("New allocated space at: %p\n", *plist_of_fields);
  *plist_of_fields = pnew;
  (*plist_of_fields)[size_of_list-1] = fieldname;
  printf ("First elem is: %s\n", (*plist_of_fields)[0]);

  return 0;
}

static void _do_lex_header ( FILE *file, struct type_desc *list_of_types, char *header_filename )
{
  struct type_desc *etype;
  struct field *efield;
  char *name_to_zeroise = NULL;
  unsigned int nb_uniq_fieldname = 0;
  const char **list_of_uniq_fieldname = NULL;

  if ( file == NULL || header_filename == NULL || list_of_types == NULL ) return;

  /* List any header */
  WF ( file, "%%{\n"
"#include <stdio.h>\n"
"#include \"%s\"\n"
"\n"
"int yywrap(void);\n"
"\n"
"static int line_counter = 1;\n"
"\n",
    (strrchr( header_filename, '/' )) + 1 );

  WF ( file, "union lex_opt {\n" );

  for ( etype = list_of_types->next; etype != NULL; etype = etype->next ) {
    if ( etype->type_ind == E_ENUM ) {
      WF ( file, "  enum %s e_%s;\n", etype->type_name, etype->type_name );
    } else if ( etype->type_ind == E_BASIC_TYPE ) {
      WF ( file, "  %s * p_%s;\n", etype->type_name, etype->variable_name );
    }
    name_to_zeroise = etype->type_name;
  }

  WF ( file, "};\n" );

  /* do a list of uniq field name, in order not to have multiple declaration of
   * same enum
   */
  WF ( file, "enum lex_return {\n" );
  for ( etype = list_of_types->next; etype != NULL; etype = etype->next ) {
    if ( etype->type_ind == E_STRUCT ) {
      for ( efield = etype->u_desc.struct_desc.list_of_fields;
            efield != NULL;
            efield = efield->next ) {
        if ( _append_or_not ( efield->field_name, &list_of_uniq_fieldname, nb_uniq_fieldname ) == 0 ) {
          WF ( file, "  E_%s = %u,\n", efield->FIELD_NAME, nb_uniq_fieldname );
          nb_uniq_fieldname++;
        }
      }
    }
  }
  WF ( file, "};\n" );

  /* Declare and zeroise the shared value */
  if ( name_to_zeroise != NULL )
    WF ( file, "\nunion lex_opt %s = { .%s = NULL };\n", name_to_zeroise, SHARED_VAL );

  WF ( file, 
"\n"
"}%%\n" );
}

static void _do_lex_state_defs ( FILE * file, struct type_desc *list_of_types, char *lexoutfilename, char *lexoutheaderfilename )
{
  struct type_desc *etype;
  struct field *field;

  if ( list_of_types == NULL || list_of_types->next == NULL ) return;

  WF ( file, "\n" "%%x SYNTAX_FILE_ERROR " );
  /* dont care of ROOT ! */
  for ( etype = list_of_types->next; etype != NULL; etype = etype->next ) {
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

  WF ( file, "%%options outfile=\"%s\" header-file=\"%s\"\n\n", lexoutfilename, lexoutheaderfilename );
}

static void _do_lex_easy_symbol ( FILE *file )
{
  WF ( file, "S\t[[:space:]]\n" );
  WF ( file, "NN\t[^\\n]\n" );

  WF ( file, "\n" );
}

void _do_lex_machine_state ( FILE *file, struct type_desc *types )
{
  struct type_desc *etype;
  struct field *field;

  if ( file == NULL || types == NULL ) return;

  WF ( file,
"%%%%\n"
"\\n\t\t{ line_counter++; }\n"
"\\t\t\t;\n"
  );

  for ( etype = types->next; etype != NULL; etype = etype->next ) {
    if ( etype->type_ind == E_STRUCT ) {
      for ( field = etype->u_desc.struct_desc.list_of_fields;
            field != NULL;
            field = field->next ) {
        WF ( file, "<%s>%s{S}*={S}*{NN}\t\t{ BEGIN %s; return E_%s; }\n", etype->TYPE_NAME, field->field_name, field->type->TYPE_NAME, field->FIELD_NAME );
      }
    }
  }

  WF ( file, "%%%%\n");
}

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
  if ( file == NULL || types == NULL || header_filename == NULL ) return -1;

  _do_lex_header ( file, types, header_filename );
  _do_lex_state_defs ( file, types, lexoutfilename, lexoutheaderfilename );
  _do_lex_options ( file, lexoutfilename, lexoutheaderfilename );
  _do_lex_easy_symbol ( file );
  _do_lex_machine_state ( file, types );
}
