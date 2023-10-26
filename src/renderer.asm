%include "data/settings.asm"

global _render

; Import math functions from C
extern _cosf
extern _sinf
extern _tanf

section .data
    const_ONE           dd  ONE
    const_DEG           dd  DEG
    const_FOV           dd  FOV
    const_TAU           dd  TAU
    const_FOV_f         dd  FOV_F
    const_half          dd  0.5
    const_0_0001        dd  0.001
    const_neg_0_0001    dd -0.001
    const_64            dd  64.0
    const_neg_64        dd -64.0
    map                 db MAP
    const_DISTANCE_MAX  dd DISTANCE_MAX


section .text

; Function: render_walls
; Renders a wall.
;
; Parameters:
;   rdi  - pixel : A pointer to the pixel data
;   esi  - r     : 
;   edx  - color : 
;   xmm0 - distT : 
;
render_walls:
    push rbp
    mov rbp, rsp
    sub rsp, 20              
    mov   qword [rbp - 8 ],  rdi     ; Pixel ptr
    mov   dword [rbp - 12],  esi     ; r
    mov   dword [rbp - 16],  edx     ; color
    movss dword [rbp - 20],  xmm0    ; distT


    ; Calculating line height
    ; (MAP_SIZE * SCREEN_HEIGHT) / distT
    ; We should be able to load MAP_SIZE_SCREEN_HEIGHT
    ; direct to XMM and remove these three...
    mov eax, MAP_SIZE_SCREEN_HEIGHT ;   MAP_SIZE * SCREEN_HEIGHT          
    cvtsi2ss xmm0, eax    

    movss xmm1, dword [rbp - 20]    ; loading distT into xmm1
    divss xmm0, xmm1                ; line height stored in xmm0      

    ; Calculating line offset                     
    cvttss2si eax, xmm0             ; Converting line height to int
    mov r15d, eax                   ; Store a copy in r15d
    
    ; Safety check
    cmp r15d, SCREEN_HEIGHT
    jle line_height_safe            ; lineHeight > SCREEN_HEIGHT
    mov r15d, SCREEN_HEIGHT         ; line height = SCREEN_HEIGHT;
    mov eax, r15d
    line_height_safe:
    
    sar eax, 1                      ; shift to devied by 2
    mov r14d, SCREEN_HEIGHT_HALF    
    sub r14d, eax                   ; SCREEN_HEIGHT_HALF - (LineHight/2)

    ; Set up line thickness
    mov  r13d, [rbp - 12]    ; Store r*5 
    imul r13d, 5
    mov  r12d, r13d
    add  r12d, 5             ; Store r*5+5

    ;; r15d : Line height
    ;; r14d : Line offset
    ;; r13d : r*5 (x_index)
    ;; r12d : r*5+5
    ;; r11d : y   (y_index)

    ; Inner loop - x
    render_walls_loop_x:
        ; Inner loop - y
        xor r11d, r11d      ; set y = 0
        render_walls_loop_y:
            
            xor  r10,  r10
            mov  r10d, r11d      ; y_index 
            add  r10d, r14d      ; y_index + lineOffset
            imul r10d, SCREEN_WIDTH
            add  r10d, r13d      ; (y_index + lineOffset) * SCREEN_WIDTH) + (x_index)

            ; Check if pixel index is valid
            cmp r10d, SCREEN_SIZE
            jg render_walls_loop_y_break    ; pixel > SCREEN_SIZE
            xor r8, r8
            cmp r10d, r8d
            jl render_walls_loop_y_break    ; pixel < 0

            ; Update pixel color
            mov r8,  qword [rbp - 8 ]       ; load pixel pointer
            mov r9d, dword [rbp - 16]       ; color
            mov dword [r8 + r10 * 4], r9d   ; set color of pixel


        ; Y-Loop check
        inc r11d              ; y++
        cmp r11d, r15d        ; y<lineHeight
        jl render_walls_loop_y
        render_walls_loop_y_break:
    ; X-Loop check
    inc r13d              ; (r*5)++
    cmp r13d, r12d        ; r*5 < ((og r) * 5 + 15)
    jl render_walls_loop_x

    render_walls_end:
    mov rsp, rbp
    pop rbp
    ret

