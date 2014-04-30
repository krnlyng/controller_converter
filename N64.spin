obj

var
    long cog

' simulate a n64 console (for interfacing with a controller)
pub start_console(N64_out_pin, do_button_update_ptr)
    setup(N64_out_pin, do_button_update_ptr, do_button_update_ptr+4, do_button_update_ptr+8, do_button_update_ptr+16)
    if cog
        cogstop(cog~ -1)
    be_controller := 0
    cog := cognew(@n64, 0) + 1

pub init_console(thecogid, N64_out_pin, do_button_update_ptr)
    setup(N64_out_pin, do_button_update_ptr, do_button_update_ptr+4, do_button_update_ptr+8, do_button_update_ptr+16)
    cog := thecogid
    be_controller := 0
    coginit(thecogid, @n64, 0)

' simulate a n64 controller (for interfacing with a console)
pub start_controller(N64_in_pin, do_button_update_ptr)
    setup(N64_in_pin, do_button_update_ptr, do_button_update_ptr+4, do_button_update_ptr+8, do_button_update_ptr+16)
    if cog
        cogstop(cog~ -1)
    be_controller := 1
    cog := cognew(@n64, 0) + 1

pub init_controller(thecogid, N64_in_pin, do_button_update_ptr)
    setup(N64_in_pin, do_button_update_ptr, do_button_update_ptr+4, do_button_update_ptr+8, do_button_update_ptr+16)
    cog := thecogid
    be_controller := 1
    coginit(thecogid, @n64, 0)

pub setup(N64_inout_pin, do_button_update_ptr, theupdatetime_ptr, controller_data_ptr, theconsoleinfo_ptr)
    n64_pin := N64_inout_pin
    updatetime_ptr := theupdatetime_ptr
    do_update_ptr := do_button_update_ptr
    data1_ptr := controller_data_ptr
    data2_ptr := controller_data_ptr+4
    consoleinfo_ptr := theconsoleinfo_ptr

    uS1 := clkfreq / 1_000_000
    uS2 := 2 * uS1
    uS3 := 3 * uS1
    uS4_8 := uS1 / 2
    uS10 := 10 * uS1
    mS1 := (clkfreq / 1_000)

dat
            org 0
n64
            cmp be_controller, C1 wz
    if_z    jmp #n64_controller

' interface with an n64 controller (simulate a console)
n64_console
            call #init
n64_console_loop
            ' wait for request
            rdlong tmp, do_update_ptr
            cmp tmp, C1         wz
    if_nz   jmp #n64_console_loop

            mov update_time_diff_tmp, cnt

            mov reps, #8
            mov n64_command_answer, n64_cmd_state
            shl n64_command_answer, #24
            call #transmit_n64
            call #transmit_stop_bit_n64

            call #receive_state_from_n64

            call #publish_button_data

            mov update_time_diff, cnt
            sub update_time_diff, update_time_diff_tmp
            wrlong update_time_diff, updatetime_ptr

            ' done
            wrlong C0, do_update_ptr

            jmp #n64_console_loop

' interface with an n64 console (simulate a controller)
n64_controller
            wrlong C0, consoleinfo_ptr
            call #init
n64_controller_loop
            ' read command byte from the console
            mov reps, #8 ' receive 1 byte
            mov n64_command, #0
            call #receive_from_n64
    if_z    jmp #check_command ' if no timeout leave

            ' check if we need to request an update
            cmp update_requested, C1 wz
    if_z    jmp #n64_controller_loop

            mov tmp, last_state
            add tmp, timediff
            rdlong tmp0, updatetime_ptr
            sub tmp, tmp0
            sub tmp, subtract

            ' check if it's time for an update
            cmp tmp, cnt wc
    if_nc   jmp #n64_controller_loop ' not yet if tmp >= cnt

            wrlong C1, do_update_ptr
            mov update_requested, C1
            jmp #n64_controller_loop

            ' check which command we received
check_command
            cmp n64_command, n64_cmd_identify   wz
    if_z    jmp #n64_identify
            cmp n64_command, n64_cmd_state      wz
    if_z    jmp #n64_state
            cmp n64_command, n64_cmd_0x02       wz
    if_z    jmp #n64_0x02
            cmp n64_command, n64_cmd_0x03       wz
    if_z    jmp #n64_0x03
            cmp n64_command, n64_cmd_reset      wz
    if_z    jmp #n64_reset

            ' unknown command, start from begining
            jmp #n64_controller_loop

