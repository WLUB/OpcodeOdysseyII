%include "data/settings.asm"

; window.asm
global _window_init_sdl
global _window_create
global _window_create_renderer
global _window_create_texture
global _window_present

; SDL2
extern _SDL_Init
extern _SDL_CreateWindow
extern _SDL_GetWindowSurface
extern _SDL_CreateTexture
extern _SDL_CreateRenderer
extern _SDL_UpdateTexture
extern _SDL_RenderCopyEx
extern _SDL_RenderPresent

section .data
    window_title            db  TITLE,0
    width                   equ SCREEN_WIDTH
    height                  equ SCREEN_HEIGHT

section .text

; Return 0 on success
_window_init_sdl:
    ; Initialize the SDL library
    mov rdi, SDL_INIT_VIDEO 
    call _SDL_Init      ; Return 0 on success
    ret

; Return 1 on success
_window_create_renderer:
    mov esi, -1
    mov edx, SDL_RENDERER_PRESENTVSYNC
    call _SDL_CreateRenderer
    ret

; Return 1 on success
_window_create_texture:

    mov esi, SDL_PIXELFORMAT_ABGR8888
    mov edx, SDL_TEXTUREACCESS_STREAMING
    mov ecx, width
    mov r8d, height
    call _SDL_CreateTexture
    ret

; Return 1 on success
_window_create:

    ; Create a window
    mov rdi, window_title   ; title
    mov esi, 0              ; x
    mov edx, 0              ; y
    mov ecx, width          ; w
    mov r8d, height         ; h
    mov r9d, 0              ; flags 
    call _SDL_CreateWindow  ; 0 on error

    ret


; Parameters:
; rdi - pixels
; rsi - texture
; rdx - renderer
_window_present:
    sub rsp, 24               ; allocate space for 3 pointers (8 bytes each)       
    mov qword [rbp - 8],  rdi ; assign pixels to the first local variable
    mov qword [rbp - 16], rsi ; assign texture to the second local variable
    mov qword [rbp - 24], rdx ; assign renderer to the third local variable

    mov rdi, [rbp - 16]
    mov rsi, 0
    mov rdx, [rbp - 8]
    mov ecx, SCREEN_WIDTHx4
    call _SDL_UpdateTexture

    mov rdi, [rbp - 24]
    mov rsi, [rbp - 16]
    xor edx, edx
    xor ecx, ecx
    ; Set angle to zero
    pxor xmm0, xmm0     
    xor r8, r8
    mov r9, SDL_FLIP_VERTICAL
    call _SDL_RenderCopyEx

    mov rdi, [rbp - 24]
    call    _SDL_RenderPresent
    
    add rsp, 24
    ret