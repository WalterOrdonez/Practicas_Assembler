; multi-segment executable file template.

data segment
    ;+++++++++++++++++++++++++++++++++++++++++++++ Mensajes ++++++++++++++++++++++++++++++++++++++++++++++
    pkey                db "Adios...$"
    ;String de un salto de linea                    
    saltoLin            db 0Dh,0Ah,"$"
    ;String ingresar dirección de bmp
    msgIngDir           db "Ingrese la direcci",0A2h,"n de la imagen BMP:",0Dh,0Ah,"$"
    ;+++++++++++++++++++++++++++++++++++++++++ Mensajes de Error +++++++++++++++++++++++++++++++++++++++++
    msgErInvBMP         db "Archivo BMP invalido.",7,0Dh,0Ah,24h
    msgErAbrBMP         db "Error al abrir archivo.",7,0Dh,0Ah,24h
    ;++++++++++++++++++++++++++++ String del encabezado y menús ++++++++++++++++++++++++++++++++++++++++++ 
    stringEncabezado    db "Universidad de San Carlos de Guatemala",0Dh,0Ah
                        db "Facultad de Ingenieria",0Dh,0Ah
                        db "Escuela de Ciencias y Sistemas",0Dh,0Ah
                        db "Arquitectura de computadores Y Ensambladores 1 A",0Dh,0Ah
                        db "Segundo Semestre 2017",0Dh,0Ah
                        db "Walter Alfredo Ordo",0A4h,"ez Garc",0A1h,"a",0Dh,0Ah
                        db "2007-14802",0Dh,0Ah
                        db "CUARTA PRACTICA",0Dh,0Ah,"$"
    stringMenPri        db "---------------------------------MENU PRINCIPAL--------------------------------",0Dh,0Ah
                        db "1- Imagen BMP",0Dh,0Ah          
                        db "2- Salir",0Dh,0Ah,"$"
    stringMenOpe        db "--------------------------------MENU OPERACIONES-------------------------------",0Dh,0Ah
                        db "1- Ver Imagen",0Dh,0Ah          
                        db "2- Girar",0Dh,0Ah
                        db "3- Voltear",0Dh,0Ah
                        db "4- Escala de Grises",0Dh,0Ah
                        db "5- Brillo",0Dh,0Ah
                        db "6- Negativo",0Dh,0Ah
                        db "7- Reporte",0Dh,0Ah
                        db "8- Salir",0Dh,0Ah,"$"
    stringMenGir        db "-----------------------------------MENU GIRAR---------------------------------",0Dh,0Ah
                        db "1- 90",0xF8," Derecha",0Dh,0Ah          
                        db "2- 90",0xF8," Izquierda",0Dh,0Ah
                        db "3- 180",0xF8,0Dh,0Ah,"$"
    stringMenVol        db "----------------------------------MENU VOLTEAR--------------------------------",0Dh,0Ah
                        db "1- Horizontalmente",0Dh,0Ah          
                        db "2- Verticalmente","$"
    ;++++++++++++++++++++++++++++++++++++++++++++++++++ Variables +++++++++++++++++++++++++++++++++++++++++
    handle              dw ?
    header              dw ?
    HeadBuff            db 54 dup('H')
    palBuff             db 1024 dup('P')
    ScrLine             db 320 dup(0)

    BMPStart            db 'BM'

    PalSize             dw ?
    BMPHeight           dw ?
    BMPWidth            dw ?
    pathArchivo         db 20 dup(0)
    ruta                db "IMG.bmp",0
    temp                dw 0
    opcGrafi            db 0

ends

stack segment
    dw   128  dup(0)
ends

code segment
;++++++++++++++++++++++++++++++++++++++++++ Macros ++++++++++++++++++++++++++++++++++++++++++++++++
    ;Macro para imprimir una cadena, recibe un parametro
    imprimir macro str
        mov AH,09h                                  ;funcion para imprimir en pantalla
        mov DX,offset str   
        int 21H
    endm
    ;imprime un caracter en pantalla
    imprimirChar macro char
         mov AH,02h                                 ;funcion 2, imprimir byte en pantalla
         mov DL,char                                ;valor del parametro char a DL
         int 21h                                    ;se llama a la interrupcion
    endm
    ;Macro para pintar un pixel en pantalla
    pixel macro xPix,yPix
        push CX
        mov AH,0Ch
        mov AL,32h
        mov BH,00h
        mov DX,yPix
        mov CX,xPix
        int 10h
        pop CX
    endm
    ;escribir en archivo
    escArch macro dato,largo
        push AX                                     ;Guarda el Valor de AX en la pila
        mov AH,40h                                  ;Escritura en archivo
        mov BX,handleRep                            ;handle del archivo de reporte
        mov CX,largo                                ;cantidad de bytes a escribir
        lea DX,dato                                 ;los datos a escribir
        int 21h                                     ;llamada a la interrupcion
        pop AX                                      ;Regresar el valor de AX    
    endm