n64_identify
            call #wait_for_n64_stop_bit

            ' send identification bytes
            mov reps, #24 ' 3 Byte
            cmp crc_result, C0 wz
    if_z    mov n64_command_answer, n64_identify_answer
    if_nz   mov n64_command_answer, n64_identify_answer_bad_crc
            call #transmit_n64
            call #transmit_stop_bit_n64

            jmp #n64_controller_loop

n64_state
            call #wait_for_n64_stop_bit

            mov update_requested, C0

            ' check if the controller module was fast enough
            rdlong tmp, do_update_ptr
            cmp tmp, C0 wz
    if_nz   add subtract, uS1 ' controller module was to slow

            ' calculate time between now and the last update
            mov tmp, cnt
            mov timediff_tmp, tmp
            sub timediff_tmp, last_state
            abs timediff_tmp, timediff_tmp

            ' only save minimal timediff
            cmp timediff_tmp, timediff wc
    if_c    mov timediff, timediff_tmp

            ' if timediff hasn't been set yet set it
            cmp timediff, C0 wz
    if_z    mov timediff, timediff_tmp
after_diff
            mov last_state, tmp

            ' read button data
            rdlong n64_state_answer, data1_ptr

            ' send button information
            mov reps, #32 ' 4 Byte
            mov n64_command_answer, n64_state_answer
            call #transmit_n64
            call #transmit_stop_bit_n64

            jmp #n64_controller_loop

n64_0x02
            jmp #n64_controller_loop
            ' 0x02 command

            mov reps, #16 ' receive address and crc
            call #receive_from_n64
            mov address_and_crc, n64_command

            call #wait_for_n64_stop_bit

            mov reps1, #32
send_remaining_0x02_bytes_n64
            mov reps, #8
            mov n64_command_answer, #0
            call #transmit_n64
            djnz reps1, #send_remaining_0x02_bytes_n64

            mov reps, #8
            mov n64_command_answer, n64_answer_no_mempack
            call #transmit_n64
            call #n64_address_crc
            
            jmp #n64_controller_loop

n64_0x03
            jmp #n64_controller_loop
            ' 0x03 command

            mov reps, #16 ' receive address and crc
            call #receive_from_n64
            mov address_and_crc, n64_command

            mov reps1, #8 ' 8*4 = 32 bytes
            ' dummy receive for now.
recv_remaining_0x03_bytes_n64
            mov reps, #32 ' receive a long
            call #receive_from_n64
            djnz reps1, #recv_remaining_0x03_bytes_n64

            call #wait_for_n64_stop_bit

            mov reps, #8
            mov n64_command_answer, n64_answer_no_mempack
            call #transmit_n64
            call #n64_address_crc

            jmp #n64_controller_loop

n64_reset
            ' n64 expects same answer as identify answer
            jmp #n64_identify

init
            mov n64_pinmask, #1
            shl n64_pinmask, n64_pin

            ' initialize counter to listen for commands from N64
            movs ctra, n64_pin
            movs ctrb, n64_pin

            movi ctra, #%01000_000 ' counter for high time
            movi ctrb, #%01100_000 ' counter for low time

            mov frqa, #1
            mov frqb, #1
init_ret    ret

transmit_n64
            mov time, cnt
            add time, uS1
transmit_n64_loop
            or dira, n64_pinmask                ' pull line low
            rol n64_command_answer, #1      wc  ' read bit from n64_command_answer into c flag
            waitcnt time, uS2                   ' wait 1 uS and add 2 uS to time
    if_c    andn dira, n64_pinmask              ' if the bit is 1 then let the line go
            waitcnt time, uS1                   ' wait 2 uS and add 1 uS to time
            andn dira, n64_pinmask              ' release the line if not already done
            waitcnt time, uS1                   ' wait 1 uS and add 1 uS to time
            djnz reps, #transmit_n64_loop
transmit_n64_ret        ret

transmit_stop_bit_n64
            mov time, cnt
            add time, uS1
            ' stop bit
            or dira, n64_pinmask    ' pull line low
            waitcnt time, #0        ' wait 1 uS
            andn dira, n64_pinmask  ' release line
transmit_stop_bit_n64_ret ret

