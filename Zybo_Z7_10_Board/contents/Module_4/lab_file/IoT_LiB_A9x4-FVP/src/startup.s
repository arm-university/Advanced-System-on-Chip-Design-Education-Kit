; ------------------------------------------------------------
; Copyright (c) 2011-2014 ARM Ltd.  All rights reserved.
; ------------------------------------------------------------

    PRESERVE8

  AREA  StartUp,CODE,READONLY


; ------------------------------------------------------------
; Porting defines
; ------------------------------------------------------------
PABASE_PERI       EQU   0x1C000000  ; PA base of peripherals
PABASE_PERI2      EQU   0x1C100000  ; PA base of more peripherals

L1_COHERENT       EQU   0x00014c06  ; Template descriptor for coherent memory
L1_NONCOHERENT    EQU   0x00000c1e  ; Template descriptor for non-coherent memory
L1_DEVICE         EQU   0x00000c16  ; Template descriptor for device memory

; ------------------------------------------------------------

  ENTRY

  EXPORT Vectors

Vectors
  B      Reset_Handler
  B      Undefined_Handler
  B      SVC_Handler
  B      Prefetch_Handler
  B      Abort_Handler
  B .    ;Reserved vector
  B .    ;Reserved vector
  B      FIQ_Handler

; ------------------------------------------------------------
; Handlers for unused exceptions
; ------------------------------------------------------------

Undefined_Handler
  B       Undefined_Handler
SVC_Handler
  B       SVC_Handler
Prefetch_Handler
  B       Prefetch_Handler
Abort_Handler
  B       Abort_Handler
FIQ_Handler
  B       FIQ_Handler

; ------------------------------------------------------------
; Imports
; ------------------------------------------------------------
  IMPORT __main

  IMPORT ||Image$$PAGETABLES$$ZI$$Base||
  IMPORT ||Image$$EXEC$$Base||

; ------------------------------------------------------------
; Reset Handler - Generic initialization, run by all CPUs
; ------------------------------------------------------------

  EXPORT Reset_Handler
Reset_Handler PROC {}

;
; Disable caches, MMU and branch prediction in case they were left enabled from an earlier run
; This does not need to be done from a cold reset
; ------------------------------------------------------------
  MRC     p15, 0, r0, c1, c0, 0       ; Read CP15 System Control register
  BIC     r0, r0, #(0x1 << 12)        ; Clear I, bit 12, to disable I Cache
  BIC     r0, r0, #(0x1 << 11)        ; Clear Z, bit 11, to disable branch prediction
  BIC     r0, r0, #(0x1 <<  2)        ; Clear C, bit  2, to disable D Cache
  BIC     r0, r0, #(0x1 <<  1)        ; Clear A, bit  1, to disable strict alignment fault checking
  BIC     r0, r0, #0x1                ; Clear M, bit  0, to disable MMU
  MCR     p15, 0, r0, c1, c0, 0       ; Write CP15 System Control register

; The MMU is enabled later, before calling main().  Caches and branch prediction are enabled inside main(),
; after the MMU has been enabled and scatterloading has been performed.

  ;
  ; Invalidate caches
  ; ------------------
  MRC     p15, 1, r0, c0, c0, 1     ; Read CLIDR
  ANDS    r3, r0, #&7000000
  MOV     r3, r3, LSR #23           ; Cache level value (naturally aligned)
  BEQ     clean_invalidate_dcache_finished
  MOV     r10, #0

clean_invalidate_dcache_loop1
  ADD     r2, r10, r10, LSR #1      ; Work out 3xcachelevel
  MOV     r1, r0, LSR r2            ; bottom 3 bits are the Cache type for this level
  AND     r1, r1, #7                ; get those 3 bits alone
  CMP     r1, #2
  BLT     clean_invalidate_dcache_skip ; no cache or only instruction cache at this level
  MCR     p15, 2, r10, c0, c0, 0    ; write the Cache Size selection register
  ISB                               ; ISB to sync the change to the CacheSizeID reg
  MRC     p15, 1, r1, c0, c0, 0     ; reads current Cache Size ID register
  AND     r2, r1, #&7               ; extract the line length field
  ADD     r2, r2, #4                ; add 4 for the line length offset (log2 16 bytes)
  LDR     r4, =0x3FF
  ANDS    r4, r4, r1, LSR #3        ; R4 is the max number on the way size (right aligned)
  CLZ     r5, r4                    ; R5 is the bit position of the way size increment
  LDR     r7, =0x00007FFF
  ANDS    r7, r7, r1, LSR #13       ; R7 is the max number of the index size (right aligned)

clean_invalidate_dcache_loop2
  MOV     r9, R4                    ; R9 working copy of the max way size (right aligned)

clean_invalidate_dcache_loop3
  ORR     r11, r10, r9, LSL r5      ; factor in the way number and cache number into R11
  ORR     r11, r11, r7, LSL r2      ; factor in the index number
  MCR     p15, 0, r11, c7, c14, 2   ; DCCISW - clean and invalidate by set/way
  SUBS    r9, r9, #1                ; decrement the way number
  BGE     clean_invalidate_dcache_loop3
  SUBS    r7, r7, #1                ; decrement the index
  BGE     clean_invalidate_dcache_loop2

