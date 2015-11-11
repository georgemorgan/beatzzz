; # - Application Pinout - #

;                  +----+
; AUDIO CHANNEL   =|•   |=	 NOT CONNECTED
;           GND   =|    |=	 VCC
;  POWER BUTTON   =|    |=	 POWER LED
;                  +----+

; # - Theory of operation. - #

; Starting at a state in which both the microcontroller and the headphones are on, the microcontroller will listen for a voltage on the signal line using the ADC.

; If there isn't a voltage, the microcontroller will start a timer - keeping track of how much time passes starting with the loss of signal.

; If a signal arises again, the timer will be reset. If 16 minutes goes by and there still isn't a signal, then power the headphones off and put the microcontroller into sleep mode.

; If there is an iterrupt on the power pin, check the state of the pin, and react accordingly. If the pin is high (the headphones are on), reset and power the microcontroller on. If they are off, sleep.

.equ PINB, 0x00

.equ DDRB, 0x01

.equ PORTB, 0x02

.equ PB0, 0

.equ PB1, 1

.equ PB2, 2

.equ PCMSK, 0x10

.equ PCINT0, 0

.equ PCINT1, 1

.equ PCINT2, 2

.equ PCINT3, 3

.equ PCICR, 0x12

.equ PCIE0, 0

.equ EIMSK, 0x13

.equ INT0, 0

.equ EICRA, 0x15

.equ ISC00, 0

.equ ISC01, 1

.equ ADCL, 0x19

.equ ADMUX, 0x1B

.equ MUX0, 0

.equ MUX1, 1

.equ ADCSRB, 0x1C

.equ ADTS0, 0

.equ ADTS1, 1

.equ ADTS2, 2

.equ ADCSRA, 0x1D

.equ ADPS0, 0

.equ ADPS1, 1

.equ ADIE, 3

.equ ADATE, 5

.equ ADSC, 6

.equ ADEN, 7

.equ OCR0AL, 0x26

.equ OCR0AH, 0x27

.equ TCNT0L, 0x28

.equ TCNT0H, 0x29

.equ TCCR0B, 0x2D

.equ CS00, 0

.equ CS01, 1

.equ CS02, 2

.equ WGM02, 3

.equ TIMSK0, 0x2B

.equ OCIE0A, 1

.equ WDTCSR, 0x31

.equ WDE, 3

.equ PRR, 0x35

.equ PRADC, 1

.equ CLKPSR, 0x36

.equ CLKPS3, 3

.equ SMCR, 0x3A

.equ SE, 0

.equ SM1, 2

.equ RSTFLR, 0x3B

.equ WDRF, 3

.equ CCP, 0x3C

.equ SPL, 0x3D

.equ SPH, 0x3E

.org 0x00

; # - Interrupt Vectors - #

                        ; Jump to the initialization code.

reset:					rjmp init

interrupt_0:			rjmp interrupt_0

pin_change_0:			rjmp check_power

timer_capture:          rjmp timer_capture

timer_overflow:         rjmp timer_overflow

                        ; This ISR is forwarded to the ADC ISR. Each time a timer interrupt arises, the ADC will be triggered to start a conversion.

timer_compare_a:		reti

timer_compare_b:		rjmp timer_compare_b

analog_compare:         rjmp analog_compare

watchdog:				rjmp watchdog

voltage_change:         rjmp voltage_change

                        ; Jump to the signal comparison routine to process the ADC conversion result.

adc_complete:			rjmp check_signal

; # - Initialize the hardware. - #

