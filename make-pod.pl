#!/home/ben/software/install/bin/perl
use warnings;
use strict;
use Template;
use FindBin '$Bin';
use Getopt::Long;

my $ok = GetOptions (
    'force' => \my $force,
    'nopb' => \my $nopb,
    'verbose' => \my $verbose,
);
if (! $ok) {
    usage ();
    exit;
}

# Perl::Build dependencies start here.
my $version = 'no version';
my $commit = {commit => 'no commit id', date => 'no date'};
my $info = {version => 'no version', name => 'no name', repo => 'no repo', date => 'no date'};
if (! $nopb) {
    eval {
	require Perl::Build;
	Perl::Build->import (qw/get_version get_commit get_info/);
	my %pbv = (base => $Bin);
	$version = get_version (%pbv);
	$commit = get_commit (%pbv);
	$info = get_info (%pbv);
    };
    require Deploy;
    Deploy->import (qw/do_system older/);
    require Perl::Build::Pod;
    Perl::Build::Pod->import ('pbtmpl');
}
if ($@) {
    $nopb = 1;
    warn "$@";
}

# Template toolkit variable holder

my %vars = (
    version => $version,
    commit => $commit,
    info => $info,
);

my @includes = (
    $Bin,
    "$Bin/examples",
    "$Bin/substitutes",
);
my %filters = (xtidy => \& noop);
if (! $nopb) {
    shift @includes, pbtmpl();
    $filters{xtidy} = [
	\& xtidy,
	0,
    ],
}

my $tt = Template->new (
    ABSOLUTE => 1,
    INCLUDE_PATH => \@includes,
    ENCODING => 'UTF8',
    FILTERS => \%filters,
    STRICT => 1,
);

my @examples = <$Bin/examples/*.pl>;
if (! $nopb) {
    for my $example (@examples) {
	my $output = $example;
	$output =~ s/\.pl$/-out.txt/;
	if (older ($output, $example) || $force) {
	    do_system ("perl -I$Bin/blib/lib -I$Bin/blib/arch $example > $output 2>&1", $verbose);
	}
    }
}

# Names of the input and output files containing the documentation.

my $pod = 'Diff.pod';
my $input = "$Bin/lib/Directory/$pod.tmpl";
my $output = "$Bin/lib/Directory/$pod";

$tt->process ($input, \%vars, $output, binmode => 'utf8')
    or die '' . $tt->error ();

exit;

sub usage
{
    print <<EOF;
--verbose
--force
EOF
}
sub noop
{
    return '';
}
