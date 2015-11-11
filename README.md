# Introduction

I recently bought a pair of Beats by Dr. Dre. I couldn't be more satisfied with the quality of my new headphones. Unfortunately, I often forget to power off my Beats when I set them down and come back later find its battery dead! Dismayed by the design oversight on the part of the engineers at Beats to power off the headphones after a period of inactivity, I decided to make my own circuit to do just that.

The circuit uses an Atmel ATTiny10 as its brain. The ATTiny10 is one of the smallest microcontrollers offered by Atmel. It has a whopping total of 3 general purpose input output pins! (You can actually get 4 if you disable the reset pin and use high-voltage programming when writing data into memory.) Its tiny size was perfect for this application, as the space within the headphones was incredibly limited.

The microcontroller has a total of 1 Kb of flash. That's 1024 bytes of bytes of program data. Not very much by today's standards. Speaking of memory, it has virtually no RAM. Only 32 bytes. Yikes.

Because of its severely limited resources, running C code on it is a challenge. If you want to write a program that does much of anything, writing assembly is a must. But let's face it: you simply can't go wrong with a microcontroller that's the size of the tip of a ball-point pen.

# Pinout

```

                +----+
AUDIO CHANNEL  =|•   |=	 NOT CONNECTED
         GND   =|    |=	 VCC
POWER BUTTON   =|    |=	 POWER LED
                +----+
                              
```

# Theory

Starting at a state in which both the microcontroller and the headphones are on, the microcontroller will listen for a voltage on the signal line using the ADC.

If there isn't a voltage, the microcontroller will start a timer - keeping track of how much time passes starting with the loss of signal.

If a signal arises again, the timer will be reset. If 16 minutes goes by and there still isn't a signal, then power the headphones off and put the microcontroller into sleep mode.

If there is an iterrupt on the power pin, check the state of the pin, and react accordingly. If the pin is high (the headphones are on), reset and power the microcontroller on. If they are off, sleep.

# Compiling

Use the makefile provided in this repository to compile the assembly file. You will need a copy of `avr-gcc` for the makefile to work properly. The standard `avr-gcc` package doesn’t support ATTiny models under the ATTiny11. Ignoring that and compiling the assembly using `-mmcu=attiny22` worked for me.

# Programming

To write the prebuilt firmware, `beats.hex` to the ATTiny, you will need an ATTiny programmer. You can purchase one online or build your own using an Arduino.

# Hardware

Here's a photo of how I tested the ATTiny before installing it into the headphones. The breakout board I used is called `SOT23-6 breakout board`.

![alt tag](https://raw.github.com/georgemorgan/beatzzz/branch/images/attiny.png)

Here, the headphones can bee seen with wires soldered to the audio channel, power button, and power LED.

![alt tag](https://raw.github.com/georgemorgan/beatzzz/branch/images/assembly.png)