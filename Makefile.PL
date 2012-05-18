# Run "perl Makefile.PL" to create "Makefile", then run "make" to
# build, "make test" to test, and "make install" to install the
# software.

use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile (
    NAME => 'Directory::Diff',
    VERSION_FROM => 'lib/Directory/Diff.pm',
    ABSTRACT_FROM => 'lib/Directory/Diff.pm',
    PREREQ_PM => {
        'File::Compare' => 0,
        'File::Copy' => 0,
        'Cwd' => 0,
        'File::Path' => 0,
    },
);
