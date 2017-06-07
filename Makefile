FLEX = flex
YACC = bison

EXTRACT = ex

##FILEP=../src/cmds/cmds.h

FLEXDEBUG = '-d'
GENELEXC = stdcfgfile_parser.c
GENELEXH = stdcfgfile_parser.h
GENES = $(GENELEXC) $(GENELEXH)
all: puto test

puto: stdcfgfile_parser.o make_file.o std_types.h
	$(CC) $^ -o $@

.l.c:
	$(FLEX) $^

####### $(CC) $^ -o $@
test: puto
	./$< < conf.gg

clean:
	rm -f puto *.o
