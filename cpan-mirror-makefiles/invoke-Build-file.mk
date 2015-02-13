.PHONY: all test install

all:
	@./Build

test:
	@./Build test

install:
	@./Build install destdir=${DESTDIR}
