
build_GCN64_4way:
	openspin GCN64_4way_Converter.spin

load_GCN64_4way:
	python2.7 Loader.py GCN64_4way_Converter.binary

program_GCN64_4way:
	openspin -e GCN64_4way_Converter.spin
	python2.7 Loader.py GCN64_4way_Converter.eeprom

build_N64_test:
	openspin N64N64_test.spin

load_N64_test:
	python2.7 Loader.py N64N64_test.binary

program_N64_test:
	openspin -e N64N64_test.spin
	python2.7 Loader.py N64N64_test.eeprom