; Function: distance
; Calculates the distance between two points (x0, y0) and (x1, y1) with a given angle.
;
; Parameters:
;   xmm0 - x0    : The x-coordinate of the first point.
;   xmm1 - y0    : The y-coordinate of the first point.
;   xmm2 - x1    : The x-coordinate of the second point.
;   xmm3 - y1    : The y-coordinate of the second point.
;   xmm4 - angle : The angle for the calculation.
;
; Returns:
;   The result of the calculation is returned in xmm0.
;
distance:
    push rbp        
    mov  rbp, rsp   
    sub rsp, 32       

    ; Init vars
    xorpd xmm5, xmm5
    movss dword [rbp - 4 ],  xmm0   ; x0 
    movss dword [rbp - 8 ],  xmm1   ; y0 
    movss dword [rbp - 12],  xmm2   ; x1 
    movss dword [rbp - 16],  xmm3   ; y1 
    movss dword [rbp - 20],  xmm4   ; angle 
    movss dword [rbp - 24],  xmm5   ; diff_x (x1 - x0) 
    movss dword [rbp - 28],  xmm5   ; diff_y (y1 - y0) 
    movss dword [rbp - 32],  xmm5   ; dist_x (cos(angle) * (x1 - x0))

    subss xmm2, xmm0                ; x1 - x0
    subss xmm3, xmm1                ; y1 - y0
    movss dword [rbp - 24], xmm2    ; diff_x
    movss dword [rbp - 28], xmm3    ; diff_y

    movss xmm0, dword [rbp - 20]    ; copy angle to xmm0
    call _cosf                      ; cos(angle), result in xmm0
    mulss xmm0, dword [rbp - 24]    ; cos(angle) * (x1 - x0)
    movss dword [rbp - 32], xmm0    ; store result in xmm2 

    movss xmm0, dword [rbp - 20]    ; copy angle to xmm0
    call _sinf                      ; sin(angle), result in xmm0
    mulss xmm0, dword [rbp - 28]    ; sin(angle) * (y1 - y0)
    movss xmm1, dword [rbp - 32]
    subss xmm1, xmm0                ; cos(angle)*(x1-x0) - sin(angle)*(y1-y0), result in xmm2
    movss xmm0, xmm1                ; move result to xmm0 for return
    
    %ifdef DEBUG
    cvttss2si r10d, xmm0 
    int 3 
    %endif

    mov rsp, rbp   ; undo the carving of space for the local variables
    pop rbp        ; restore the previous stackbase-pointer register
    ret

