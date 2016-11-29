FLEX = flex
YACC = bison

EXTRACT = ex

##FILEP=../src/cmds/cmds.h

FLEXDEBUG = '-d'
GENELEXC = tupperwar.c
GENELEXH = tupperwar.h
GENES = $(GENELEXC) $(GENELEXH)
all: puto test

puto: tupperwar.o make_file.o tupperware_types.h
	$(CC) $^ -o $@

.l.c:
	$(FLEX) $^

####### $(CC) $^ -o $@
test: puto
	./$< < conf.gg

clean:
	rm -f puto
