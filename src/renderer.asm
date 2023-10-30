%include "data/settings.asm"

; Export render
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

;; Function: render_walls
;; Renders a wall.
;;
;; Parameters:
;;   rdi  - pixel : A pointer to the pixel data
;;   esi  - r     : 
;;   edx  - color : 
;;   xmm0 - distT : 
;;
render_walls:
    in u64::pixel_ptr
    in u32::r
    in u32::color
    in f32::distT

    ; Calculating line height
    ; (MAP_SIZE * SCREEN_HEIGHT) / distT
    ; We should be able to load MAP_SIZE_SCREEN_HEIGHT
    ; direct to XMM and remove these three...
    mov eax, MAP_SIZE_SCREEN_HEIGHT ;   MAP_SIZE * SCREEN_HEIGHT          
    cvtsi2ss xmm0, eax    

    movss xmm1, §distT              ; loading distT into xmm1
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
    mov  r13d, §r    ; Store r*5 
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
            mov r8,  §pixel_ptr             ; load pixel pointer
            mov r9d, §color                 ; color
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

;; Function: distance
;; Calculates the distance between two points (x0, y0) and (x1, y1) with a given angle.
;;
;; Parameters:
;;   xmm0 - x0    : The x-coordinate of the first point.
;;   xmm1 - y0    : The y-coordinate of the first point.
;;   xmm2 - x1    : The x-coordinate of the second point.
;;   xmm3 - y1    : The y-coordinate of the second point.
;;   xmm4 - angle : The angle for the calculation.
;;
;; Returns:
;;   The result of the calculation is returned in xmm0.
;;
distance:
    in f32::x0
    in f32::y0
    in f32::x1
    in f32::x2
    in f32::angle

    f32::diff_x
    f32::diff_y

    subss xmm2, xmm0                ; x1 - x0
    subss xmm3, xmm1                ; y1 - y0
    movss §diff_x, xmm2             ; diff_x
    movss §diff_y, xmm3             ; diff_y

    movss xmm0, §angle              ; copy angle to xmm0
    call _cosf                      ; cos(angle), result in xmm0
    mulss xmm0, §diff_x             ; cos(angle) * (x1 - x0)
    movss §diff_x, xmm0             ; store result in diff_x 

    movss xmm0, §angle              ; copy angle to xmm0
    call _sinf                      ; sin(angle), result in xmm0
    mulss xmm0, §diff_y             ; sin(angle) * (y1 - y0)
    movss xmm1, §diff_x
    subss xmm1, xmm0                ; cos(angle)*(x1-x0) - sin(angle)*(y1-y0), result in xmm2
    movss xmm0, xmm1                ; move result to xmm0 for return
    
    %ifdef DEBUG
    cvttss2si r10d, xmm0 
    int 3 
    %endif

    
    mov rsp, rbp
    pop rbp
    ret

