;-----------------------------------------------------------------------
;
; dir2car:BANK - xEMU - emulation xBIOS for car
; (c) 2025 GienekP
;
;-----------------------------------------------------------------------
TMP     = $2C
TMPBUF  = $0700
XEMUAD	= $0800
;-----------------------------------------------------------------------
CASINI  = $02
BOOTQ   = $09
DOSINI  = $0C
DOSVEC  = $0A
CRITIC  = $42
RAMTOP  = $6A
DMACTLS = $022F
COLDST  = $0244
RUNAD   = $02E0
INITAD 	= $02E2
MEMTOP  = $02E5
MEMLO   = $02E7
BASICF  = $03F8
GINTLK  = $03FA
TRIG3   = $D013
COLBAK  = $D01A
CONSOL  = $D01F
PORTB   = $D301
DMACTL  = $D400
VCOUNT  = $D40B
RESETCD = $E477
EDOPN   = $EF94
EOUTCH  = $F2B0
;-----------------------------------------------------------------------
; CARTRIDGE BANK FIRST & LAST

		OPT h-f+
		
;-----------------------------------------------------------------------
; Files table

		ORG $A000
;-----------------------------------------------------------------------
; NOF - number of files
NOF		dta 0
;-----------------------------------------------------------------------
; DCart miniwindow - not use in this solution

		ORG $B500
;-----------------------------------------------------------------------
		sei
		sta $D500
		jmp RESETCD
;-----------------------------------------------------------------------
		ORG $B5FB
		dta 'DCart'
		ORG $B600
;-----------------------------------------------------------------------
		dta $FF
;-----------------------------------------------------------------------
; xEMU Vectors
		ORG $B800
;--------------------------------
XEMU
.local xEMUloc,XEMUAD
.def :LOAD_AUTORUN = xEMU_LOAD_AUTORUN
.def :FSTRUCT= FILEINFO
;--------------------------------
xEMU_HEADER             dta $78,$42
xEMU_VERSION            dta $43
xEMU_RENAME_ENTRY       jmp HOLD
xEMU_LOAD_FILE          jmp LOAD_FILE
xEMU_OPEN_FILE          jmp OPEN_FILE
xEMU_LOAD_DATA          jmp LOAD_DATA
xEMU_WRITE_DATA         jmp RETURN
xEMU_OPEN_CURRENT_DIR   jmp HOLD
xEMU_GET_BYTE           jmp GET_BYTE
xEMU_PUT_BYTE           jmp RETURN
xEMU_FLUSH_BUFFER       jmp RETURN
xEMU_SET_LENGTH         jmp SET_LENGTH
xEMU_SET_INIAD          jmp SET_INIAD
xEMU_SET_FILE_OFFSET    jmp FILE_OFFSET
xEMU_SET_RUNAD          jmp SET_RUNAD
xEMU_SET_DEFAULT_DEVICE jmp RETURN
xEMU_OPEN_DIR           jmp HOLD
xEMU_LOAD_BINARY_FILE   jmp HOLD
xEMU_OPEN_DEFAULT_DIR   jmp HOLD
xEMU_SET_DEVICE         jmp RETURN
xEMU_RELOCATE_BUFFER    jmp HOLD
xEMU_GET_ENTRY          jmp HOLD
xEMU_OPEN_DEFAULT_FILE  jmp HOLD
xEMU_READ_SECTOR        jmp HOLD
xEMU_FIND_ENTRY         jmp HOLD
xEMU_SET_BUFFER_SIZE    jmp HOLD
xEMU_JMPEMPTY1			jmp RETURN
xEMU_JMPEMPTY2			jmp RETURN
xEMU_JMPEMPTY3			jmp RETURN
xEMU_RESET				jmp RESTART
;--------------------------------
xEMU_LOAD_AUTORUN
		lda #$22
		sta DMACTLS
		jsr WAITVB
		jsr CARTOFF
		ldy <AUTOFN 
		ldx >AUTOFN 
		jsr xEMU_LOAD_FILE
;--------------------------------
RESTART	sei
		sta $D500
		jmp RESETCD
