
MCU = atmega16
F_OSC=8000000

AVRDUDE_PORT = /dev/ttyACM0

BUILD_SYSTEM = ./bs.sh

#SRC = $(wildcard *.c)
SRC = src/tlcd.c \
      test/main.c \
      test/uart.c

HEADER = src/tlcd.h.in

INCLUDES = -I"./src" -I"./test"
TARGET = main

# List Assembler source files here.
ASRC = 
