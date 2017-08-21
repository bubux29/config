FLEX = flex
YACC = bison

TEMPLATE_FILE = example.template

EXTRACT = ex

##FILEP=../src/cmds/cmds.h

FLEXDEBUG = '-d'
GENELEXC = stdcfgfile_parser.c
GENELEXH = stdcfgfile_parser.h
GENES = $(GENELEXC) $(GENELEXH)
all: copagen test

copagen: stdcfgfile_parser.o make_file.o std_types.h
	$(CC) $^ -o $@

.l.c:
	$(FLEX) $^

####### $(CC) $^ -o $@
test: copagen
	./$< -d ./ -o lvalid_cfg < $(TEMPLATE_FILE)

clean:
	rm -f copagen *.o