;--------------------------------
; HOLD DEBUG - I don't know what to do :/
HOLD	sec
@		bcs	@-
RETURN	rts
;--------------------------------
WAITVB	lda #$77
@		cmp VCOUNT
		bne @-
		rts
;--------------------------------
BUSYVB	rts
;--------------------------------
; Turn On/Off bank need it, if OS work
CTRIGTG	lda TRIG3
		sta GINTLK
		rts
;--------------------------------
UPCRIT	inc CRITIC
		rts
;--------------------------------
DWCRIT	jsr CTRIGTG
		dec	CRITIC
		rts
;--------------------------------
CARTON	jsr UPCRIT
		jsr BUSYVB
		sta $D500
		jmp DWCRIT
;--------------------------------
CARTOFF	jsr UPCRIT
		jsr BUSYVB
		sta $D580
		jmp DWCRIT
;--------------------------------
LOAD_FILE
		jsr OPEN_FILE
		
		ldy <RETURN
		ldx >RETURN
		jsr SET_RUNAD
		lda FSTATUS
		beq LFEXIT

		jsr GET_BYTE
		cmp #$FF
		bne LFEXIT
		jsr GET_BYTE
		cmp #$FF
		bne LFEXIT
		
XEXNEXT	ldy <RETURN
		ldx >RETURN
		jsr SET_INIAD
		
INGFFFF	lda FSTATUS
		beq LFEXIT
		
		jsr GET_BYTE
		sta BLKSTA
		jsr GET_BYTE
		sta BLKSTA+1
		
		lda BLKSTA
		cmp #$FF
		bne XEXBLK
		lda BLKSTA+1
		cmp #$FF
		beq INGFFFF
		
XEXBLK	jsr GET_BYTE
		sta BLKEND
		jsr GET_BYTE
		sta BLKEND+1
		
		INW	BLKEND
		SBW BLKEND BLKSTA BLKLEN
		
		ldy BLKLEN
		ldx BLKLEN+1
		jsr SET_LENGTH	
		
		ldy BLKSTA
		ldx BLKSTA+1
		jsr LOAD_DATA

		lda #>(XEXNEXT-1)
		pha
		lda #<(XEXNEXT-1)
		pha
		
		jmp (INITAD)
LFEXIT	jmp (RUNAD)
;--------------------------------
OPEN_FILE
		lda TMP
		pha
		lda TMP+1
		pha
		
		sty TMP
		stx TMP+1
		ldy #$00		; copy file name [danger, name covered by A000-BFFF]
@		lda (TMP),y
		sta AUTOFN,y
		iny
		cpy #$0B
		bne @-
		pla
		sta TMP+1
		pla
		sta TMP
		
		ldy #<AUTOFN
		ldx #>AUTOFN
		
		jsr WAITVB
		jsr CARTON
		jsr CAR_OPEN_FILE
		jsr CARTOFF
		
		lda #$00
		sta PPOS
		sta PPOS+1
		sta PPOS+2
		sta BLKLEN
		sta BLKLEN+1
		lda FSECTOR
		sta PSECTOR
		lda FBANK
		sta PBANK
		rts
;--------------------------------
LOAD_DATA
		
		lda TMP
		pha
		lda TMP+1
		pha
		
		tya
		sta TMP
		sta BLKSTA
		txa
		sta TMP+1
		sta BLKSTA+1
		
		ADW BLKSTA BLKLEN BLKEND
		
@		lda FSTATUS
		beq LDEOF
		
		jsr GET_BYTE
		ldy #$00
		sta (TMP),y
		
		INW TMP
		
		lda TMP
		cmp BLKEND
		bne @-
		lda TMP+1
		cmp BLKEND+1
		bne @-

LDEOF	pla
		sta TMP+1
		pla
		sta TMP
		rts
;--------------------------------
GET_BYTE
		lda FSTATUS
		bne @+
		rts
@		lda PPOS
		bne @+
		jsr COPY_SECTOR
@		ldx PPOS
		lda TMPBUF,x
		pha
		jsr INC_PPOS
		pla
		rts
