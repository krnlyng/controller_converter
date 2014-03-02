
build_GCN64_4way:
	openspin GCN64_4way_Converter.spin

load_GCN64_4way:
	python2.7 Loader.py GCN64_4way_Converter.binary

program_GCN64_4way:
	openspin -e GCN64_4way_Converter.spin
	python2.7 Loader.py GCN64_4way_Converter.eeprom


