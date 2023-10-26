%ifndef UTILITY_MAC
%define UTILITY_MAC

;; Program
%define MAC_OS

%ifdef MAC_OS
    %define SYSCALL_EXIT        0x2000001  ; syscall number for exit on MacOS
%elifdef LINUX
    %define SYSCALL_EXIT        0x3C       ; syscall number for exit on Linux
%endif

%define ERROR_EXIT_CODE         1

;; Game Constants
%define TITLE                   "Opcode Odyssey II"
%define SCREEN_WIDTH            300
%define SCREEN_HEIGHT           240
%define SCREEN_HEIGHT_HALF      SCREEN_HEIGHT / 2
%define SCREEN_SIZE             SCREEN_WIDTH * SCREEN_HEIGHT
%define SCREEN_WIDTHx4          SCREEN_WIDTH * 4

%define PIXEL_SIZE              SCREEN_WIDTH * SCREEN_HEIGHT * 4

%define DISTANCE_MAX            100000.0

%define MAP_X                   8 
%define MAP_Y                   8 
%define MAP_SIZE                MAP_X * MAP_Y
%define MAP                     1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1
%define MAP_SIZE_SCREEN_HEIGHT  MAP_SIZE * SCREEN_HEIGHT
%define FOV_F                   60.0
%define FOV                     60

;; Player
%define TURN_SPEED              0.05
%define MOVMENT_SPEED           3.00
%define PLAYER_POS_X            150.0
%define PLAYER_POS_Y            100.0
%define PLAYER_ANGLE            5.0
%define PLAYER_DELTA_X          3.16339e-5
%define PLAYER_DELTA_Y          5.0

;; Math
%define PI                      3.141592653
%define TAU                     6.283185307
%define DEG                     0.017453292
%define NEG                     -1.0
%define ONE                     1.0

;; SDL Constants
%define SDL_INIT_VIDEO              0x00000020
%define SDL_PIXELFORMAT_ABGR8888    376840196
%define SDL_RENDERER_PRESENTVSYNC   0x00000004
%define SDL_TEXTUREACCESS_STREAMING 0x00000001
%define SDL_FLIP_VERTICAL           0x00000002
%define SDL_QUIT                    0x100
%define SDL_KEYUP                   0x301
%define SDL_KEYDOWN                 0x300
%define SDL_SCANCODE_A              0x4
%define SDL_SCANCODE_D              0x7
%define SDL_SCANCODE_S              0x16
%define SDL_SCANCODE_W              0x1A
%define SDL_SCANCODE_RIGHT          0x4F
%define SDL_SCANCODE_LEFT           0x50
%define SDL_SCANCODE_DOWN           0x51
%define SDL_SCANCODE_UP             0x52

%endif