wait_for_low_timeout
            test pinmask, INA wz                    ' test if low
    if_nz   djnz timeout, #wait_for_low_timeout     ' try again if not low and no timeout
wait_for_low_timeout_ret   ret

receive_generic
first_bit_generic
            mov phsa, #0                            ' ready high count for timeouts
            mov phsb, #0                            ' ready low count

            ' wait for low
            mov timeout, uS4_8
            call #wait_for_low_timeout
            'if timeout return
    if_nz   jmp #receive_generic_ret    

            mov phsa, #0                            ' ready high count
            waitpeq pinmask, pinmask                ' wait for high
            mov lowtime, phsb                       ' capture low count
            mov phsb, #0                            ' reset low count

            ' wait for low
            mov timeout, uS4_8
            call #wait_for_low_timeout
            'if timeout return
    if_nz   jmp #receive_generic_ret

            sub reps, #1
receive_remaining_bits
            cmp lowtime, phsa wc                    ' compare lowtime to hightime from currently captured bit
            rcl recv_data, #1                       ' store received bit into recv_data

            mov phsa, #0                            ' clear high count
            waitpeq pinmask, pinmask                ' wait for high
            mov lowtime, phsb                       ' capture low count
            mov phsb, #0                            ' reset low count
            ' wait for low
            mov timeout, uS4_8
            call #wait_for_low_timeout
            'if timeout return
    if_nz   jmp #receive_generic_ret

            djnz reps, #receive_remaining_bits      ' repeat for remaining command bits

            cmp lowtime, phsa wc                    ' compare lowtime to hightime for last bit
            rcl recv_data, #1                       ' store last bit into recv_data
receive_generic_ret ret

receive_state_from_n64
            mov reps, #32
            call #receive_from_n64
            mov n64_state_answer, n64_command
receive_state_from_n64_ret  ret

receive_from_n64
            mov pinmask, n64_pinmask
            mov recv_data, #0
            call #receive_generic
            mov n64_command, recv_data
receive_from_n64_ret        ret

wait_for_n64_stop_bit
            ' wait until console stop bit is over
            waitpeq n64_pinmask, n64_pinmask
            ' wait 1uS (necessary?)
            mov time, cnt
            add time, uS1
            waitcnt time, uS1
wait_for_n64_stop_bit_ret ret

n64_address_crc
            mov crc_result, address_and_crc
            mov cur_crc_poly, address_crc_poly
            shl cur_crc_poly, #11
            mov crc_bit_mask, #1
            shl crc_bit_mask, #15

n64_address_crc_loop
            test crc_result, crc_bit_mask wz
    if_nz   xor crc_result, cur_crc_poly

            shr cur_crc_poly, #1
            shr crc_bit_mask, #1
            tjnz crc_bit_mask, #n64_address_crc_loop
n64_address_crc_ret ret

publish_button_data
            rdlong tmp, consoleinfo_ptr
            cmp tmp, C0 wz
    if_z    call #publish_n64
            cmp tmp, C1 wz
    if_z    call #publish_gc
publish_button_data_ret     ret

publish_n64
            wrlong n64_state_answer, data1_ptr
publish_n64_ret  ret

publish_gc
            mov gc_data1, #0
            mov gc_data2, #0
            call #convert_n64_data_to_gc_data
            wrlong gc_data1, data1_ptr
            wrlong gc_data2, data2_ptr
publish_gc_ret   ret

convert_n64_data_to_gc_data
            test n64_state_answer, n64_a_mask wz
    if_z    or gc_data1, gc_a_mask wr

            test n64_state_answer, n64_b_mask wz
    if_z    or gc_data1, gc_b_mask wr

            ' z -> l
            test n64_state_answer, n64_z_mask wz
    if_z    or gc_data1, gc_l_mask wr

            test n64_state_answer, n64_start_mask wz
    if_z    or gc_data1, gc_start_mask wr

            test n64_state_answer, n64_dright_mask wz
    if_z    or gc_data1, gc_dright_mask wr

            test n64_state_answer, n64_dleft_mask wz
    if_z    or gc_data1, gc_dleft_mask wr

            test n64_state_answer, n64_dup_mask wz
    if_z    or gc_data1, gc_dup_mask wr

            test n64_state_answer, n64_ddown_mask wz
    if_z    or gc_data1, gc_ddown_mask wr

            ' l -> l
            test n64_state_answer, n64_l_mask wz
    if_z    or gc_data1, gc_l_mask wr

            test n64_state_answer, n64_r_mask wz
    if_z    or gc_data1, gc_r_mask wr

            ' cup -> ?
