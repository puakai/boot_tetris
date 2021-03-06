[BITS 16]
[org 0x7C00]

start:
    cli
    ;create stack
    xor eax,eax
    mov ss,ax           ;stack 0
    ;data sp starts at 0xffff
    sti
    
    mov al,0x0D         ;320x200 16 color graphics (EGA,VGA)
    int 0x10
    
    ;mov ah,0x01
    inc ah
    mov ch,0x20       ;disable cursor
    int 0x10
    
    mov [0xf000],dword(0x02)
    call newblock
    mov sp,0xff2f
    
.draw
    mov bx,0xffff           ;stack index
    mov dx,0x000a           ;10y
    .loopy
        mov cx,0x0008       ;8x
        ;mov cl,0x08
        .loopx
            ;mov bx,0xffff
            sub bl,0x02
            mov ax,[bx]
            push bx
            
            mov ah,0x0c ;draw pixel
            ;and al,0x0f
            xor bh,bh
            int 0x10
            
            pop bx
            dec cl
            test cl,cl
            jnz .loopx
        dec dl
        test dl,dl
        jnz .loopy
    
    ;active block
    call setactbcd ;dx will be overridden anyway
    .loopcb
        sub bl,0x02
        mov ax,[bx]
        
        push cx
        push bx
        mov cx,ax
        shr cl,0x04
        mov dx,ax
        and dl,0x0f
        
        mov ax,0x0c0f
        xor bh,bh
        int 0x10
        
        pop bx
        pop cx
        dec cl
        test cl,cl
        jnz .loopcb
    
.waitinput
    mov word[0xfe10],0x00   ;down command?
    
    xor ah,ah
    int 0x16
    
    cmp al,0x73 ;s
    je .down
    cmp al,0x61 ;a
    je .left
    cmp al,0x64 ;d
    je .right
    jmp .waitinput

.down
    mov word[0xfe10], 0x10
    call setactbcd
    .loopdown
        call movsim1
        inc al
        call movsim2
        jnz .loopdown
    jmp .check
.left
    call setactbcd
    .loopleft
        call movsim1
        sub al,0x10
        call movsim2
        jnz .loopleft
    jmp .check
.right
    call setactbcd
    .looprght
        call movsim1
        add al,0x10
        ;mov [bx],ax
        call movsim2
        jnz .looprght
    jmp .check

.hit
    mov dx,word[0xfe10]
    test dx,dx
    jz .waitinput
    ;apply block
    call setactbcd
    .loophitapply
        call movsim1 ;id in al
        push bx
        
        mov bx,0xff4d
        push ax
        shr al,0x04
        shl al,0x01
        add bl,al
        pop ax
        shl al,0x04
        add bl,al
        mov dx,[0xff45]
        
        mov word[bx],dx
        pop bx
        dec cl
        test cl,cl
        jnz .loophitapply
    
    ;clear
    mov bx,0xfffd   ;bottom line left
    mov dl,0x0a
    .loopcleary     ;for top to bottom
        xor cl,cl   ;has empty block?
        mov dh,0x08
        .loopclearx1
            mov ax,[bx]
            sub bl,0x02
            test ax,ax
            jnz .lchasblock
            inc cl
            .lchasblock
            dec dh
            test dh,dh
            jnz .loopclearx1
            
        test cl,cl   ;is there an empty block?
        jnz .noclear
        push dx
        push bx
        ;bl is next line left
        ;dl is current line y
        .loopdecliney
            sub bl,0x10     ;front of this line
            mov dh,0x08
            .loopdeclinex
                add bl,0x02 ;moving back
                mov ax,[bx] ;take from last line
                ;xor ax,ax
                add bl,0x10
                mov [bx],ax ;put to this line
                sub bl,0x10 ;inc 1 previous line
                dec dh
                test dh,dh
                jnz .loopdeclinex
            sub bl,0x10
            dec dl
            cmp dl,0x01
            jne .loopdecliney
        pop bx
        pop dx
        .noclear
        
        dec dl
        cmp dl,0x01
        jne .loopcleary
    
    ;newblock
    call newblock
    jmp .draw

.apply
    mov bx,0xff3f
    mov dx,0xff4f
    mov cl,0x04
    .loopapply
        call movsim1
        call movsim2
        jnz .loopapply
    jmp .draw

.check
    mov [0xfe00],sp
    mov bx,0xffff           ;stack index
    mov dl,0x0a           ;10y
    .loopcy
        mov cl,0x08       ;8x
        .loopcx
            sub bl,0x02
            mov ax,[bx]
            ;test ax,ax
            ;jz .emptycheck
            push cx
            push dx
            push bx
            
            shl cl,0x04
            or cl,dl
            mov bx,0xff3f
            mov dl,0x04
            .loopCol
                sub bl,0x02
                test ax,ax
                jz .emptycheck
                cmp word[bx],cx
                je .colld
                .emptycheck
                    ;outside bounds?
                    push dx
                    mov dx,[bx]
                    push dx
                    shr dl,0x04
                    ;and dl,0x0f
                    test dl,dl
                    jz .colld
                    cmp dl,0x09
                    je .colld
                    pop dx
                    and dl,0x0f
                    cmp dl,0x0b
                    je .colld
                    pop dx
                    dec dl
                    test dl,dl
                    jnz .loopCol
            pop bx
            pop dx
            pop cx
            dec cl
            test cl,cl
            jnz .loopcx
        dec dl
        test dl,dl
        jnz .loopcy
        
    ;mov sp,[0xfe00]
    jmp .apply
    .colld
        mov sp,[0xfe00]
        jmp .hit

newblock:
    mov [0xfe00],sp
    mov sp,0xff4f
    push dword 0x00410042           ;current block location 0xXY
    ;push 0x42
    push dword 0x00430053
    ;push 0x53
    mov ax,[0xf000]
    push ax
    inc ax
    cmp ax,0x07
    jl .dontrevcol
    mov al,0x02
    .dontrevcol
    mov [0xf000],ax
    mov sp,[0xfe00]
    retn

coord2dx:
    mov bx,0xff4d
    push ax
    shr al,0x04
    shl al,0x01
    add bl,al
    pop ax
    shl al,0x04
    add bl,al
    mov dx,[0xff45]
    retn

movsim1:
    sub bl,0x02
    sub dl,0x02
    mov ax,[bx]
    retn
movsim2:
    push bx
    mov bx,dx
    mov [bx],ax
    pop bx
    dec cl
    test cl,cl
    retn

setactbcd:
    mov bx,0xff4f
    mov dx,0xff3f
    mov cl,0x04
    retn

TIMES 510 - ($ - $$) db 0
DW 0xAA55