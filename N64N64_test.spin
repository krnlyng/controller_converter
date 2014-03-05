' n64 test module, connect a n64 controller to an n64 with my module in between wohoo

CON
    _xinfreq = 5_000_000
    _clkmode = xtal1 + pll16x

OBJ
    CO1         : "N64"
    P1          : "N64"

VAR
    long p1_do_update
    long p1_updatetime
    long p1_controller_data[2]
    long p1_consoleinfo

PUB start
    CO1.start_controller(0, @p1_do_update)
    P1.start_console(4, @p1_do_update)

