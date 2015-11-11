all:

	avr-gcc -std=gnu99 -nostartfiles -nostdlib -mmcu=attiny22 beats.s -o beats.elf

	avr-objcopy -O ihex beats.elf beats.hex

clean:

	rm -rf *.o *.elf *.hex all