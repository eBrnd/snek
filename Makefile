TARGET=snek
.PHONE: all clean

all: $(TARGET).prg

run: $(TARGET).prg
	x64 $(TARGET).prg || true

$(TARGET).prg: $(TARGET).asm
	dasm $(TARGET).asm -o$(TARGET).prg

clean:
	rm -f $(TARGET).prg