;+++++++++++++++++++++++++++++++++++++++ Procedimientos ++++++++++++++++++++++++++++++++++++++++++++
    ;Limpia la pantalla, modo texto
    limpPant proc
        mov AH, 00h
        mov AL, 3h                                  ;modo texto
        int 10h                                     ;interrupcion
        mov AH,02h                                  ;funcion posicionar cursor
        mov DX,0000h                                ;cordenadas 0,0
        int 10h                                     ;interrupcion
        mov AX,0600h                                ;ah 06(es un recorrido), al 00(pantalla completa)
        mov BH,07h                                  ;fondo negro(0), sobre blanco(7)
        mov CX,0000h                                ;es la esquina superior izquierda reglon: columna
        mov DX,184Fh                                ;es la esquina inferior derecha reglon: columna
        int 10h                                     ;interrupcion
        ret
    endp
    ;Hace una pausa en la ejecución del código,
    ;espera una pulsación de tecla para continuar
    pausa proc
        mov AH, 07h                                 ;funcion 7, obtener caracter de pantalla, sin imprimir en pantalla(echo)
        int 21h                                     ;se llama a la interrupcion
        ret
    endp
    ;espera una pulsación de tecla con ECO
    leeTecla proc
        mov AH,01h                                  ;Asigna la funcion para leer un caracter de teclado, mostrandolo en pantalla
        int 21h                                     ;llama a la interrupcion
        ret
    endp
    ;Obtiene la dirección del archivo ingresada por el usuario
    obtDirArch proc
        ;Carga de Direccion al buffer
        mov SI,00h                                  ;inicia el indice SI en 0
        leerDireccion:
            mov AX,0000h                            ;limpia el registro AX
            mov AH,01h                              ;Asigna la funcion para leer un caracter de teclado
            int 21h                                 ;llama a la interrupcion
            
            mov pathArchivo[SI],AL                  ;Guarda en el buffer en el indice SI, la tecla leida, guardada en AL
            inc SI                                  ;Se incrementa en 1 el indice SI
            
            ;Se Repite el Proceso de Carga Caracter
            ;por Caracter hasta que se Ingrese un Enter
            cmp AL,0Dh                              ;Compara si es un salto de linea
            je salirLeerDireccion                   ;Si es salto de linea sale del loop
        loop leerDireccion
        salirLeerDireccion:
        dec SI                                      ;Resta uno a SI
        mov pathArchivo[SI],0                       ;quita el salto de linea del buffer y deja un null (0) 
        ret
    endp
    ; Inicia Modo Video
    ; registro ES apunta a la memoria de video
    modVid proc
        mov AX,13h                              ;modo video 13h, 320x200x256
        int 10h
        mov AX, 0A000h                              ;apunta segmento de memoria de video, ES = A000h 
        mov ES, AX
        ret
    endp
    ;Abrir Archivo en modo lectura
    ;DS:DX: direccion del nombre del archivo
    abrirModLec proc
        mov AX,3D00h                                ;abrir un archivo AL=0 modo lectura; AH=3D abrir archivo
        int 21h
        ;CF Carry Flag en cero (operacion exitosa)
        ;con AX = manejador de archivo.
        ;CF Carry Flag en 1 (operacion fallida)
        ;con AX = codigo de error.
        ret
    endp
    ;Cerrar el archivo handle como parametro
    cerrarArch proc
        mov ah,3eh                                  ;Peticion para salir
        int 21h
        ret
    endp
    ; Este procedimiento revisa el encabezado del archivo para 
    ; asegurarse de que es un archivo tipo BMP valido
    ; y obtiene la informacion necesaria del mismo.
    leerHeader proc
        mov BX,handle                               ;handle del archivo BMP
        mov AH,3fh                                  ;lectura de archivo
        mov CX,36h                                  ;54 (36h) bytes a leer
        mov DX,offset header                        ;buffer para el encabezado
        int 21h
        jc salirLeeH                                ;Si hay error en el encabezado, salir
                                                    ;lee el byte 0Ah del header, direccion donde
        mov AX,header[0Ah]                          ;inician los datos de cada pixel 
        sub AX,36h                                  ;Restar la longitud del encabezado de la imagen
        shr AX,2                                    ;Dividir el resultado entre 4
        
        mov PalSize,AX                              ;Obtener el numero de colores del BMP
        
        mov AX,header[12h]
        mov BMPWidth,AX                             ; Guardar el ancho del BMP en BMPWidth
        
        mov AX,header[16h]    
        mov BMPHeight,AX                            ; Guardar la altura del BMP en BMPHeight

        salirLeeH:
        ret
    endp
    ; Recorre el buffer de la paleta y 
    ; envia informacion de la paleta a los registros de 
    ; video. Se envia un byte a traves del puerto 3C8h que 
    ; contiene el primer indice a modificar de la paleta  
    ; de colores. Despues, se envia informacion acerca de 
    ; los colores (RGB) a traves del puerto 3C9h
    ReadPal proc
        mov BX,handle                               ;handle del archivo BMP
        
        mov AH,3fh 
        mov CX,PalSize                              ;Numero de colores de la paleta en CX
        shl CX,2                                    ;multiplicar por 4, tamaño en bytes
        mov DX,offset palBuff                       ;Poner la paleta en el buffer
        int 21h

        
        mov SI,offset palBuff                       ;SI apunta al buffer que contiene a la paleta
        mov CX,PalSize                              ;Numero de colores a enviar en CX
        mov DX,3c8h                             
        mov AL,00h                                  ;Comenzar en el color 0
        out DX,AL
        inc DX                                      ;DX = 3C9h
        LoopLeerPal:
            ;Los colores en un archivo BMP se guardan como
            ;BGR y no como RGB
            mov AL,[SI+2]                           ;Obtener el valor para el rojo
            ;El maximo permitido es 255
            ;modo video permite valores hasta 63
            ;dividir entre 4 para un valor valido
            shr AL,2
            out DX,AL                               ;Mandar el valor del rojo por el puerto 3C9h
            mov AL,[SI+1]                           ;Obtener el valor para el verde
            shr AL,2                                ;Obtener el valor para el verde
            out DX,AL                               ;Mandar el valor del verde por el puerto
            mov AL,[si]                             ;Obtener el valor para el azul
            shr AL,2
            out dx,al                               ;Enviarlo por el puerto
            
            add SI,04h                              ;Apuntar al siguiente color
                                                    ;se avanzan cuatro, por el caracter nulo al final del color
        loop LoopLeerPal
        ret
    endp

    ;Recorre la memoria, obteniendo los datos a pintar
    ;la imagen se almacena de abajo hacia arriba
    LoadBMP proc
        mov temp,01h
        cmp opcGrafi,07h
        jne imgNormal
        mov AX,101Bh
        xor BX,BX
        mov CX,255
        int 10h
        imgNormal:
        mov BX,handle                               ;handle del archivo BMP
        mov CX,BMPHeight                            ;Numero de lineas a desplegar
        LoopImpLinea:
            push CX
            cmp opcGrafi,06h
            je  calcDI
            mov temp,CX
            calcDI:
            push temp
            mov DI,temp                             ; Hacer una copia de CX en DI
            shl temp,6                              ; Multiplicar CX por 64
            shl DI,8                                ; Multiplicar DI por 256
            ;DI apunta al primer pixel
            ;de la linea deseada en la pantalla
            add DI,temp                             ;DI = CX * 320
            lineaBuff:
            ;Copia del archivo bmp una linea
            ;en un buffer temporal (SrcLine).
            mov     AH,3fh
            mov     CX,BMPWidth
            mov     DX,offset ScrLine
            int     21h                             ;Colocar una linea de la imagen en el buffer

            ;Limpiar la bandera de 
            ;direccion par usar movsb
            cld                                     ;limpiar la bandera Dirección DF=0
            mov CX,BMPWidth
            mov SI,offset ScrLine
            cmp opcGrafi,05h
            jne loopRot
            add SI,BMPWidth
            dec SI
            loopRot:
            ; Instruccion movsb: 
            ; Mover el byte en la direccion DS:SI a la direccion 
            ; ES:DI. Despues de esto, los registros SI y DI se 
            ; incrementan o decrementan automaticamente de acuerdo
            ; con el valor que contiene la bandera de direccion
            ; (DF). Si la bandera DF esta puesta en 0, los 
            ; registros SI y DI se incrementan en 1. Si la bandera 
            ; DF esta puesta en 1, los registros SI y DI se
            ; decrementan en 1.

            ; Instruccion rep: repite cx times una operacion
            ; Copiar en la pantalla la linea que esta en el buffer
            
            cmp opcGrafi,05h
            jne voltNormal
            mov AL,[SI]
            mov ES:[DI],AL
            dec SI
            inc DI
            jmp salirLoopRot
            ;rep movsb
            voltNormal:
            movsb
            salirLoopRot:
            loop loopRot
            pop CX
            mov temp,CX
            pop CX                                 ;Regresar el valor guardado de CX
            inc temp
        loop LoopImpLinea
        ret
    endp
