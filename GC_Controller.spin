obj

var
    long cog

' simulate a gc console (for interfacing with a controller)
pub start_console(GC_out_pin, do_button_update_ptr)
    setup(GC_out_pin, do_button_update_ptr, do_button_update_ptr+4, do_button_update_ptr+8, do_button_update_ptr+16)
    if cog
        cogstop(cog~ - 1)
    be_controller := 0
    cog := cognew(@gc, 0) + 1

pub init_console(thecogid, GC_out_pin, do_button_update_ptr)
    setup(GC_out_pin, do_button_update_ptr, do_button_update_ptr+4, do_button_update_ptr+8, do_button_update_ptr+16)
    cog := thecogid
    be_controller := 0
    coginit(thecogid, @gc, 0)

{{
' simulate a gc controller (for interfacing with a console)
pub start_controller(GC_in_pin, do_button_update_ptr)
    setup(GC_in_pin, do_button_update_ptr, do_button_update_ptr+4, do_button_update_ptr+8, do_button_update_ptr+16)
    if cog
        cogstop(cog~ - 1)
    be_controller := 1
    cog := cognew(@gc, 0) + 1

pub init_controller(thecogid, GC_in_pin, do_button_update_ptr)
    setup(GC_in_pin, do_button_update_ptr, do_button_update_ptr+4, do_button_update_ptr+8, do_button_update_ptr+16)
    cog := thecogid
    be_controller := 1
    coginit(thecogid, @gc, 0)
}}

pub setup(GC_inout_pin, do_button_update_ptr, the_updatetime_ptr, controller_data1_ptr, theconsoleinfo_ptr)
    gc_pin := GC_inout_pin
    updatetime_ptr := the_updatetime_ptr
    do_update_ptr := do_button_update_ptr
    data1_ptr := controller_data1_ptr
    data2_ptr := controller_data1_ptr+4
    consoleinfo_ptr := theconsoleinfo_ptr

    uS1 := clkfreq / 1_000_000
    uS2 := 2 * uS1
    uS3 := 3 * uS1
    uS4_8 := uS1 / 2
    uS10 := 10 * uS1
    uS20 := 20 * uS1

    mS1 := (clkfreq / 1_000)

dat
            org 0
gc
{{
            cmp be_controller, C1 wz
    if_z    jmp #gc_controller
}}

' interface with a gc controller (simulate a console)
gc_console
            call #init

            mov reps1, #5 ' try 5 times
gc_console_init_loop
            mov reps, #8
            mov gc_command, #0
            call #transmit_gc
            call #transmit_stop_bit_gc

            mov reps, #24
            call #receive_from_gc
    if_z    jmp #gc_console_loop ' if no timeout leave
            djnz reps1, #gc_console_init_loop

' TODO (failed)
            jmp #gc_console_loop


gc_console_loop
            ' wait for request
            rdlong tmp, do_update_ptr
            cmp tmp, C1                 wz
    if_nz   jmp #gc_console_loop

            mov update_time_diff_tmp, cnt

            mov reps, #24
            mov gc_command, gc_command_readstate
            call #transmit_gc
            call #transmit_stop_bit_gc

            call #receive_state_from_gc

            call #publish_button_data

            mov update_time_diff, cnt
            sub update_time_diff, update_time_diff_tmp
            wrlong update_time_diff, updatetime_ptr

            ' done
            wrlong C0, do_update_ptr

            jmp #gc_console_loop

{{
' interface with a gc console (simulate a controller)
gc_controller
            call #init
            jmp #gc_controller
}}

init
            ' initialize pin masks
            mov gc_pinmask, #1
            shl gc_pinmask, gc_pin

            ' initialize counters
            movi ctra, #%01000_000 ' counter for high time
            movi ctrb, #%01100_000 ' counter for low time

            movs ctra, gc_pin
            movs ctrb, gc_pin

            mov frqa, #1
            mov frqb, #1
init_ret    ret

transmit_gc
            mov time, cnt
            add time, uS1
transmit_gc_loop
            or dira, gc_pinmask                 ' pull line low
            rol gc_command, #1              wc  ' read bit from gc_command into c flag
            waitcnt time, uS2                   ' wait 1 uS and add 2 uS to time
    if_c    andn dira, gc_pinmask               ' if the bit is 1 then let the line go
            waitcnt time, uS1                   ' wait 2 uS and add 1 uS to time
            andn dira, gc_pinmask               ' release the line if not already done
            waitcnt time, uS1                   ' wait 1 uS and add 1 uS to time
            djnz reps, #transmit_gc_loop
transmit_gc_ret        ret

transmit_stop_bit_gc
            mov time, cnt
            add time, uS1
            ' stop bit
            or dira, gc_pinmask    ' pull line low
            waitcnt time, #0       ' wait 1 uS
            andn dira, gc_pinmask  ' release line
transmit_stop_bit_gc_ret ret

receive_state_from_gc
            mov reps, #32
            call #receive_from_gc
            mov gc_data1, gc_data

            mov reps, #32
            call #receive_from_gc
            mov gc_data2, gc_data
receive_state_from_gc_ret         ret

receive_from_gc
            mov pinmask, gc_pinmask
            mov recv_data, #0
            call #receive_generic
            mov gc_data, recv_data
receive_from_gc_ret ret

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

publish_button_data
            rdlong tmp, consoleinfo_ptr
            cmp tmp, C0 wz
    if_z    call #publish_n64
            cmp tmp, C1 wz
    if_z    call #publish_gc
