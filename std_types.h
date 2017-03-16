#ifndef __TUPPERWARE_TYPES_H__
#define __TUPPERWARE_TYPES_H__

enum type_indicator {
  E_ENUM = 1,
  E_BASIC_TYPE,
  E_STRUCT,
};

enum known_type {
  UINT8_t = 1,
  INT8_t,
  UINT16_t,
  INT16_t,
  UINT32_t,
  INT32_t,
  UINT64_t,
  INT64_t,
  INT_t,
  UINT_t,
  FLOAT_t,
  DOUBLE_t,
  STRING_t,
};

struct vals {
  struct vals *next;
  char *name;
  char *enum_name;
};

struct enum_type {
  struct vals *values;
};

struct field;
struct struct_type {
  struct field *list_of_fields;
};

struct type_desc {
  struct type_desc *next;
  char *type_name;
  char *TYPE_NAME;
  char *variable_name;
  int type_ind;
  int has_been_defined;
  union {
    struct enum_type enum_desc;
    enum known_type type_desc;
    struct struct_type struct_desc;
  } u_desc;
};

struct field {
  struct field *father; /* Not to loose the wire while
                         * wandering among fields and subfields... */
  struct field *next;
  int level_index;

  /* Field spec' */
  struct type_desc *type;
  char *field_name;
  char *FIELD_NAME;

  /* Field behaviour flag in a struct (ie a list of field) */
  int is_a_list;
  int is_mandatory;
};

#endif /* __TUPPERWARE_TYPES_H__ */
