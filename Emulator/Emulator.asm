        ;**************************************************************************************
        ; Jeff Stanton
        ; CS M30
        ; Program Assignment #2
        ;
        ; This program emulates the CPU described below.
        ;
        ; CPU contains 6 registers each 8 bits  (R0 – R5 valued 0 – 5)
        ; 16-bit address space 
        ; 1K of RAM 
        ; On reset the CPU begins execution at location 0. 
        ; CISC style instruction set, instruction length varies with instruction. 
        ; Register Operands are 1 byte.
        ; All memory addresses are 2 bytes long and are stored in big endian format.
        ;
        ;**************************************************************************************
        
        .586
        .MODEL flat, stdcall

        include Win32API.asm

        .STACK 4096

        .DATA

;---------------------
; EQUATES 
;---------------------

MAX_RAM             EQU     1024                ;Maximum size of emulated CPU's RAM
INVALID_HANDLE_VALUE EQU    -1                  ;CreateFile returns this value if it failed
_CR                 EQU     0Dh                 ;Carriage return character
_LF                 EQU     0Ah                 ;Line Feed (new line) character
NULL_PTR            EQU     0
ERROR               EQU     1                   ;return code indicating an error occurred
READ_FILE_ERROR     EQU     0                   ;ReadFile will return 0 if an error occurred

ADDING              EQU     11h                 ;OpCode for ADD
SUBTRACTING         EQU     22h                 ;OpCode for SUB
EXCLUSIVE_OR        EQU     44h                 ;OpCode for XOR
LOADING             EQU     05h                 ;OpCode for LOAD
LOADING_REG         EQU     55h                 ;OpCode for LOADR
STORING             EQU     06h                 ;OpCode for STORE
STORE_REG           EQU     66h                 ;OpCode for STORR
OUTPUT              EQU     0CCh                ;OpCode for OUT
JUMP_NOT_ZERO       EQU     0AAh                ;OpCode for JNZ
HALTCPU             EQU     0FFh                ;OpCode for HALT

;---------------------
; Variables
;---------------------

errorFileOpen       byte    "ERROR:  Unable to open input file", _CR, _LF

filename            byte    "c:\machine.bin", 0

ProgramBuffer       byte    MAX_RAM dup (0)        ;max size of RAM 1K

RetCode             dword   0

BytesWritten        dword   0
BytesRead           dword   0
FileHandle          dword   0
FileSize            dword   0
hStdOut             dword   0
hStdIn              dword   0

RegisterArray       byte    6 dup (0)               ;These are the 6 registers [R0-R5]
ArrayOutput         byte    0

        .CODE

Main    Proc

        ;*********************************
        ; Get Handle to Standard output
        ;*********************************
        invoke  GetStdHandle, STD_OUTPUT_HANDLE
        mov     hStdOut,eax

        ;*********************************
        ; Get Handle to Standard input
        ;*********************************
        invoke  GetStdHandle, STD_INPUT_HANDLE
        mov     hStdIn,eax

        ;*********************************
        ; Open existing file for Reading
        ;*********************************
        invoke  CreateFileA, offset filename, GENERIC_READ, FILE_SHARE_NONE,\
                             NULL_PTR, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL_PTR
        cmp     eax,INVALID_HANDLE_VALUE                    ;was open successful?
        je      OpenError                                   ;No....Display error and Exit
        mov     FileHandle,eax                              ;Yes...then save file handle

        ;********************************************
        ; Determine the size of the file (in bytes)
        ;********************************************
        invoke  GetFileSize, FileHandle, NULL_PTR
        mov     FileSize, eax

        ;****************************************
        ; Read the entire file into emulator RAM
        ;****************************************
        invoke  ReadFile, FileHandle, offset ProgramBuffer, FileSize, offset BytesRead, NULL_PTR
        cmp     eax,READ_FILE_ERROR     ;was it successful?
        je      Finish                  ;No...then Exit

        ;*********************************
        ; Close the file
        ;*********************************
        invoke  CloseHandle, FileHandle

        ; jmp Finish
       
        xor     edi, edi            ;index into ProgramBuffer
        jmp     Emulator