publish_button_data_ret     ret

publish_n64
            mov n64_state_answer, #0
            call #convert_gc_data_to_n64_data
            wrlong n64_state_answer, data1_ptr
publish_n64_ret ret

publish_gc
            wrlong gc_data1, data1_ptr
            wrlong gc_data2, data2_ptr
publish_gc_ret   ret

convert_gc_data_to_n64_data
            test gc_data1, gc_start_mask wz
    if_nz   or n64_state_answer, n64_start_mask wr

            test gc_data1, gc_y_mask wz
    if_nz   or n64_state_answer, n64_cleft_mask wr

            test gc_data1, gc_x_mask wz
    if_nz   or n64_state_answer, n64_cright_mask wr

            test gc_data1, gc_b_mask wz
    if_nz   or n64_state_answer, n64_b_mask wr

            test gc_data1, gc_a_mask wz
    if_nz   or n64_state_answer, n64_a_mask wr

            ' l -> z
            test gc_data1, gc_l_mask wz
    if_nz   or n64_state_answer, n64_z_mask wr

            test gc_data1, gc_r_mask wz
    if_nz   or n64_state_answer, n64_r_mask wr

            test gc_data1, gc_z_mask wz
    if_nz   or n64_state_answer, n64_cdown_mask wr

            test gc_data1, gc_dleft_mask wz
    if_nz   or n64_state_answer, n64_dleft_mask wr

            test gc_data1, gc_dright_mask wz
    if_nz   or n64_state_answer, n64_dright_mask wr

            test gc_data1, gc_dup_mask wz
    if_nz   or n64_state_answer, n64_dup_mask wr

            test gc_data1, gc_ddown_mask wz
    if_nz   or n64_state_answer, n64_ddown_mask wr

{{ ' simple hacky method won't work because of left/right swap
            mov tmp, gc_dpad_mask
            and tmp, gc_data1
            shl tmp, #8
            or n64_state_answer, tmp wr
}}

left_joystick
x_axis
            mov tmp, gc_joy_x_axis
            and tmp, gc_data1
            shr tmp, #8

            ' fancy calculation
            sub tmp, #127
            cmp tmp, C0 wz
    if_z    jmp #y_axis             ' ignore if there is no movement

            mov axis_tmp, tmp
            shr axis_tmp, #2
            add axis_tmp, tmp
            shr axis_tmp, #1

            mov tmp, axis_tmp
            shl tmp, #8

            and tmp, n64_joy_x_mask
            or n64_state_answer, tmp wr

y_axis
            mov tmp, gc_joy_y_axis
            and tmp, gc_data1

            ' fancy calculation
            sub tmp, #127

            cmp tmp, C0 wz
    if_z    jmp #right_joystick     ' ignore if there is no movement

            mov axis_tmp, tmp
            shr axis_tmp, #2
            add axis_tmp, tmp
            shr axis_tmp, #1

            and axis_tmp, n64_joy_y_mask
            or n64_state_answer, axis_tmp wr

right_joystick
            mov tmp, gc_cjoy_x_axis
            and tmp, gc_data2
            shr tmp, #24

            cmp tmp, gc_joy_1_4_value wc, nr
    if_c    or n64_state_answer, n64_cleft_mask wr

            cmp tmp, gc_joy_3_4_value wc, nr
    if_nc   or n64_state_answer, n64_cright_mask wr

            mov tmp, gc_cjoy_y_axis
            and tmp, gc_data2
            shr tmp, #16

            cmp tmp, gc_joy_1_4_value wc, nr
    if_c    or n64_state_answer, n64_cdown_mask wr

            cmp tmp, gc_joy_3_4_value wc, nr
    if_nc   or n64_state_answer, n64_cup_mask wr
convert_gc_data_to_n64_data_ret     ret

gc_command_readstate    long %0100_0000_0000_0011_0000_0000_1000_0000
gc_command          long 0

C0                  long 0
C1                  long 1
C2                  long 2

'C5                 long 5
'C10                 long 10
C15                 long 15

gc_data1            long 0
gc_data2            long 0
gc_data             long 0

timeout          long 0

gc_pin        long    0

gc_pinmask      long    0

pinmask         long    0
reps            long    0
lowtime         long    0

recv_data       long    0

uS1             long    0
uS2             long    0
uS3             long    0
uS4_8             long    0
uS10            long    0
uS20             long    0
time            long    0

controller_info_ptr      long    0
'gc_data1_ptr long    0
'gc_data2_ptr long    0

do_update_ptr       long    0
updatetime_ptr      long    0

tmp                 long    0

update_time_diff    long    0
update_time_diff_tmp    long    0

compare                 long    0

reps1                   long    0

subtract                long    0 ' timing subtract

request_difference      long    0

sync_count              long    0        ' frame to wait for console request

data1_ptr               long    0
data2_ptr               long    0

mS1                     long    0

axis_tmp            long 0


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
n64_joy_x_shift     long 8
n64_joy_y_mask      long $00_00_00_FF
n64_joy_y_shift     long 0
'end

' helpers
n64_cup_mask        long $00_08_00_00
n64_cdown_mask      long $00_04_00_00
n64_cleft_mask      long $00_02_00_00
n64_cright_mask     long $00_01_00_00

gc_joy_1_4_value    long    63
gc_joy_middle_value long    127
gc_joy_3_4_value    long    191

n64_state_answer        long 0


consoleinfo_ptr         long 0

be_controller        long 0