; Function: render_wall
; This function is resonsible for rendering the walls
; This is also the function that calculate the rays.
;
; Parameters:
;   rdi - pixel  : A pointer to the pixel data.
;   rsi - player : A pointer to the player data.
;
render_wall:
    push rbp
    mov rbp, rsp
    sub rsp, 84             

    mov qword [rbp - 8 ],  rdi              ; Pixel     ptr
    mov qword [rbp - 16],  rsi              ; Player    ptr
    
    ; Init vars
    xor r8, r8
    xorpd xmm0, xmm0
    mov   dword [rbp - 20],  r8d            ; r
    mov   dword [rbp - 24],  r8d            ; mx
    mov   dword [rbp - 28],  r8d            ; my
    mov   dword [rbp - 32],  r8d            ; mp
    mov   dword [rbp - 36],  r8d            ; dof
    movss dword [rbp - 40],  xmm0           ; vx 
    movss dword [rbp - 44],  xmm0           ; vy
    movss dword [rbp - 48],  xmm0           ; rx
    movss dword [rbp - 52],  xmm0           ; ry
    movss dword [rbp - 56],  xmm0           ; ra
    movss dword [rbp - 60],  xmm0           ; xo
    movss dword [rbp - 64],  xmm0           ; yo
    movss dword [rbp - 68],  xmm0           ; distT
    movss dword [rbp - 72],  xmm0           ; distV
    movss dword [rbp - 76],  xmm0           ; distH
    mov   dword [rbp - 80],  0xFFFFFF       ; color
    movss dword [rbp - 84],  xmm0           ; tan

    ; Initizilise ra
    mov rsi, [rbp - 16]
    movss xmm0, dword [rsi + 8]             ; Load player angle 
    movss xmm1, dword [rel const_DEG] 
    mulss xmm1, dword [rel const_FOV_f]     ; DEG*FOV
    mulss xmm1, dword [rel const_half]      ; (DEG*FOV) / 2
    addss xmm0, xmm1                        ; player.angle + (DEG*FOV) / 2
    movss dword [rbp - 56], xmm0            ; ra = player.angle + (DEG*FOV) / 2

    ; Make sure that ra is in range
    movss xmm0, dword [rbp - 56]            ; Load ra
    xorps xmm1, xmm1                        ; Load 0 into xmm1
    ucomiss xmm0, xmm1                      ; Compare ra with 0
    jae not_less_than_zero                  ; Jump if ra >= 0
    addss xmm0, dword [rel const_TAU]       ; ra += 2*PI
    movss dword [rbp - 56], xmm0            ; Store ra

    not_less_than_zero:
    movss xmm0, dword [rbp - 56]            ; Load ra
    ucomiss xmm0, dword [rel const_TAU]     ; Compare ra with 2*PI
    jbe not_greater_than_TAU                ; Jump if ra <= 2*PI
    subss xmm0, dword [rel const_TAU]       ; ra -= 2*PI
    movss dword [rbp - 56], xmm0            ; Store ra
    not_greater_than_TAU:

    render_loop_start:                      ; Loop (r < FOV)
    mov ecx, [rel const_FOV]
    cmp dword [rbp - 20], ecx               ; Compare r with FOV
    jge render_loop_end                     ; If r >= FOV, exit loop

    ; Init
    mov dword [rbp - 36], 0                 ; dof = 0

    movss xmm0, [rel const_DISTANCE_MAX]
    movss dword [rbp - 72], xmm0            ; distV = 100000

    movss xmm0, dword [rbp - 56]            ; Store tan(ra)
    call _tanf
    movss dword [rbp - 84], xmm0

    movss xmm0, dword [rbp - 56]                ; ra
    call _cosf                                  ; result stored in xmm0
    ucomiss xmm0, dword [rel const_0_0001]      ; Check if cos(ra) > 0.001
    ja greater_than_limit                       ; Jump if cos(ra) > 0.001
    ucomiss xmm0, dword [rel const_neg_0_0001]  ; Check if cos(ra) < -0.001
    jb less_than_neg_limit                      ; Jump if cos(ra) < -0.001
   
    ; ---- Else ------
    mov rsi, [rbp - 16]
    movss xmm0, dword [rsi]                 ; Load player.pos.x
    movss dword [rbp - 48], xmm0            ; rx = player.pos.x;
    movss xmm0, dword [rsi + 4]             ; Load player.pos.y
    movss dword [rbp - 52], xmm0            ; ry = player.pos.y;
    mov dword [rbp - 36], 8                 ; dof = 8

    jmp end_if_limit
    greater_than_limit:

    ; int 3
    ; rx = (((int) player.pos.x >> 6) << 6) + 64;
    mov rsi, [rbp - 16]
    movss xmm0, dword [rsi]                 ; Load player.pos.x
    cvttss2si eax, xmm0                     ; Convert to integer
    sar eax, 6                              ; Shift right by 6
    shl eax, 6                              ; Shift left by 6
    add eax, 64                             ; Add 64
    cvtsi2ss xmm0, eax                      ; Convert back to float
    movss dword [rbp - 48], xmm0            ; Store to rx

    ; ry = (player.pos.x - rx) * Tan + player.pos.y;
    movss xmm0, dword [rsi]                 ; Load player.pos.x
    subss xmm0, dword [rbp - 48]            ; Subtract rx
    mulss xmm0, dword [rbp - 84]            ; Multiply by Tan
    addss xmm0, dword [rsi + 4]             ; Add player.pos.y
    movss dword [rbp - 52], xmm0            ; Store to ry
    xor rsi, rsi

    ; xo = 64;
    movss xmm0, dword [rel const_64]        ; Load 64
    movss dword [rbp - 60], xmm0            ; Store to xo

    ; yo = -xo * Tan;
    mulss xmm0, dword [rbp - 84]            ; Multiply by Tan
    xorps xmm1, xmm1                        ; Zero xmm1
    subss xmm1, xmm0                        ; Negate result
    movss dword [rbp - 64], xmm1            ; Store to yo

    jmp end_if_limit

    less_than_neg_limit:
    ; rx = (((int) player.pos.x >> 6) << 6) - 0.0001;
    mov rsi, [rbp - 16]
    movss xmm0, [rsi]                       ; Load player.pos.x
    cvttss2si eax, xmm0                     ; Convert to integer
    sar eax, 6                              ; Shift right by 6
    shl eax, 6                              ; Shift left by 6
    cvtsi2ss xmm0, eax                      ; Convert back to float
    subss xmm0, dword [rel const_0_0001]    ; Subtract 0.0001
    movss dword [rbp - 48], xmm0            ; Store to rx

    ; ry = (player.pos.x - rx) * Tan + player.pos.y;
    movss xmm0, dword [rsi]                 ; Load player.pos.x
    subss xmm0, dword [rbp - 48]            ; Subtract rx
    mulss xmm0, dword [rbp - 84]            ; Multiply by Tan
    addss xmm0, dword [rsi + 4]             ; Add player.pos.y
    movss dword [rbp - 52], xmm0            ; Store to ry

    ; xo = -64;
    movss xmm0, dword [rel const_neg_64]    ; Load 64
    movss dword [rbp - 60], xmm0            ; Store to xo

    ; yo = -xo * Tan;
    mulss xmm0, dword [rbp - 84]            ; Multiply by Tan
    xorps xmm1, xmm1                        ; Zero xmm1
    subss xmm1, xmm0                        ; Negate result
    movss dword [rbp - 64], xmm1            ; Store to yo

    end_if_limit:

    dof_loop_start:
        ; If dof >= 8, jump to end of loop
        cmp dword [rbp - 36], 8 
        jge dof_loop_end       

        ; Devide 64;
        ; mx = (int) (rx) >> 6
        movss xmm0, dword [rbp - 48]        ; Load rx
        cvttss2si eax, xmm0                 ; Convert to integer
        sar eax, 6                          ; Shift right by 6
        mov [rbp - 24], eax                 ; Store to mx

        ; my = (int) (ry) >> 6
        movss xmm0, dword [rbp - 52]        ; Load ry
        cvttss2si eax, xmm0                 ; Convert to integer
        sar eax, 6                          ; Shift right by 6
        mov [rbp - 28], eax                 ; Store to my

        ; mp = my*MAP_X + mx
        mov eax, [rbp - 28]                 ; Load my
        imul eax, MAP_X                     ; Multiply my by MAP_X
        add eax, [rbp - 24]                 ; Add mx
        mov [rbp - 32], eax                 ; Store to mp
        movsxd rax, eax

        ; Hit wall
        ; if mp > 0 && mp < MAP_SIZE && map[mp] == 1
        cmp dword [rbp - 32], 0             ; Compare mp with 0
        jl not_hit_wall                     ; If mp <= 0, not a hit
        cmp dword [rbp - 32], MAP_SIZE      ; Compare mp with MAP_SIZE
        jge not_hit_wall                    ; If mp >= MAP_SIZE, not a hit

        lea rdi, qword [rel map]            ; We load the address to map
        mov al, byte [rdi + rax]            ; load map[mp] into al
        movzx eax, al                       ; zero-extend al into eax

        cmp eax, 1                          ; Compare map[mp] with 1
        jne not_hit_wall                    ; If map[mp] != 1, not a hit

        ; distV = distance(player.pos.x, player.pos.y, rx, ry, ra)
        mov   rsi, [rbp - 16]
        movss xmm0, dword [rsi]             ; Load player.pos.x
        movss xmm1, dword [rsi + 4]         ; Load player.pos.y
        movss xmm2, dword [rbp - 48]        ; Load rx
        movss xmm3, dword [rbp - 52]        ; Load ry
        movss xmm4, dword [rbp - 56]        ; Load ra
        call distance                       ; Call distance function
        movss dword [rbp - 72], xmm0        ; Store result to distV
        
        jmp dof_loop_end                    ; Break out of loop

        not_hit_wall:
        ; rx += xo;
        movss xmm0, dword [rbp - 48]        ; Load rx
        addss xmm0, dword [rbp - 60]        ; Add xo
        movss dword [rbp - 48], xmm0        ; Store to rx

        ; ry += yo;
        movss xmm0, dword [rbp - 52]        ; Load ry
        addss xmm0, dword [rbp - 64]        ; Add yo
        movss dword [rbp - 52], xmm0        ; Store to ry

        inc dword [rbp - 36]                ; Increment dof
        jmp dof_loop_start                  ; Continue loop

    dof_loop_end:

    movss xmm0, dword [rbp - 48] 
    movss dword [rbp - 40], xmm0            ; vx = rx
    movss xmm0, dword [rbp - 52] 
    movss dword [rbp - 44], xmm0            ; vy = ry
    mov dword [rbp - 36], 0                 ; dof = 0

    movss xmm0, [rel const_DISTANCE_MAX]
    movss dword [rbp - 76], xmm0            ; distH = 100000

    ; movss xmm0, dword [rel const_ONE]
    ; divss xmm0, dword [rbp - 84]                
    ; movss dword [rbp - 84], xmm0          ; div by zero
    xorps xmm7, xmm7
    rcpss xmm7, dword [rbp - 84]
    movss dword [rbp - 84], xmm7
                                                ; if sin(ra) > 0.001
    movss xmm0, dword [rbp - 56]                ; ra
    call _sinf                                  ; result stored in xmm0
    ucomiss xmm0, dword [rel const_0_0001]      ; Check if sin(ra) > 0.001
    ja greater_than_limit_2                     ; Jump if sin(ra) > 0.001
    ucomiss xmm0, dword [rel const_neg_0_0001]  ; Check if sin(ra) < -0.001
    jb less_than_neg_limit_2                    ; Jump if sin(ra) < -0.001
    ; ---- Else ------
   
    mov rsi, qword [rbp - 16]
    movss xmm0, dword [rsi + 0]             ; Load player.pos.x
    movss dword [rbp - 48], xmm0            ; rx = player.pos.x;
    movss xmm0, dword [rsi + 4]             ; Load player.pos.y
    movss dword [rbp - 52], xmm0            ; ry = player.pos.y;

    jmp end_if_limit_2
    greater_than_limit_2:

    ; ry = (((int) player.pos.y >> 6 ) << 6) -0.0001
    mov rsi, qword [rbp - 16]
    movss xmm0, dword [rsi + 4]             ; Load player.pos.y
    cvttss2si eax, xmm0                     ; Convert to integer
    sar eax, 6                              ; Shift right by 6
    shl eax, 6                              ; Shift left by 6
    cvtsi2ss xmm0, eax                      ; Convert back to float
    subss xmm0, dword [rel const_0_0001]    ; Subtract 0.0001
    movss dword [rbp - 52], xmm0            ; Store to ry

    ; rx = (player.pos.y - ry) * Tan + player.pos.x
    movss xmm0, dword [rsi + 4 ]            ; Load player.pos.y
    subss xmm0, dword [rbp - 52]            ; Subtract ry
    mulss xmm0, dword [rbp - 84]            ; Multiply by Tan
    addss xmm0, [rsi]                       ; Add player.pos.x
    movss dword [rbp - 48], xmm0            ; Store to rx
    xor rsi, rsi

    ; yo = -64
    movss xmm0, dword [rel const_neg_64]    ; Load -64
    movss dword [rbp - 64], xmm0            ; Store to yo

    ; xo = -yo*Tan
    mulss xmm0, dword [rbp - 84]            ; Multiply by Tan
    xorps xmm1, xmm1                        ; Zero xmm1
    subss xmm1, xmm0                        ; Negate result
    movss dword [rbp - 60], xmm1            ; Store to xo

    jmp end_if_limit_2
    less_than_neg_limit_2:
    mov rsi, qword [rbp - 16]
    movss xmm0, dword [rsi + 4]             ; Load player.pos.y
    cvttss2si eax, xmm0                     ; Convert to integer
    sar eax, 6                              ; Shift right by 6
    shl eax, 6                              ; Shift left by 6
    add eax, 64                             ; Add 64
    cvtsi2ss xmm0, eax                      ; Convert back to float
    movss dword [rbp - 52], xmm0            ; Store to ry

    ; rx = (player.pos.y - ry) * Tan + player.pos.x
    movss xmm0, dword [rsi + 4]             ; Load player.pos.y
    subss xmm0, dword [rbp - 52]            ; Subtract ry
    mulss xmm0, dword [rbp - 84]            ; Multiply by Tan
    addss xmm0, dword [rsi]                 ; Add player.pos.x
    movss dword [rbp - 48], xmm0            ; Store to rx
    xor rsi, rsi
    ; yo = 64;
    movss xmm0, dword [rel const_64]        ; Load 64
    movss dword [rbp - 64], xmm0            ; Store to yo

    ; xo = -yo*Tan;
    mulss xmm0, dword [rbp - 84]            ; Multiply by Tan
    xorps xmm1, xmm1                        ; Zero xmm1
    subss xmm1, xmm0                        ; Negate result
    movss dword [rbp - 60], xmm1            ; Store to xo
    end_if_limit_2:

    ;
    ;   We Should be able to make the dof
    ;   loop to a function and pass distV/distH
    ;
    dof_2_loop_start:
        cmp dword [rbp - 36], 8             ; Compare dof with 8
        jge dof_2_loop_end                  ; If dof >= 8, jump to end of loop

        ; Devide 64;
        ; mx = (int) (rx) >> 6
        movss xmm0, dword [rbp - 48]        ; Load rx
        xor rax, rax
        cvttss2si eax, xmm0                 ; Convert to integer
        sar eax, 6                          ; Shift right by 6
        mov [rbp - 24], eax                 ; Store to mx

        ; my = (int) (ry) >> 6
        movss xmm0, dword [rbp - 52]        ; Load ry
        xor rax, rax
        cvttss2si eax, xmm0                 ; Convert to integer
        sar eax, 6                          ; Shift right by 6
        mov [rbp - 28], eax                 ; Store to my

        ; mp = my*MAP_X + mx
        mov eax, [rbp - 28]                 ; Load my
        imul eax, MAP_X                     ; Multiply my by MAP_X
        add eax, [rbp - 24]                 ; Add mx
        mov [rbp - 32], eax                 ; Store to mp
        movsxd rax, eax

        ; Hit wall
        ; if mp > 0 && mp < MAP_SIZE && map[mp] == 1
        cmp dword [rbp - 32], 0             ; Compare mp with 0
        jl dof_2_not_hit_wall               ; If mp <= 0, not a hit
        cmp dword [rbp - 32], MAP_SIZE      ; Compare mp with MAP_SIZE
        jge dof_2_not_hit_wall              ; If mp >= MAP_SIZE, not a hit

        lea rdi, qword [rel map]            ; We load the address to map
        mov al, byte [rdi + rax]            ; load map[mp] into al
        movzx eax, al                       ; zero-extend al into eax

        cmp eax, 1                          ; Compare map[mp] with 1
        jne dof_2_not_hit_wall              ; If map[mp] != 1, not a hit

        ; distH = distance(player.pos.x, player.pos.y, rx, ry, ra)
        mov  rsi,   qword [rbp - 16]
        movss xmm0, dword [rsi + 0 ]        ; Load player.pos.x
        movss xmm1, dword [rsi + 4 ]        ; Load player.pos.y
        movss xmm2, dword [rbp - 48]        ; Load rx
        movss xmm3, dword [rbp - 52]        ; Load ry
        movss xmm4, dword [rbp - 56]        ; Load ra
        call distance                       ; Call distance function
        movss dword [rbp - 76], xmm0        ; Store result to distH

        jmp dof_2_loop_end                  ; Break out of loop

        dof_2_not_hit_wall:
        ; rx += xo;
        movss xmm0, dword [rbp - 48]        ; Load rx
        addss xmm0, dword [rbp - 60]        ; Add xo
        movss dword [rbp - 48], xmm0        ; Store to rx

        ; ry += yo;
        movss xmm0, dword [rbp - 52]        ; Load ry
        addss xmm0, dword [rbp - 64]        ; Add yo
        movss dword [rbp - 52], xmm0        ; Store to ry

        inc dword [rbp - 36]                ; Increment dof
        jmp dof_2_loop_start                ; Continue loop

    dof_2_loop_end:

    movss xmm0, dword [rbp - 72]
    ucomiss xmm0, dword [rbp - 76]          ; Compare distV (xmm0) with distH
    jb vertical_shorter                     ; distV < distH
    movss xmm0, dword [rbp - 76]            
    movss dword [rbp - 68], xmm0            ; distT = distH
    mov   dword [rbp - 80], 0xFFFFFF        ; color
    jmp distance_set
    vertical_shorter:
    movss xmm0, dword [rbp - 72]  
    movss dword [rbp - 68], xmm0            ; distT = distV
    mov   dword [rbp - 80], 0xF7F7F7        ; color 
    distance_set:

    ; If a converted result is larger than the maximum signed doubleword integer, 
    ; the floating-point invalid exception is raised, and if this exception is masked,
    ; the indefinite integer value (80000000H) is returned.
    cvttss2si r10d, dword [rbp - 68]
    cmp r10d, 0x80000000
    je render_loop_continue
    xor rdi, rdi
    cmp r10d, edi
    je render_loop_continue

    ; Remove fish eye effect
    mov   rsi, [rbp - 16]
    movss xmm0, dword [rsi + 8 ]  ; Load player.angle
    subss xmm0, dword [rbp - 56]  ; Load ra
    call _cosf                    ; cos(angle - ra)
    mulss xmm0, dword [rbp - 68]  ; cos(angle - ra) * distT
    movss dword [rbp - 68], xmm0  ; Save in distT

    ;;   rdi  : pixel 
    ;;   esi  : r      
    ;;   edx  : color  
    ;;   xmm0 : distT  
    mov   rdi,  qword [rbp - 8 ] 
    mov   esi,  dword [rbp - 20]
    mov   edx,  dword [rbp - 80]
    movss xmm0, dword [rbp - 68] 
    call render_walls

    ; Loop again
    render_loop_continue:

    ; ra -= DEG
    movss xmm0, dword [rbp - 56]
    subss xmm0, dword[rel const_DEG]  
    movss dword [rbp - 56], xmm0

    ;;
    ;;  This code can be re-used in the begining
    ;;  (Make sure that ra is in range)
    ;;
    movss xmm0, dword [rbp - 56]        ; Load ra
    xorps xmm1, xmm1                    ; Load 0 into xmm1
    ucomiss xmm0, xmm1                  ; Compare ra with 0
    jae not_less_than_zero_2            ; Jump if ra >= 0
    addss xmm0, dword [rel const_TAU]   ; ra += 2*PI
    movss dword [rbp - 56], xmm0        ; Store ra

    not_less_than_zero_2:
    movss xmm0, dword [rbp - 56]            ; Load ra
    ucomiss xmm0, dword [rel const_TAU]     ; Compare ra with 2*PI
    jbe not_greater_than_TAU_2              ; Jump if ra <= 2*PI
    subss xmm0, dword [rel const_TAU]       ; ra -= 2*PI
    movss dword [rbp - 56], xmm0            ; Store ra
    not_greater_than_TAU_2:


    inc dword [rbp - 20]  
    jmp render_loop_start
    render_loop_end:

    mov rsp, rbp
    pop rbp
    ret


; Function: render
; This function is resonsible for all the rendering. 
;
; Parameters:
;   rdi - pixel : A pointer to the pixel data.
;
_render:
    push rbp
    mov rbp, rsp
    sub rsp, 16                     
    mov qword [rbp - 8 ],  rdi ; assign pixels to the first local variable
    mov qword [rbp - 16],  rsi ; assign player to the secound local variable

    mov rdi, qword [rbp - 8 ] ; pixels ptr
    mov rsi, qword [rbp - 16] ; player ptr
    call render_wall
    
    mov rsp, rbp
    pop rbp
    ret