;--------------------------------
COPY_SECTOR
		lda TMP
		pha
		lda TMP+1
		pha
		lda #$00
		sta TMP
		tay
		clc
		lda PSECTOR
		add #$A0
		sta TMP+1
		jsr WAITVB
		jsr UPCRIT
		ldx PBANK
		sta $D500,x
		jsr CTRIGTG
@		lda (TMP),y
		sta TMPBUF,y
		iny
		bne @-
		jsr CARTOFF
		jsr DWCRIT
		pla
		sta TMP+1
		pla
		sta TMP
		rts
;--------------------------------
INC_PPOS
		inc PPOS
		bne INCRET
		inc PSECTOR
		lda PSECTOR
		cmp #$20
		bne @+
		lda #$00
		sta PSECTOR
		inc PBANK
@		inc PPOS+1
		bne INCRET
		inc PPOS+2
INCRET	lda PPOS
		cmp	FSIZE
		bne @+
		lda PPOS+1
		cmp	FSIZE+1
		bne @+
		lda PPOS+2
		cmp	FSIZE+2
		bne @+
		lda #$00
		sta FSTATUS
@		rts
;--------------------------------
SET_INIAD
		sty INITAD
		stx INITAD+1
		rts
;--------------------------------
SET_RUNAD
		sty RUNAD
		stx RUNAD+1
		rts
;--------------------------------
SET_LENGTH
		sty BLKLEN
		stx BLKLEN+1
		rts
;--------------------------------
FILE_OFFSET
		lda FSTATUS
		bne @+
		rts
@		sty PPOS
		stx PPOS+1
		sta PPOS+2
		txa
		and #$1F
		sta PSECTOR
		lda PPOS+1
		lsr
		lsr
		lsr
		lsr
		lsr
		sta PBANK
		lda PPOS+2
		asl
		asl
		asl
		ora PBANK
		and #$3F
		sta PBANK
		clc
		lda FSECTOR
		adc PSECTOR
		pha
		and #$1F
		sta PSECTOR
		pla
		lsr
		lsr
		lsr
		lsr
		lsr
		pha
		clc
		lda FBANK
		adc PBANK
		sta PBANK
		clc
		pla
		adc PBANK
		and #$3F
		sta PBANK
		rts
;--------------------------------
FILEINFO
;--------
FSTATUS	dta 0		; 1 - opened & data ready
FILENO	dta 0		; file no
FSIZE	dta 0,0,0	; file size
FSECTOR	dta 0		; sector number
FBANK	dta 0		; bank number
PPOS	dta 0,0,0	; pointer of file
PSECTOR	dta 0		; current sector
PBANK	dta 0		; current bank
;--------------------------------
BLKSTA	dta 0,0		; start data
BLKEND	dta 0,0		; stop data
BLKLEN	dta 0,0		; length data
;--------------------------------
AUTOFN	dta c'AUTORUN COM'
;-----------------------------------------------------------------------	
.end
ENDXEMU
;-----------------------------------------------------------------------
; PROCEDURES IN BANK

		ORG	$BB00
;-----------------------------------------------------------------------
; 
CAR_OPEN_FILE

		lda TMP
		pha
		lda TMP+1
		pha
		lda TMP+2
		pha
		lda TMP+3
		pha
		lda TMP+4
		pha
		
		sty TMP+2
		stx TMP+3
		
		lda #<(NOF+1)
		sta TMP
		lda #>(NOF+1)
		sta TMP+1
		
		lda #$00
		sta TMP+4
		
STRCMP	ldy #$00
@		lda (TMP),y
		cmp (TMP+2),y
		bne NEXTIF
		iny
		cpy #$0B
		bne @-
		
		lda #$01
		sta FSTRUCT
		lda TMP+4
		sta FSTRUCT+1
		ldx #$00
@		lda (TMP),y
		sta FSTRUCT+2,x
		iny
		inx
		cpx #$05
		bne @-
		beq FINDED
		
