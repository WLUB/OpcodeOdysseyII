%include "data/settings.asm"

; player.asm
global _player_ptr
global _player_init
global _player_handle_inputs

; SDL
extern _SDL_GetKeyboardState

; SDT
extern _cosf
extern _sinf

section .data
    initPosX            dd PLAYER_POS_X
    initPosY            dd PLAYER_POS_Y
    initAngle           dd PLAYER_ANGLE
    deltaX              dd PLAYER_DELTA_X
    deltaY              dd PLAYER_DELTA_Y

    const_TAU           dd TAU
    const_NEG           dd NEG
    const_TURN_SPEED    dd TURN_SPEED
    const_MOVMENT_SPEED dd MOVMENT_SPEED

section .bss

    ; - Player Layout -
    ; x         (float) (0 )
    ; y         (float) (4 )
    ; angle     (float) (8 )
    ; delta x   (float) (12)
    ; delta y   (float) (16)
    player          resb 20 

section .text

;; Returns a pointer to the player object. 
align 16
_player_ptr:
    mov rax, player 
    ret

;; Init player with vars.
_player_init:
    push rbp              
    mov rbp, rsp

    movss xmm0, dword [rel initPosX]
    movss dword [rel player + 0 ], xmm0
    movss xmm0, dword [rel initPosY]
    movss dword [rel player + 4 ], xmm0
    movss xmm0, dword [rel initAngle]
    movss dword [rel player + 8 ], xmm0
    movss xmm0, dword [rel deltaX]
    movss dword [rel player + 12], xmm0
    movss xmm0, dword [rel deltaY]
    movss dword [rel player + 16], xmm0

    mov rsp, rbp
    pop rbp
    ret

_player_handle_inputs:
    push rbp              
    mov  rbp, rsp

    xor  rdi, rdi                
    call _SDL_GetKeyboardState      ; Load pointer in rax

    ; Load player ptr
    mov rsi, player 

    cmp dword [rax + SDL_SCANCODE_UP], 1
    je forward
    cmp dword [rax + SDL_SCANCODE_DOWN], 1
    jne v_movement_end

    backwards: 
    movss xmm0, dword [rsi + 0 ]     
    subss xmm0, dword [rsi + 12]
    movss dword [rsi + 0], xmm0     ; x -= dx

    movss xmm0, dword [rsi + 4 ]     
    subss xmm0, dword [rsi + 16]
    movss dword [rsi + 4], xmm0     ; y -= dy
    jmp v_movement_end

    forward:
    movss xmm0, dword [rsi + 0 ]     
    addss xmm0, dword [rsi + 12]
    movss dword [rsi + 0], xmm0     ; x += dx

    movss xmm0, dword [rsi + 4 ]     
    addss xmm0, dword [rsi + 16]
    movss dword [rsi + 4], xmm0     ; y += dy
    v_movement_end:

    cmp dword [rax + SDL_SCANCODE_RIGHT], 1
    je right
    cmp dword [rax + SDL_SCANCODE_LEFT], 1
    jne turn_end

    left:
    ; player.angle += TURN_SPEED
    movss xmm0, dword [rsi + 8]             ; Load angle
    addss xmm0, dword [rel const_TURN_SPEED]  
    movss dword [rsi + 8], xmm0     

    ucomiss xmm0, dword [rel const_TAU]     ; Compare angle with 2*PI
    jle not_greater_than_TAU                ; Jump if angle <= 2*PI
    subss xmm0, dword [rel const_TAU]       ; angle -= 2*PI
    movss dword [rsi + 8], xmm0             ; Store angle
    not_greater_than_TAU:

    jmp update_deltas

    right:
    ; player.angle -= TURN_SPEED
    movss xmm0, dword [rsi + 8]   
    subss xmm0, dword [rel const_TURN_SPEED]  
    movss dword [rsi + 8], xmm0     

    ; Make sure that angle is in range 
    xorps xmm1, xmm1                    ; Load 0 into xmm1
    ucomiss xmm0, xmm1                  ; Compare player.angle with 0
    jge not_less_than_zero              ; Jump if ra >= 0
    addss xmm0, dword [rel const_TAU]   ; player.angle += 2*PI
    movss dword [rsi + 8], xmm0         ; Store player.angle
    not_less_than_zero:

    update_deltas:
    ; cos(angle) * MOVMENT_SPEED
    ; We know that the angle is saved in xmm0
    call _cosf                          
    mulss xmm0, dword [rel const_MOVMENT_SPEED] 
    movss dword [rsi + 12], xmm0        ; update delta x

    ; -sin(player.angle) * MOVMENT_SPEED
    movss xmm0, dword [rsi + 8]         ; load angle
    call _sinf                          
    mulss xmm0, dword [rel const_MOVMENT_SPEED]   
    mulss xmm0, dword [rel const_NEG]                  
    movss dword [rsi + 16], xmm0        ; update delta y
    turn_end:

    mov rsp, rbp
    pop rbp
    ret