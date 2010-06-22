def do_pins(name):
    return ["%s%d" % (name, i) for i in range(8)]

pnames = ['PORTA', 'PORTB', 'PORTC', 'PORTD']

ports = {"PORTA" : do_pins("PA"),
        "PORTB" : do_pins("PB"),
        "PORTC" : do_pins("PC"),
        "PORTD" : do_pins("PD")}

def choose_fsport(obj, port):
    name = port.read()
    cfg.choose("FS_RS", ports[name])
    cfg.choose("FS_EN", ports[name])
    cfg.choose("FS_RW", ports[name])

def choose_port(obj, port):
    name = port.read()
    p = ports[name]
    cfg.choose("LSB_PIN", [p[i] for i in range(5)])

def set_ddr(obj, port):
    return "DDR" + port.read().lstrip('PORT')

def set_pin(obj, port):
    return "PIN" + port.read().lstrip('PORT')

def check_reinit_count(value):
    try:
        number = int(value)
        if number < 10 and number > 0:
            return True
    except ValueError:
        pass
    return False

fs_port = cfg.choose("FS_PORT", pnames)
cfg.bind(None, choose_fsport, fs_port)

dat_port = cfg.choose("DATA_PORT", pnames)

cfg.bind(None, choose_port, dat_port)

cfg.bind("FS_DDR", set_ddr, fs_port)
cfg.bind("DATA_DDR", set_ddr, dat_port)
cfg.bind("DATA_PIN", set_pin, dat_port)

cfg.expr("REINIT_COUNT", check=check_reinit_count,
    help="This must be an integer in range [1,10]")