NEXTIF	inc TMP+4
		lda TMP+4
		cmp NOF
		beq NOFILE
		clc
		lda TMP
		adc #$10
		sta TMP
		bcc @+
		inc TMP+1
@		clc
		bcc STRCMP
		
NOFILE	ldx #$0C
		lda #$00
@		sta FSTRUCT,x
		dex
		bpl @-
		
FINDED	pla
		sta TMP+4
		pla
		sta TMP+3
		pla
		sta TMP+2
		pla
		sta TMP+1
		pla
		sta TMP
		rts
;-----------------------------------------------------------------------
; MAIN PROC

		ORG $BD00
;-----------------------------------------------------------------------
; BEGIN
BEGIN	jsr BASDIS
		jsr CPYPXEM
		jsr CLRPG7
		lda #$0C
		sta MEMLO+1
		lda #$00
		sta MEMLO
		clc
		ldx #$FF
		txs
RUN		jmp LOAD_AUTORUN
;-----------------------------------------------------------------------
; COPY xEMU to RAM
CPYPXEM	ldx #$00
@		lda XEMU,x
		sta XEMUAD,x
		lda XEMU+$0100,x
		sta XEMUAD+$0100,x
		inx
		bne @-
@		lda XEMU+$0200,x
		sta XEMUAD+$0200,x
		inx
		cpx #<(ENDXEMU-XEMU)
		bne @-
		rts
;-----------------------------------------------------------------------
; CLEAR PAGE7
CLRPG7	lda #$00
		tax
@		sta TMPBUF,X
		inx
		bne @-	
		rts
;-----------------------------------------------------------------------		
; DISABLE BASIC AND REOPEN EDITOR
BASDIS	lda #$00
		sta DMACTLS
		sta DMACTL
		lda #01
		sta CRITIC
		lda PORTB
		ora #$02
		sta PORTB
		lda #$01
		sta BASICF
		lda #$1F
		sta MEMTOP
		lda #$BC
		sta MEMTOP+1
		lda #$C0
		sta RAMTOP
		ldx #(CLPRE-CLPRS-1)
@		lda CLPRS,X
		sta TMPBUF,X
		dex
		bpl @-
		jsr TMPBUF	
		lda #<RESETCD
		sta DOSVEC
		sta DOSINI
		sta CASINI	
		lda #>RESETCD
		sta DOSVEC+1
		sta DOSINI+1
		sta CASINI+1
		lda #$03
		sta BOOTQ
		lda #$00
		sta COLDST
		rts
;----------------
; Clear RAM under CART
CLPRS	sta $D5FF
		lda #$A0
		sta TMP+1
		lda #$00
		sta TMP
		ldy #$00
NEWPAG	lda #$00
@		sta (TMP),Y
		iny
		bne @-
		inc TMP+1
		lda TMP+1
		cmp #$C0
		bne NEWPAG
		lda TRIG3
		sta GINTLK
		dec CRITIC
		jsr EDOPN
		lda #$00
		sta DMACTLS
		sta DMACTL
		inc CRITIC
		sta $D500
		lda TRIG3
		sta GINTLK
		dec CRITIC		
		lda #$00
		sta TMP
		sta TMP+1
		rts
CLPRE
;-----------------------------------------------------------------------		
; CLONE FOR LAST BANK MAXFLASH OLD

		ORG $BF00
		
		dta $FF
;-----------------------------------------------------------------------		
; INITCART ROUTINE

		ORG $BFDA
			
INIT	lda CONSOL
		and #$02
		bne CONTIN
		ldx #(CONTIN-STANDR-1)
@		lda STANDR,X
		sta TMPBUF,x
		dex
		bpl @-
		jmp TMPBUF
STANDR  sta $D5FF
		jmp RESETCD
CONTIN	sta $D500
RETURN	rts
;-----------------------------------------------------------------------		
; BANK NUMBER

		ORG $BFF9
		
BANKNUM	dta $00
;-----------------------------------------------------------------------
; CARTRIDGE HEADER

		ORG $BFFA
		
		dta <BEGIN, >BEGIN, $00, $04, <INIT, >INIT
;-----------------------------------------------------------------------