OpenError:
        invoke  WriteConsoleA, hStdOut, OFFSET errorFileOpen, SIZEOF errorFileOpen, OFFSET BytesWritten, NULL_PTR
        mov     RetCode,ERROR
        jmp     finish


        ;******************************************************************************
        ; ADD is OpCode 11h
        ; Addition adds the destination register with the source register and stores
        ; the result in the destination register
        ;******************************************************************************
Addition:
        mov bl, ProgramBuffer[edi * TYPE ProgramBuffer]     ;determine the destination register [0-5]
        inc edi
        mov al, ProgramBuffer[edi * TYPE ProgramBuffer]     ;determine which register will be added to destination register [0-5]

        mov cl, bl                                          ;need to preserve value of bl since its the index to RegisterArray
        add cl, al
        mov RegisterArray[ebx * TYPE RegisterArray], cl     ;store result in specified register
        mov RegisterArray[eax * TYPE RegisterArray], al     ;store source operand in specified register

        inc edi                                             ;get the next OpCode
        jmp Emulator                                        ;jump to determine which OpCode to execute


        ;********************************************************************************
        ; SUB is OpCode 22h
        ; Subtraction subtracts the destination register from the source register and
        ; stores the result in the destination register
        ;********************************************************************************
Subtraction:
        mov bl, ProgramBuffer[edi * TYPE ProgramBuffer]     ;this is the destination register
        inc edi
        mov al, ProgramBuffer[edi * TYPE ProgramBuffer]     ;this is the source register

        mov RegisterArray[eax * TYPE RegisterArray] , al    ;store source operand in specified register

        mov cl, bl                                          ;need to preserve value of bl since its the index to RegisterArray
        sub cl, al
        mov RegisterArray[ebx * TYPE RegisterArray], cl     ;store result in specified register
        
        inc edi                                             ;get the next OpCode
        jmp Emulator                                        ;jump to determine which OpCode to execute


        ;*************************************************************************************
        ; XOR is OpCode 44h
        ; ExclusiveOr stores the value of the destination register XOR with another register
        ;*************************************************************************************
ExclusiveOr:
        mov bl, ProgramBuffer[edi * TYPE ProgramBuffer]     ;this is destination register, used to index RegisterArray
        inc edi                                             ;next element in the array
        mov al, ProgramBuffer[edi * Type ProgramBuffer]     ;this is the source register
        
        mov cl, bl                                          ;need to preserve destination register since its used to index the array
        xor cl, al
        mov RegisterArray[ebx * TYPE RegisterArray], cl     ;store result in specified register
        mov RegisterArray[eax * TYPE RegisterArray], al     ;move source register into specified register in array
        
        inc edi                                             ;get the next OpCode
        jmp Emulator                                        ;jump to determine which OpCode to execute


        ;****************************************************************************
        ; LOAD is OpCode 05h
        ; Load_ loads the specified register with the value at the specified address
        ;****************************************************************************
Load_:
        mov bl, ProgramBuffer[edi * TYPE ProgramBuffer]     ;determine which register to load value into, used to index RegisterArray
        inc edi                                             ;next element in array
        mov al, ProgramBuffer[edi * TYPE ProgramBuffer]     ;get the first address byte
        inc edi                                             ;next element in array
        mov ah, ProgramBuffer[edi * TYPE ProgramBuffer]     ;get the second address byte

        mov cl, [eax]                                       ;eax has address in correct little endian format - get the value from it
        mov RegisterArray[ebx * TYPE RegisterArray], cl     ;load register with this value
        
        inc edi                                             ;get the next OpCode
        jmp Emulator                                        ;jump to determine which OpCode to execute
    

        ;*****************************************************************************
        ; LOADR is OpCode 55h
        ; Load_R loads the specified register with the value at [address + register]
        ;*****************************************************************************
Load_R:
        mov bl, ProgramBuffer[edi * TYPE ProgramBuffer]     ;this is the destination register
        inc edi                                             ;need to get the first byte of the address
        mov al, ProgramBuffer[edi * TYPE ProgramBuffer]     ;store first address byte
        inc edi                                             ;need to get the second byte of the address
        mov ah, ProgramBuffer[edi * TYPE ProgramBuffer]     ;store second address byte

        movsx ebx, bl                                       ;need ebx to do indirect addressing required by instruction
        mov cl, bl                                          ;to index the correct register in RegisterArray
        mov bl, [ebx + eax]                                 ;load the register with the value at [register + address]
        mov RegisterArray[ecx * TYPE RegisterArray], bl     ;load register with this value
        
        inc edi                                             ;get the next OpCode
        jmp Emulator                                        ;jump to determine which OpCode to execute
        

        ;*********************************************************
        ; STORE is OpCode 06h
        ; Store_ writes the value in R0 to the specified address
        ;*********************************************************
