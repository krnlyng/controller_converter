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
    CO1.start(0, @p1_do_update, @p1_updatetime, @p1_controller_data, @p1_consoleinfo)
    CO2.start(1, @p2_do_update, @p2_updatetime, @p2_controller_data, @p2_consoleinfo)
    CO3.start(2, @p3_do_update, @p3_updatetime, @p3_controller_data, @p3_consoleinfo)
    CO4.start(3, @p4_do_update, @p4_updatetime, @p4_controller_data, @p4_consoleinfo)
    P1.start(4, @p1_do_update, @p1_updatetime, @p1_controller_data, @p1_consoleinfo)
    P2.start(5, @p2_do_update, @p2_updatetime, @p2_controller_data, @p2_consoleinfo)
    P3.start(6, @p3_do_update, @p3_updatetime, @p3_controller_data, @p3_consoleinfo)
    P4.init(0, 7, @p4_do_update, @p4_updatetime, @p4_controller_data, @p4_consoleinfo)