clean_invalidate_dcache_skip
  ADD     r10, r10, #2              ; increment the cache number
  CMP     r3, r10
  BGT     clean_invalidate_dcache_loop1

clean_invalidate_dcache_finished

  ;
  ; Clear Branch Prediction Array
  ; ------------------------------
  MOV     r0, #0x0
  MCR     p15, 0, r0, c7, c5, 6     ; BPIALL - Invalidate entire branch predictor array

  ;
  ; Invalidate TLBs
  ;------------------
  MOV     r0, #0x0
  MCR     p15, 0, r0, c8, c7, 0     ; TLBIALL - Invalidate entire Unified TLB

  ;
  ; Set up Domain Access Control Reg
  ; ----------------------------------
  ; b00 - No Access (abort)
  ; b01 - Client (respect table entry)
  ; b10 - RESERVED
  ; b11 - Manager (ignore access permissions)

  MRC     p15, 0, r0, c3, c0, 0      ; Read Domain Access Control Register
  LDR     r0, =0x55555555            ; Initialize every domain entry to b01 (client)
  MCR     p15, 0, r0, c3, c0, 0      ; Write Domain Access Control Register

  ;
  ; Set location of level 1 page table
  ;------------------------------------
  ; 31:14 - Base addr
  ; 13:5  - 0x0
  ; 4:3   - RGN 0x0 (Outer Noncachable)
  ; 2     - P   0x0
  ; 1     - S   0x0 (Non-shared)
  ; 0     - C   0x0 (Inner Noncachable)
  LDR     r0, =||Image$$PAGETABLES$$ZI$$Base||
  MCR     p15, 0, r0, c2, c0, 0


  ;
  ; Activate VFP/NEON, if required
  ;-------------------------------

  IF {TARGET_FEATURE_NEON} || {TARGET_FPU_VFP}

  ; Enable access to NEON/VFP by enabling access to Coprocessors 10 and 11.
  ; Enables Full Access i.e. in both privileged and non privileged modes
      MRC     p15, 0, r0, c1, c0, 2     ; Read Coprocessor Access Control Register (CPACR)
      ORR     r0, r0, #(0xF << 20)      ; Enable access to CP 10 & 11
      MCR     p15, 0, r0, c1, c0, 2     ; Write Coprocessor Access Control Register (CPACR)
      ISB

  ; Switch on the VFP and NEON hardware
      MOV     r0, #0x40000000
      VMSR    FPEXC, r0                   ; Write FPEXC register, EN bit set

  ENDIF


  ; Translation tables
  ; -------------------
  ; The translation tables are generated at boot time.  
  ; First the table is zeroed.  Then the individual valid
  ; entries are written in
  ;

  LDR     r0, =||Image$$PAGETABLES$$ZI$$Base||

  ; Fill table with zeros
  MOV     r2, #1024                 ; Set r3 to loop count (4 entries per iteration, 1024 iterations)
  MOV     r1, r0                    ; Make a copy of the base dst
  MOV     r3, #0
  MOV     r4, #0
  MOV     r5, #0
  MOV     r6, #0
ttb_zero_loop
  STMIA   r1!, {r3-r6}              ; Store out four entries
  SUBS    r2, r2, #1                ; Decrement counter
  BNE     ttb_zero_loop

  ;
  ; STANDARD ENTRIES
  ;

  ; Region covering program code and data
  LDR     r1,=||Image$$EXEC$$Base|| ; Base physical address of program code and data
  LSR     r1,#20                    ; Shift right to align to 1MB boundaries
  LDR     r3, =L1_COHERENT          ; Descriptor template
  ORR     r3, r1, LSL#20            ; Combine address and template
  STR     r3, [r0, r1, LSL#2]       ; Store table entry

  ; Entry for private address space
  ; Needs to be marked as Device memory
  MRC     p15, 4, r1, c15, c0, 0    ; Get base address of private address space
  LSR     r1, r1, #20               ; Clear bottom 20 bits, to find which 1MB block it is in
  LSL     r2, r1, #2                ; Make a copy, and multiply by four.  This gives offset into the page tables
  LSL     r1, r1, #20               ; Put back in address format
  LDR     r3, =L1_DEVICE            ; Descriptor template
  ORR     r1, r1, r3                ; Combine address and template
  STR     r1, [r0, r2]              ; Store table entry

  ; Enable MMU
  ; -----------
  ; Leave the caches disabled until after scatter loading.
  MRC     p15, 0, r0, c1, c0, 0       ; Read CP15 System Control register
  ORR     r0, r0, #0x1                ; Set M bit 0 to enable MMU before scatter loading
  MCR     p15, 0, r0, c1, c0, 0       ; Write CP15 System Control register


  ;
  ; Branch to C lib code
  ; ----------------------
  B       __main


  ENDP

; ------------------------------------------------------------
; End of code
; ------------------------------------------------------------

  END

; ------------------------------------------------------------
; End of startup.s
; ------------------------------------------------------------
