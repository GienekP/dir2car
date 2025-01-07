# Dir2Car Makefile

all: clean \
	compile \

clean:
	rm -f dir2car.o
	rm -f dir2car

compile:
	gcc -Wall -pedantic dir2car.c -o dir2car
	rm -f dir2car.o

	
