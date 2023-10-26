%include "data/settings.asm"

; main.asm
global _main

; Window 
extern _window_init_sdl
extern _window_create
extern _window_create_renderer
extern _window_create_texture
extern _window_present

; renderer.asm
extern _render

; player.asm 
extern _player_ptr
extern _player_init
extern _player_handle_inputs

; SDL
extern _SDL_DestroyTexture
extern _SDL_DestroyRenderer
extern _SDL_DestroyWindow
extern _SDL_Quit
extern _SDL_PollEvent

; Utility
extern _memset        

section .bss
    ptr_window      resq 1
    ptr_texture     resq 1
    ptr_renderer    resq 1

    running         resb 1
    sdl_event       resb 56   

    pixels          resb PIXEL_SIZE


section .text

_main:
    call init
    call main_loop
    call clean_up
    ret

init: 
    push rbp              
    mov rbp, rsp

    ; Init
    mov byte [rel running], 1
    
    ; Initialize player
    call _player_init

    ; Initialize the SDL library
    call _window_init_sdl    
    test rax, rax                   
    jnz exit_with_error 
    
    ; Create window
    call _window_create  
    mov qword [rel ptr_window], rax  
    test rax, rax                   
    jz exit_with_error 

    ; Create renderer
    mov rdi, qword [rel ptr_window]
    call _window_create_renderer
    mov qword [rel ptr_renderer], rax 
    test rax, rax
    jz exit_with_error 

    ; Create texture
    mov rdi, qword [rel ptr_renderer]
    call _window_create_texture
    mov qword [rel ptr_texture], rax 
    test rax, rax
    jz exit_with_error 

    mov rsp, rbp
    pop rbp
    ret

main_loop:
    ; Reset pixel data
    mov rdi, qword pixels
    xor rsi, rsi 
    mov edx, dword PIXEL_SIZE
    call _memset

    mov rdi, qword pixels
    call _player_ptr
    mov rsi, rax
    call _render

    mov rdi, qword pixels
    mov rsi, qword [rel ptr_texture]
    mov rdx, qword [rel ptr_renderer]
    call _window_present


    mov rdi, sdl_event         
    call _SDL_PollEvent
    test rax, rax          
    jz main_loop

    cmp dword [rel sdl_event], SDL_QUIT    
    je main_loop_exit

    call _player_handle_inputs

    ; Check if running...
    cmp word [rel running], 0    
    jnz main_loop
main_loop_exit:
    ret

clean_up:
    mov rdi, qword [rel ptr_texture]
    call _SDL_DestroyTexture
    
    mov rdi, qword [rel ptr_renderer]
    call _SDL_DestroyRenderer

    mov rdi, qword [rel ptr_window]
    call _SDL_DestroyWindow

    call _SDL_Quit
    ret

exit_with_error: 
    mov rax, SYSCALL_EXIT  
    mov rdi, ERROR_EXIT_CODE 
    syscall







