/*
 * main.c
 *
 *  Created on: Sep 12, 2014
 *      Author: brelei01
 */


__asm void my_strcpy(const char *src, char *dst)
{
loop
    LDRB    r2, [r0]        ; Load byte into r2 from mem. pointed to by r0 (src pointer)
    ADDS    r0, #1          ; Increment src pointer
    STRB    r2, [r1]        ; Store byte in r2 into memory pointed to by (dst pointer)
    ADDS    r1, #1          ; Increment dst pointer
    CMP     r2, #0          ; Was the byte 0?
    BNE     loop            ; If not, repeat the loop
    BX      lr              ; Else return from subroutine
}

__asm void my_capitalize(char *str)
{
cap_loop
    LDRB    r1, [r0]        ; Load byte into r1 from memory pointed to by r0 (str pointer)
    CMP	    r1, #'a'-1      ; compare it with the character before 'a'
    BLS	    cap_skip        ; If byte is lower or same, then skip this byte

    CMP	    r1, #'z'        ; Compare it with the 'z' character
    BHI	    cap_skip        ; If it is higher, then skip this byte

    SUBS    r1,#32          ; Else subtract out difference to capitalize it
    STRB    r1, [r0]        ; Store the capitalized byte back in memory
cap_skip
    ADDS    r0, r0, #1      ; Increment str pointer
    CMP     r1, #0          ; Was the byte 0?
    BNE     cap_loop        ; If not, repeat the loop
    BX      lr              ; Else return from subroutine
}

main()
{
	const char a[] = "Hello world!";
	char b[20];

	my_strcpy(a, b);
	my_capitalize(b);

	while (1)
		;
}
