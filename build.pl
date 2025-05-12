#!/home/ben/software/install/bin/perl
use warnings;
use strict;
use FindBin '$Bin';
use Getopt::Long;
my $ok = GetOptions (
    nopb => \my $nopb,
);
if (! $ok) {
    print "Wrong options";
    exit;
}
if (! $nopb) {
    print "Bog";
    eval {
	require Perl::Build;
	Perl::Build->import ();
	perl_build (
	    make_pod => "$Bin/make-pod.pl",
	);
    };
}
if ($@) {
    $nopb = 1;
}
if ($nopb) {
    system ("$Bin/make-pod.pl --nopb") == 0 or die "make-pod.pl failed";
}
