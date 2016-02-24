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

;---------------------
;variables
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

        jmp Finish


OpenError:
        invoke  WriteConsoleA, hStdOut, OFFSET errorFileOpen, SIZEOF errorFileOpen, OFFSET BytesWritten, NULL_PTR
        mov     RetCode,ERROR
        jmp     finish

Finish:
        ;Terminate Program
        invoke  ExitProcess, RetCode

Main    endp

        END Main