init:                   ; ~ Disable global interrupts. ~

                        cli

                        ; ~ Reset the watchdog timer. ~

                        wdr

                        ; ~ Clear WDRF. ~a

                        in r16, RSTFLR

                        andi r16, ~(1 << WDRF)

                        out RSTFLR, r16

                        ; ~ Unlock the WDTCSR register by writing the appropriate unlock signature (0xD8) to the CCP. ~

                        ldi r16, 0xD8

                        out CCP, r16

                        ; ~ Disable the watchdog timer. ~

                        clr r16

                        out WDTCSR, r16

                        ; ~ Configure the stack. The ATTiny10 has 32 bytes of RAM, which ends at address 0x5F. ~

                        clr r16

                        out SPH, r16

                        ldi r16, 0x5F

                        out SPL, r16

                        ; ~ Unlock the CLKPSR register by writing the appropriate unlock signature (0xD8) to the CCP. ~

                        ldi r16, 0xD8

                        out CCP, r16

                        ; ~ Prescale the internal clock to 1/256 its original speed in order to reduce power consumption. ~

                        ldi r16, (1 << CLKPS3)

                        out CLKPSR, r16

                        ; ~ Clear counter register on compare match. Configure the timer with a 1/1024 prescaler. Start the timer. ~

                        ldi r16, ((1 << WGM02) | (1 << CS02) | (1 << CS00))

                        out TCCR0B, r16

                        ; ~ OCRA0A is set to a decimal value of 235 so that an interrupt is fired after roughly 8 seconds of real time. ~

                        clr r16

                        out OCR0AH, r16

                        ldi r16, 235

                        out OCR0AL, r16

                        ; ~ Enable the timer compare match interrupt. ~

                        ldi r16, (1 << OCIE0A)

                        out TIMSK0, r16

                        ; ~ Zero r25, which will be used as the counter register. ~

                        clr r25

                        ; ~ Set the power pin (PB1) as an output and leave the power indicator pin (PB2) and signal pin (PB0) as an input.

                        ldi r16, (1 << PB1)

                        out DDRB, r16

                        ; ~ Enable the internal pull-up resistor on PB2. ~

                        ldi r16, (1 << PB2)

                        out PORTB, r16

                        ; ~ Enable PCINT1. This is PB1, which is connected to the power button. Even though it is configured as an output, the pin change interrupt should still fire. ~

                        ldi r16, (1 << PCINT1)

                        out PCMSK, r16

                        ; ~ Enable the pin change interrupt. ~

                        in r16, PCICR

                        ori r16, (1<< PCIE0)

                        out PCICR, r16

                        ; ~ Enable the ADC. Start a conversion. Set the ADC auto trigger bit as well as the ADC compare complete interrupt bit. Prescale to 1/8 internal clock. ~

                        ldi r16, ((1 << ADEN) | (1 << ADSC) | (1 << ADATE) | (1 << ADIE) | (1 << ADPS1) | (1 << ADPS0))

                        out ADCSRA, r16

                        ; ~ Configure the ADC to perform a conversion each time the timer compare match interrupt is serviced. ~

                        ldi r16, ((1 << ADTS1) | (1 << ADTS0))

                        out ADCSRB, r16

                        ; ~ Select PB0 as the ADC input channel by setting both MUX0 and MUX1 to 0. ~

                        clr r16

                        out ADMUX, r16

                        ; ~ Enable global interrupts. ~

                        sei

                        ; ~ Enter idle mode to save power. The CPU clock will be haulted, leaving the other clocks active. ~

._sleep:                clr r16

                        out SMCR, r16

                        sleep

                        rjmp ._sleep

                        ; ~ Enter an infinite loop should the program ever reach this point. ~

                        rjmp loop


; # - Handle an PCINT0 interrupt and wake the MCU if the headphones are on. - #


check_power:            ; ~ If the microcontroller is in sleep mode, disable sleep mode. ~

                        in r16, SMCR

                        andi r16, ~(1 << SE)

                        out SMCR, r16

                        ; ~ Wait roughly 1.5 seconds for the headphones to completely turn on or turn off. ~

                        ldi r16, 60

                        rcall delay

                        ; ~ Read the value of PB2. ~

                        in r16, PINB

                        bst r16, PB2

                        ; ~ If PB2 is low, the headphones are on. Turn the microcontroller on.

                        brtc .__beats_on

                        ; ~ If PB2 is high, the headphones are off. Turn the microcontroller off. ~

.__beats_off:           ; Enable interrupts again so that other interrupts can be serviced while in sleep mode.

                        sei

                        ; ~ Power off the device. ~

                        rcall power_off