;; Function: render_wall
;; This function is resonsible for rendering the walls
;; This is also the function that calculate the rays.
;;
;; Parameters:
;;   rdi - pixel  : A pointer to the pixel data.
;;   rsi - player : A pointer to the player data.
;;
render_wall:
    in u64::pixel_ptr
    in u64::player_ptr

    i32::r
    i32::mx
    i32::my
    i32::mp
    i32::dof
    u32::color

    f32::vx
    f32::vy
    f32::rx
    f32::ry
    f32::ra
    f32::xo
    f32::yo
    f32::distT
    f32::distH
    f32::distV
    f32::tan

    ; Initizilise ra
    mov rsi, §player_ptr
    movss xmm0, dword [rsi + 8]             ; Load player angle 
    movss xmm1, dword [rel const_DEG] 
    mulss xmm1, dword [rel const_FOV_f]     ; DEG*FOV
    mulss xmm1, dword [rel const_half]      ; (DEG*FOV) / 2
    addss xmm0, xmm1                        ; player.angle + (DEG*FOV) / 2
    movss §ra, xmm0                         ; ra = player.angle + (DEG*FOV) / 2

    ; Make sure that ra is in range
    movss xmm0, §ra                         ; Load ra
    xorps xmm1, xmm1                        ; Load 0 into xmm1
    ucomiss xmm0, xmm1                      ; Compare ra with 0
    jae not_less_than_zero                  ; Jump if ra >= 0
    addss xmm0, dword [rel const_TAU]       ; ra += 2*PI
    movss §ra, xmm0                         ; Store ra

    not_less_than_zero:
    movss xmm0, §ra                         ; Load ra
    ucomiss xmm0, dword [rel const_TAU]     ; Compare ra with 2*PI
    jbe not_greater_than_TAU                ; Jump if ra <= 2*PI
    subss xmm0, dword [rel const_TAU]       ; ra -= 2*PI
    movss §ra, xmm0                         ; Store ra
    not_greater_than_TAU:

    render_loop_start:                      ; Loop (r < FOV)
    mov ecx, [rel const_FOV]
    cmp §r, ecx                             ; Compare r with FOV
    jge render_loop_end                     ; If r >= FOV, exit loop

    ; Init
    mov §dof, 0                             ; dof = 0

    movss xmm0, [rel const_DISTANCE_MAX]
    movss §distV, xmm0                      ; distV = 100000

    movss xmm0, §ra                         ; Store tan(ra)
    call _tanf
    movss §tan, xmm0

    movss xmm0, §ra                             ; ra
    call _cosf                                  ; result stored in xmm0
    ucomiss xmm0, dword [rel const_0_0001]      ; Check if cos(ra) > 0.001
    ja greater_than_limit                       ; Jump if cos(ra) > 0.001
    ucomiss xmm0, dword [rel const_neg_0_0001]  ; Check if cos(ra) < -0.001
    jb less_than_neg_limit                      ; Jump if cos(ra) < -0.001
   
    ; ---- Else ------
    mov rsi, §player_ptr
    movss xmm0, dword [rsi]                 ; Load player.pos.x
    movss §rx, xmm0                         ; rx = player.pos.x;
    movss xmm0, dword [rsi + 4]             ; Load player.pos.y
    movss §ry, xmm0                         ; ry = player.pos.y;
    mov §dof, 8                             ; dof = 8

    jmp end_if_limit
    greater_than_limit:

    ; int 3
    ; rx = (((int) player.pos.x >> 6) << 6) + 64;
    mov rsi, §player_ptr
    movss xmm0, dword [rsi]                 ; Load player.pos.x
    cvttss2si eax, xmm0                     ; Convert to integer
    sar eax, 6                              ; Shift right by 6
    shl eax, 6                              ; Shift left by 6
    add eax, 64                             ; Add 64
    cvtsi2ss xmm0, eax                      ; Convert back to float
    movss §rx, xmm0                         ; Store to rx

    ; ry = (player.pos.x - rx) * Tan + player.pos.y;
    movss xmm0, dword [rsi]                 ; Load player.pos.x
    subss xmm0, §rx                         ; Subtract rx
    mulss xmm0, §tan                        ; Multiply by Tan
    addss xmm0, dword [rsi + 4]             ; Add player.pos.y
    movss §ry, xmm0                         ; Store to ry
    xor rsi, rsi

    ; xo = 64;
    movss xmm0, dword [rel const_64]        ; Load 64
    movss §xo, xmm0                         ; Store to xo

    ; yo = -xo * Tan;
    mulss xmm0, §tan                        ; Multiply by Tan
    xorps xmm1, xmm1                        ; Zero xmm1
    subss xmm1, xmm0                        ; Negate result
    movss §yo, xmm1                         ; Store to yo

    jmp end_if_limit

    less_than_neg_limit:
    ; rx = (((int) player.pos.x >> 6) << 6) - 0.0001;
    mov rsi, §player_ptr
    movss xmm0, [rsi]                       ; Load player.pos.x
    cvttss2si eax, xmm0                     ; Convert to integer
    sar eax, 6                              ; Shift right by 6
    shl eax, 6                              ; Shift left by 6
    cvtsi2ss xmm0, eax                      ; Convert back to float
    subss xmm0, dword [rel const_0_0001]    ; Subtract 0.0001
    movss §rx, xmm0                         ; Store to rx

    ; ry = (player.pos.x - rx) * Tan + player.pos.y;
    movss xmm0, dword [rsi]                 ; Load player.pos.x
    subss xmm0, §rx                         ; Subtract rx
    mulss xmm0, §tan                        ; Multiply by Tan
    addss xmm0, dword [rsi + 4]             ; Add player.pos.y
    movss §ry, xmm0                         ; Store to ry

    ; xo = -64;
    movss xmm0, dword [rel const_neg_64]    ; Load 64
    movss §xo, xmm0                         ; Store to xo

    ; yo = -xo * Tan;
    mulss xmm0, §tan                        ; Multiply by Tan
    xorps xmm1, xmm1                        ; Zero xmm1
    subss xmm1, xmm0                        ; Negate result
    movss §yo, xmm1                         ; Store to yo

    end_if_limit:

    dof_loop_start:
        ; If dof >= 8, jump to end of loop
        cmp §dof, 8 
        jge dof_loop_end       

        ; Devide 64;
        ; mx = (int) (rx) >> 6
        movss xmm0, §rx                     ; Load rx
        cvttss2si eax, xmm0                 ; Convert to integer
        sar eax, 6                          ; Shift right by 6
        mov §mx, eax                        ; Store to mx

        ; my = (int) (ry) >> 6
        movss xmm0, §ry                     ; Load ry
        cvttss2si eax, xmm0                 ; Convert to integer
        sar eax, 6                          ; Shift right by 6
        mov §my, eax                        ; Store to my

        ; mp = my*MAP_X + mx
        mov eax, §my                        ; Load my
        imul eax, MAP_X                     ; Multiply my by MAP_X
        add eax, §mx                        ; Add mx
        mov §mp, eax                        ; Store to mp
        movsxd rax, eax

        ; Hit wall
        ; if mp > 0 && mp < MAP_SIZE && map[mp] == 1
        cmp §mp, 0                          ; Compare mp with 0
        jl not_hit_wall                     ; If mp <= 0, not a hit
        cmp §mp, MAP_SIZE                   ; Compare mp with MAP_SIZE
        jge not_hit_wall                    ; If mp >= MAP_SIZE, not a hit

        lea rdi, qword [rel map]            ; We load the address to map
        mov al, byte [rdi + rax]            ; load map[mp] into al
        movzx eax, al                       ; zero-extend al into eax

        cmp eax, 1                          ; Compare map[mp] with 1
        jne not_hit_wall                    ; If map[mp] != 1, not a hit

        ; distV = distance(player.pos.x, player.pos.y, rx, ry, ra)
        mov   rsi, §player_ptr
        movss xmm0, dword [rsi]             ; Load player.pos.x
        movss xmm1, dword [rsi + 4]         ; Load player.pos.y
        movss xmm2, §rx                     ; Load rx
        movss xmm3, §ry                     ; Load ry
        movss xmm4, §ra                     ; Load ra
        call distance                       ; Call distance function
        movss §distV, xmm0                  ; Store result to distV
        
        jmp dof_loop_end                    ; Break out of loop

        not_hit_wall:
        ; rx += xo;
        movss xmm0, §rx                     ; Load rx
        addss xmm0, §xo                     ; Add xo
        movss §rx, xmm0                     ; Store to rx

        ; ry += yo;
        movss xmm0, §ry                     ; Load ry
        addss xmm0, §yo                     ; Add yo
        movss §ry, xmm0                     ; Store to ry

        inc §dof                            ; Increment dof
        jmp dof_loop_start                  ; Continue loop

    dof_loop_end:

    movss xmm0, §rx 
    movss §vx, xmm0                         ; vx = rx
    movss xmm0, §ry 
    movss §vy, xmm0                         ; vy = ry
    mov §dof, 0                             ; dof = 0

    movss xmm0, [rel const_DISTANCE_MAX]
    movss §distH, xmm0                      ; distH = 100000

    ; movss xmm0, dword [rel const_ONE]
    ; divss xmm0, §tan                
    ; movss §tan, xmm0                      ; div by zero
    xorps xmm7, xmm7
    rcpss xmm7, §tan
    movss §tan, xmm7
                                                
    movss xmm0, §ra                             ; if sin(ra) > 0.001
    call _sinf                                  ; result stored in xmm0
    ucomiss xmm0, dword [rel const_0_0001]      ; Check if sin(ra) > 0.001
    ja greater_than_limit_2                     ; Jump if sin(ra) > 0.001
    ucomiss xmm0, dword [rel const_neg_0_0001]  ; Check if sin(ra) < -0.001
    jb less_than_neg_limit_2                    ; Jump if sin(ra) < -0.001
    ; ---- Else ------
   
    mov rsi, §player_ptr
    movss xmm0, dword [rsi + 0]                 ; Load player.pos.x
    movss §rx, xmm0                             ; rx = player.pos.x;
    movss xmm0, dword [rsi + 4]                 ; Load player.pos.y
    movss §ry, xmm0                             ; ry = player.pos.y;

    jmp end_if_limit_2
    greater_than_limit_2:

    ; ry = (((int) player.pos.y >> 6 ) << 6) -0.0001
    mov rsi, §player_ptr
    movss xmm0, dword [rsi + 4]                 ; Load player.pos.y
    cvttss2si eax, xmm0                         ; Convert to integer
    sar eax, 6                                  ; Shift right by 6
    shl eax, 6                                  ; Shift left by 6
    cvtsi2ss xmm0, eax                          ; Convert back to float
    subss xmm0, dword [rel const_0_0001]        ; Subtract 0.0001
    movss §ry, xmm0                             ; Store to ry

    ; rx = (player.pos.y - ry) * Tan + player.pos.x
    movss xmm0, dword [rsi + 4 ]                ; Load player.pos.y
    subss xmm0, §ry                             ; Subtract ry
    mulss xmm0, §tan                            ; Multiply by Tan
    addss xmm0, [rsi]                           ; Add player.pos.x
    movss §rx, xmm0                             ; Store to rx
    xor rsi, rsi

    ; yo = -64
    movss xmm0, dword [rel const_neg_64]        ; Load -64
    movss §yo, xmm0                             ; Store to yo

    ; xo = -yo*Tan
    mulss xmm0, §tan                            ; Multiply by Tan
    xorps xmm1, xmm1                            ; Zero xmm1
    subss xmm1, xmm0                            ; Negate result
    movss §xo, xmm1                             ; Store to xo

    jmp end_if_limit_2
    less_than_neg_limit_2:
    mov rsi, §player_ptr
    movss xmm0, dword [rsi + 4]                 ; Load player.pos.y
    cvttss2si eax, xmm0                         ; Convert to integer
    sar eax, 6                                  ; Shift right by 6
    shl eax, 6                                  ; Shift left by 6
    add eax, 64                                 ; Add 64
    cvtsi2ss xmm0, eax                          ; Convert back to float
    movss §ry, xmm0                             ; Store to ry

    ; rx = (player.pos.y - ry) * Tan + player.pos.x
    movss xmm0, dword [rsi + 4]                 ; Load player.pos.y
    subss xmm0, §ry                             ; Subtract ry
    mulss xmm0, §tan                            ; Multiply by Tan
    addss xmm0, dword [rsi]                     ; Add player.pos.x
    movss §rx, xmm0                             ; Store to rx
    xor rsi, rsi
    ; yo = 64;
    movss xmm0, dword [rel const_64]            ; Load 64
    movss §yo, xmm0                             ; Store to yo

    ; xo = -yo*Tan;
    mulss xmm0, §tan                            ; Multiply by Tan
    xorps xmm1, xmm1                            ; Zero xmm1
    subss xmm1, xmm0                            ; Negate result
    movss §xo, xmm1                             ; Store to xo
    end_if_limit_2:

    ;
    ;   We Should be able to make the dof
    ;   loop to a function and pass distV/distH
    ;
    dof_2_loop_start:
        cmp §dof, 8                             ; Compare dof with 8
        jge dof_2_loop_end                      ; If dof >= 8, jump to end of loop

        ; Devide 64;
        ; mx = (int) (rx) >> 6
        movss xmm0, §rx                         ; Load rx
        xor rax, rax
        cvttss2si eax, xmm0                     ; Convert to integer
        sar eax, 6                              ; Shift right by 6
        mov §mx, eax                            ; Store to mx

        ; my = (int) (ry) >> 6
        movss xmm0, §ry                         ; Load ry
        xor rax, rax
        cvttss2si eax, xmm0                     ; Convert to integer
        sar eax, 6                              ; Shift right by 6
        mov §my, eax                            ; Store to my

        ; mp = my*MAP_X + mx
        mov eax, §my                            ; Load my
        imul eax, MAP_X                         ; Multiply my by MAP_X
        add eax, §mx                            ; Add mx
        mov [rbp - 32], eax                     ; Store to mp
        movsxd rax, eax

        ; Hit wall
        ; if mp > 0 && mp < MAP_SIZE && map[mp] == 1
        cmp §mp, 0                              ; Compare mp with 0
        jl dof_2_not_hit_wall                   ; If mp <= 0, not a hit
        cmp §mp, MAP_SIZE                       ; Compare mp with MAP_SIZE
        jge dof_2_not_hit_wall                  ; If mp >= MAP_SIZE, not a hit

        lea rdi, qword [rel map]                ; We load the address to map
        mov al, byte [rdi + rax]                ; load map[mp] into al
        movzx eax, al                           ; zero-extend al into eax

        cmp eax, 1                              ; Compare map[mp] with 1
        jne dof_2_not_hit_wall                  ; If map[mp] != 1, not a hit

        ; distH = distance(player.pos.x, player.pos.y, rx, ry, ra)
        mov  rsi, §player_ptr
        movss xmm0, dword [rsi + 0 ]            ; Load player.pos.x
        movss xmm1, dword [rsi + 4 ]            ; Load player.pos.y
        movss xmm2, §rx                         ; Load rx
        movss xmm3, §ry                         ; Load ry
        movss xmm4, §ra                         ; Load ra
        call distance                           ; Call distance function
        movss §distH, xmm0                      ; Store result to distH

        jmp dof_2_loop_end                      ; Break out of loop

        dof_2_not_hit_wall:
        ; rx += xo;
        movss xmm0, §rx                         ; Load rx
        addss xmm0, §xo                         ; Add xo
        movss §rx, xmm0                         ; Store to rx

        ; ry += yo;
        movss xmm0, §ry                         ; Load ry
        addss xmm0, §yo                         ; Add yo
        movss §ry, xmm0                         ; Store to ry

        inc §dof                                ; Increment dof
        jmp dof_2_loop_start                    ; Continue loop

    dof_2_loop_end:

    movss xmm0, §distV
    ucomiss xmm0, §distH                        ; Compare distV (xmm0) with distH
    jb vertical_shorter                         ; distV < distH
    movss xmm0, §distH            
    movss §distT, xmm0                          ; distT = distH
    mov   §color, 0xFFFFFF                      ; color
    jmp distance_set
    vertical_shorter:
    movss xmm0, §distV  
    movss §distT, xmm0                          ; distT = distV
    mov   §color, 0xF7F7F7                      ; color 
    distance_set:

    ; If a converted result is larger than the maximum signed doubleword integer, 
    ; the floating-point invalid exception is raised, and if this exception is masked,
    ; the indefinite integer value (80000000H) is returned.
    cvttss2si r10d, §distT
    cmp r10d, 0x80000000
    je render_loop_continue
    xor rdi, rdi
    cmp r10d, edi
    je render_loop_continue

    ; Remove fish eye effect
    mov   rsi, §player_ptr
    movss xmm0, dword [rsi + 8 ]                ; Load player.angle
    subss xmm0, §ra                             ; Load ra
    call _cosf                                  ; cos(angle - ra)
    mulss xmm0, §distT                          ; cos(angle - ra) * distT
    movss §distT, xmm0                          ; Save in distT

    ;;   rdi  : pixel 
    ;;   esi  : r      
    ;;   edx  : color  
    ;;   xmm0 : distT  
    mov   rdi,  §pixel_ptr 
    mov   esi,  §r
    mov   edx,  §color
    movss xmm0, §distT 
    call render_walls

    ; Loop again
    render_loop_continue:

    ; ra -= DEG
    movss xmm0, §ra
    subss xmm0, dword[rel const_DEG]  
    movss §ra, xmm0

    ;;
    ;;  This code can be re-used in the begining
    ;;  (Make sure that ra is in range)
    ;;
    movss xmm0, §ra                             ; Load ra
    xorps xmm1, xmm1                            ; Load 0 into xmm1
    ucomiss xmm0, xmm1                          ; Compare ra with 0
    jae not_less_than_zero_2                    ; Jump if ra >= 0
    addss xmm0, dword [rel const_TAU]           ; ra += 2*PI
    movss §ra, xmm0                             ; Store ra

    not_less_than_zero_2:
    movss xmm0, §ra                             ; Load ra
    ucomiss xmm0, dword [rel const_TAU]         ; Compare ra with 2*PI
    jbe not_greater_than_TAU_2                  ; Jump if ra <= 2*PI
    subss xmm0, dword [rel const_TAU]           ; ra -= 2*PI
    movss §ra, xmm0                             ; Store ra
    not_greater_than_TAU_2:


    inc §r  
    jmp render_loop_start
    render_loop_end:

    mov rsp, rbp
    pop rbp
    ret


;; Function: render
;; This function is resonsible for all the rendering. 
;;
;; Parameters:
;;   rdi - pixel : A pointer to the pixel data.
;;
_render:
    in u64::pixel_ptr             
    in u64::player_ptr             

    mov rdi, §pixel_ptr
    mov rsi, §player_ptr
    call render_wall
    
    mov rsp, rbp
    pop rbp
    ret