;+++++++++++++++++++++++++++++++++++++++ Etiquetas +++++++++++++++++++++++++++++++++++++++++++++++
    ;Menu principal de la aplicación
    menuPrin:
        call limpPant
        imprimir stringEncabezado
        imprimir saltoLin
        imprimir saltoLin
        imprimir stringMenPri
        call pausa
        cmp AL,31h                                  ;compara si es la opción uno 
        je  ingDir                                  ;salta a Ingresar la dirección de la imagen
        cmp AL,32h                                  ;compara si es la opción dos
        je  salirApp                                ;si es la opción 2 salta a la salida de la aplicación
        jmp menuPrin                                ;Si no es ninguna opcion, se mantiene en el menu

    menuOpe:
        mov opcGrafi,01h
        call limpPant
        imprimir stringMenOpe
        call pausa
        cmp AL,31h                                  ;compara si es la opción uno 
        je  mosImagen                               ;salta a Ingresar la dirección de la imagen
        cmp AL,32h                                  ;compara si es la opción uno 
        je  menGira                                 ;salta a Ingresar la dirección de la imagen
        inc opcGrafi
        cmp AL,33h                                  ;compara si es la opción uno 
        je  menVolt                                 ;salta a Ingresar la dirección de la imagen
        mov opcGrafi,07h
        cmp AL,34h                                  ;compara si es la opción uno 
        je  mosImagen                               ;salta a Ingresar la dirección de la imagen
        mov opcGrafi,08h
        cmp AL,35h                                  ;compara si es la opción uno 
        je  mosImagen                               ;salta a Ingresar la dirección de la imagen
        mov opcGrafi,09h
        cmp AL,36h                                  ;compara si es la opción uno 
        je  mosImagen                               ;salta a Ingresar la dirección de la imagen
        cmp AL,37h                                  ;compara si es la opción uno 
        je  Reporte                                 ;salta a Ingresar la dirección de la imagen
        cmp AL,38h
        je  menuPrin
        jmp menuOpe

    menGira:
        call limpPant
        imprimir stringMenGir
        call pausa
        jmp menuOpe

    menVolt:
        mov opcGrafi,05h
        call limpPant
        imprimir stringMenVol
        call pausa
        cmp AL,31h
        je  mosImagen
        inc opcGrafi
        cmp AL,32h
        je mosImagen
        cmp AL,76h
        je  menuPrin
        jmp menVolt

    ingDir:
        call limpPant
        imprimir msgIngDir
        call obtDirArch
        jmp verifPath

    verifPath:
        dec SI
        cmp pathArchivo[SI],70h
        jne ingDir
        dec SI
        cmp pathArchivo[SI],6Dh
        jne ingDir
        dec SI
        cmp pathArchivo[SI],62h
        jne ingDir
        dec SI
        cmp pathArchivo[SI],2Eh
        jne ingDir
        jmp menuOpe

    ;Mostrar imagen
    mosImagen:
        call modVid                                 ;modo video resolucion de 320x200
        lea DX,ruta                                 ;Ruta de la imagen

        ; Guardar los registros en la pila
        push AX
        push CX
        push DX
        push BX
        push SP
        push BP
        push SI
        push DI
      
        ; Abrir el archivo 
        call abrirModLec           
        ; Error? Desplegar mensaje de error y salir
        jc errorAbrirIMG
        ; Colocar el manejador del archivo en BX
        mov handle,AX
        ; Leer el encabezado de 54 bytes que contiene la 
        ; informacion del archivo BMP
        call leerHeader
        ; No es un archivo BMP valido? Desplegar mensaje de error
        ; y salir
        jc InvalidBMP
        ; Leer la paleta del BMP y colocarla en el buffer
        call ReadPal
        push es
        ; Cargar la imagen y desplegarla
        call LoadBMP
        pop es

        ; Cerrar el archivo
        mov BX,handle
        call cerrarArch
        jmp ProcDone

        errorAbrirIMG:
        imprimir msgErAbrBMP
        jmp ProcDone

        InvalidBMP:
        imprimir msgErInvBMP
        jmp ProcDone

        ProcDone:
        ; Restaurar los registros
        pop DI
        pop SI
        pop BP
        pop SP
        pop BX
        pop DX
        pop CX
        pop AX
        ; Esperar por cualquier tecla
        call pausa
        call limpPant
        jmp menuOpe

    reporte:
        call limpPant
        call pausa
        jmp menuPrin
start:
; set segment registers:
    mov AX, data
    mov DS, AX
    mov ES, AX

    jmp menuPrin
    salirApp:

    lea dx, pkey
    mov ah, 9
    int 21h        ; output string at ds:dx
    
    ; wait for any key....    
    mov ah, 1
    int 21h
    
    mov ax, 4c00h ; exit to operating system.
    int 21h    
ends

end start ; set entry point and stop the assembler.