Store_:
        mov al, ProgramBuffer[edi * TYPE ProgramBuffer]     ;get the first address byte
        inc edi
        mov ah, ProgramBuffer[edi * TYPE ProgramBuffer]     ;get the second address byte

        mov cl, RegisterArray                               ;copy value of R0 to register
        mov [eax], cl                                       ;copy value to specified address

        inc edi                                             ;get the next OpCode
        jmp Emulator                                        ;jump to determine which OpCode to execute


        ;****************************************************************************
        ; STORR is OpCode 66h
        ; Store_R writes the value in R0 to [specified address + specified register]
        ;****************************************************************************
Store_R:
        mov bl, ProgramBuffer[edi * TYPE ProgramBuffer]     ;get the register
        inc edi
        mov al, ProgramBuffer[edi * TYPE ProgramBuffer]     ;get the first address byte
        inc edi
        mov ah, ProgramBuffer[edi * TYPE ProgramBuffer]     ;get the second address byte

        mov cl, RegisterArray                               ;copy value of R0 to register
        movsx ebx, bl                                       ;need ebx to do indirect addressing required by instruction
        mov [eax + ebx], cl                                 ;copy value of R0 to [specified address + specified register]

        inc edi                                             ;get the next OpCode
        jmp Emulator                                        ;jump to determine which OpCode to execute


        ;*********************************************************
        ; OUT is OpCode 0CCh
        ; Out_ sends the value in the specified register to output
        ;**********************************************************
Out_:
        mov bl, ProgramBuffer[edi * TYPE ProgramBuffer]     ;get the register

        mov ArrayOutput, bl

        invoke  WriteConsoleA, hStdOut, OFFSET ArrayOutput, SIZEOF ArrayOutput, OFFSET BytesWritten, NULL_PTR

        inc edi                                             ;get the next OpCode
        jmp Emulator                                        ;jump to determine which OpCode to execute
        

        ;********************************************************************
        ; JNZ is OpCode 0AAh
        ; JNZ_ uses the specified register to determine the next instruction
        ;********************************************************************
JNZ_:
        mov bl, ProgramBuffer[edi * TYPE ProgramBuffer]     ;get the register
        mov RegisterArray[ebx * TYPE ProgramBuffer], bl     ;store value in specified array

        cmp bl, 0                                           ;if the value isn't zero, then get instruction from address
        jne NotZero                                         ;instructions to get the instruction from specified address

        inc edi                                             ;Otherwise, get the next OpCode
        jmp Emulator                                        ;jump to determine which OpCode to execute


NotZero:
        inc edi
        mov al, ProgramBuffer[edi * TYPE ProgramBuffer]     ;get the first address byte
        inc edi
        mov ah, ProgramBuffer[edi * TYPE ProgramBuffer]     ;get the second address byte

        mov edi, [eax]                                      ;get the next OpCode from specified address
        jmp Emulator                                        ;jump to determine which OpCode to execute
        
        ;*******************************************************************
        ;Parses ProgramBuffer array and determines the OpCode to execute
        ;*******************************************************************
Emulator:
        xor ebx, ebx

        mov bl, ProgramBuffer[edi * TYPE ProgramBuffer]     ;get the OpCode
        inc edi

        xor eax, eax
        xor ecx, ecx
        xor edx, edx

        cmp bl, ADDING
        je  Addition

        cmp bl, SUBTRACTING
        je  Subtraction

        cmp bl, EXCLUSIVE_OR
        je  ExclusiveOr

        cmp bl, LOADING
        je  Load_

        cmp bl, LOADING_REG
        je  Load_R

        cmp bl, STORING
        je  Store_

        cmp bl, STORE_REG
        je  Store_R

        cmp bl, OUTPUT
        je  Out_

        cmp bl, JUMP_NOT_ZERO
        je  JNZ_

        cmp bl, HALTCPU
        je  Finish
        
        jmp Finish

Finish:
        ;Terminate Program
        invoke  ExitProcess, RetCode

Main    endp

        END Main