.__beats_on:            rcall reset_and_reboot

.__abort:               reti


; # - Check signal function. - #


check_signal:           ; Increment the counter register.

                        inc r25

                        ; Get the conversion value.

                        in r16, ADCL

                        ; See if the conversion value is below the threshold. (No signal.)

                        cpi r16, 0 ; The ADC has a depth of 8-bits. ?? The maxmium value of a conversion is 255, which is equivalent to 0v. 5v is a value of 0. This value was chosen based on experimentation. Pull up?

                        brne ._check_signal_failure ; Fail if the comparison is the lower than the threshold.


._check_signal_success: ; The comparison was a success. We have no signal.

                        rcall check_time

                        reti


._check_signal_failure: ; The comparison failed. There is more than XXv on the line.

                        ; Zero the no signal register and counter register.

                        clr r25

                        reti


; # - Handle counting. - #


check_time:             ; See if the counter is above the threshold. (16 minutes have passed.)

                        cpi r25, 3 ; timer ticks in 16 minutes = (16 minutes * 60 seconds) / 8 seconds per tick = 120 ticks in 16 minutes

                        brlo .__check_failure ; The comparison was lower than the threshold. 16 minutes have not passed.


.__check_success:       ; The check was a success. 16 minutes have passed and it's time to power the device off.

                        ; ~ Clear interrupts so that another conversion isn't performed. ~

                        cli

                        ; Turn off the ADC so that another comparsion won't be triggered, and also so that the MCU will save more power when put into sleep mode.

                        in r16, PRR

                        ori r16, (1 << PRADC)

                        out PRR, r16

                        ; ~ Disable the pin change interrupt. ~

                        in r16, PCICR

                        andi r16, ~(1<< PCIE0)

                        out PCICR, r16

                        ; Toggle the power pin high.

                        in r16, PORTB

                        ori r16, (1 << PB1)

                        out PORTB, r16

                        ; Set r16 to the desired delay value. 136 ticks is roughly 3.5 seconds and just enough delay time to power off the headphones.

                        ldi r16, 136

                        rcall delay

                        ; Three seconds have passed. Toggle the power pin low.

                        in r16, PORTB

                        andi r16, ~(1 << PB1)

                        out PORTB, r16

                        ; ~ Enable the pin change interrupt. ~

                        in r16, PCICR

                        ori r16, (1<< PCIE0)

                        out PCICR, r16

                        ; Enable interrupts.

                        sei

                        ; Power off the microcontroller.

                        rcall power_off

.__check_failure:       ; The check was a failure. 16 minutes have not passed yet.

                        ret


power_off:              ; ~ Enter sleep mode. This is a deep power down. The only interrupt that can wake the device is a pin change. ~

                        ldi r16, ((1 << SM1) | (1 << SE))

                        out SMCR, r16

                        sleep


reset_and_reboot:       ; ~ Disable interrupts. ~

                        cli

                        ; Enable the watchdog timer.

                        ldi r16, (1 << WDE)

                        out WDTCSR, r16

                        ; Loop forever and cause a hardware reset.

                        rjmp loop

; # - Delay Loop - # ~ 1 iteration of this loop is roughly 26 milleseconds. 39 iterations is roughly 1 second. ~

delay:                  ; We have prescaled the internal clock to 1/256 its original speed. (8/256 MHz) This means that exactly 31250 clock cycles will be executed in 1 second.

                        ; Set all of the bits in r17.

                        ser r17

                        ; Subtract 1 from r17

.__delay_loop:          dec r17             ; 1 cycle

                        ; If r17 isn't equal to zero, then do it again.

                        brne .__delay_loop  ; 1 cycle if false. 2 cycles if true.

                        ; If r17 is equal to 0, subtract 1 from r16.

                        dec r16             ; 1 cycle

                        ; If r16 isn't equal to zero, then do it all again.

                        brne .__delay_loop  ; 1 cycle. 2 cycles if true.

                        ; If r16 is equal to zero, then return.

                        ret

; # - Enter an infinite loop. - #


loop:					rjmp loop

