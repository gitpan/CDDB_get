use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'CDDB_get',
    'VERSION_FROM' => 'CDDB_get.pm', # finds $VERSION
    'EXE_FILES' => ['cddb.pl'],
);
