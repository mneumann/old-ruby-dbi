require 'mkmf'

# You may need to change these parameters
FREETDSDIR = "/usr/local/freetds"
# end of parameters

$CFLAGS = "-I#{FREETDSDIR}/include"
$LDFLAGS = "-L#{FREETDSDIR}/lib"
$libs = "-ltds"

create_makefile("dbd_sybase")