'            test n64_state_answer, n64_cup_mask wz
'    if_z    or gc_data1, gc_

            test n64_state_answer, n64_cdown_mask wz
    if_z    or gc_data1, gc_z_mask wr

            test n64_state_answer, n64_cleft_mask wz
    if_z    or gc_data1, gc_y_mask wr

            test n64_state_answer, n64_cright_mask wz
    if_z    or gc_data1, gc_x_mask wr

            ' TODO axes
convert_n64_data_to_gc_data_ret ret

gc_data1            long 0
gc_data2            long 0

address_and_crc     long 0
crc_result          long 0
crc_bit_mask        long 0
cur_crc_poly        long 0
address_crc_poly    long $00_00_00_15

pinmask             long 0
recv_data           long 0

n64_pin          long 0
n64_pinmask         long 0

uS1                 long 0
uS2                 long 0
uS3                 long 0
uS4_8               long 0
uS10                long 0
mS1                     long    0

time                long 0
timediff            long 0
timediff_tmp        long 0
last_state          long 0
lowtime             long 0
n64_command         long 0
n64_command_answer  long 0
n64_cmd_identify    long 0
n64_identify_answer long %0000_0101_0000_0000_0000_0010_0000_0000
n64_identify_answer_bad_crc long %0000_0101_0000_0000_0000_0100_0000_0000
n64_cmd_state       long 1
n64_state_answer    long %0000_0000_0000_0000_0000_0000_0000_0000
n64_cmd_0x02        long 2
n64_cmd_0x03        long 3
n64_cmd_reset       long 255
reps                long 0
reps1               long 0


' n64_state_answer description
n64_a_mask          long (1 << 31)
n64_b_mask          long (1 << 30)
n64_z_mask          long (1 << 29)
n64_start_mask      long (1 << 28)
n64_dpad_mask       long $0F_00_00_00

n64_dright_mask     long (1 << 24)
n64_dleft_mask      long (1 << 25)
n64_dup_mask        long (1 << 26)
n64_ddown_mask      long (1 << 27)

                    ' joy reset bit
                    '0
n64_l_mask          long (1 << 21)
n64_r_mask          long (1 << 20)
n64_cpad_mask       long $00_0F_00_00
n64_joy_x_mask      long $00_00_FF_00
n64_joy_y_mask      long $00_00_00_FF
'end

n64_answer_no_mempack   long $1E_00_00_00

' helpers
n64_cup_mask        long $00_08_00_00
n64_cdown_mask      long $00_04_00_00
n64_cleft_mask      long $00_02_00_00
n64_cright_mask     long $00_01_00_00

' gc_data1 description:
                    '0
                    '0
                    '0
gc_start_mask       long (1 << 28)
gc_y_mask           long (1 << 27)
gc_x_mask           long (1 << 26)
gc_b_mask           long (1 << 25)
gc_a_mask           long (1 << 24)
                    '1
gc_l_mask           long (1 << 22)
gc_r_mask           long (1 << 21)
gc_z_mask           long (1 << 20)
gc_dpad_mask        long $00_0F_00_00

gc_dleft_mask       long (1 << 16)
gc_dright_mask      long (1 << 17)
gc_dup_mask         long (1 << 18)
gc_ddown_mask       long (1 << 19)

gc_joy_x_axis       long $00_00_FF_00
gc_joy_y_axis       long $00_00_00_FF

'gc_data2 description:

gc_cjoy_x_axis      long $FF_00_00_00
gc_cjoy_y_axis      long $00_FF_00_00
gc_left_sbutton     long $00_00_FF_00     ' left shoulder button press level
gc_right_sbutton    long $00_00_00_FF     ' same for the right button

'end

axis_tmp            byte 0
axis_tmp1           byte 0
tmp                 long 0
tmp0                long 0

subtract            long 0

update_requested    long    0

long_sign           long %1000_0000_0000_0000_0000_0000_0000_0000

C0                  long 0
C1                  long 1

data1_ptr           long    0
data2_ptr           long    0

updatetime_ptr      long    0
do_update_ptr       long    0

timeout             long    0

consoleinfo_ptr     long    0

update_time_diff    long    0
update_time_diff_tmp    long    0

be_controller       long 0
