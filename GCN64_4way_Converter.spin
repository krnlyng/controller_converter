CON
    _xinfreq = 5_000_000
    _clkmode = xtal1 + pll16x

OBJ
    CO1         : "N64_Console"
    CO2         : "N64_Console"
    CO3         : "N64_Console"
    CO4         : "N64_Console"
    P1          : "GC_Controller"
    P2          : "GC_Controller"
    P3          : "GC_Controller"
    P4          : "GC_Controller"

VAR
    long p1_do_update
    long p1_updatetime
    long p1_controller_data[2]
    long p1_consoleinfo

    long p2_do_update
    long p2_updatetime
    long p2_controller_data[2]
    long p2_consoleinfo

    long p3_do_update
    long p3_updatetime
    long p3_controller_data[2]
    long p3_consoleinfo

    long p4_do_update
    long p4_updatetime
    long p4_controller_data[2]
    long p4_consoleinfo

PUB start
    CO1.start_controller(0, @p1_do_update)
    CO2.start_controller(1, @p2_do_update)
    CO3.start_controller(2, @p3_do_update)
    CO4.start_controller(3, @p4_do_update)
    P1.start_console(4, @p1_do_update)
    P2.start_console(5, @p2_do_update)
    P3.start_console(6, @p3_do_update)
    P4.init_console(0, 7, @p4_do_update)

