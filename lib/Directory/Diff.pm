=head1 Directory::Diff

=head1 NAME

Directory::Diff - recursively find differences between similar directories

=head1 SYNOPSIS

     use Directory::Diff 'directory_diff';

     # Do a "diff" between "old_dir" and "new_dir"

     directory_diff ('old_dir', 'new_dir', 
                     {diff => \&diff
                      dir1_only => \& old_only});

     # User-supplied callback for differing files

     sub diff
     {
         my ($data, $dir1, $dir2, $file) = @_;
         print "$dir1/$file is different from $dir2/$file.\n";
     }

     # User-supplied callback for files only in one of the directories

     sub old_only
     {
         my ($data, $dir1, $file) = @_;
         print "$file is only in the old directory.\n";
     }

=head1 DESCRIPTION

Directory::Diff finds differences between two directories and all
their subdirectories, recursively. If it finds a file with the same
name in both directories, it uses L<File::Compare> to find out whether
they are different. It is callback-based and takes actions only if
required.

=head1 FUNCTIONS

The main function of this module is L<directory_diff>. The other
functions are helper functions, but these can be exported on request.

=cut

package Directory::Diff;
require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw/ls_dir get_only get_diff directory_diff
                default_diff default_dir_only/;
use warnings;
use strict;
our $VERSION = 0.01;
use Carp;
use Cwd;
use File::Compare;

=head2 ls_dir

     my %ls = ls_dir ("dir");

C<ls_dir> makes a hash containing a true value for each file and
directory which is found under the directory given as the first
argument.

It also has an option to print messages on what it finds, by setting a
second argument to a true value, for example

     my %ls = ls_dir ("dir", 1);

=cut

sub ls_dir
{
    my ($dir, $verbose) = @_;
    if (! $dir || ! -d $dir) {
        croak "bad inputs";
    }
    my %ls;
    if (! wantarray) {
        die "bad call";
    }
    my $original_dir = getcwd ();
    chdir ($dir);
    opendir (my $dh, ".");
    my @files = readdir ($dh);
    for my $file (@files) {
        if ($file eq '.' || $file eq '..') {
            next;
        }
        if (-f $file) {
            $ls{"$file"} = 1;
        }
        elsif (-d $file) {
            my %subdir = ls_dir ($file);
            for my $subdir_file (keys %subdir) {
                $ls{"$file/$subdir_file"} = 1;
            }
            $ls{"$file/"} = 1;
        }
        else {
            warn "Skipping unknown type of file $file.\n";
        }
    }
    closedir ($dh);
    chdir ($original_dir);
    if ($verbose) {
        for my $k (keys %ls) {
            print "$k $ls{$k}\n";
        }
    }
    return %ls;
}

=head2 get_only

     my %only = get_only (\%dir1, \%dir2);

Given two hashes containing true values for each file or directory
under two directories, return a hash containing true values for the
files and directories which are in the first directory hash but not in
the second directory hash.

For example, if

     %dir1 = ("file" => 1, "dir/" => 1, "dir/file" => 1);

and 

     %dir2 = ("dir/" => 1, "dir2/" => 1);

C<get_only> returns

     %only = ("file" => 1, "dir/file" => 1);

There is also a third option which prints messages on what is found if
set to a true value, for example,

     my %only = get_only (\%dir1, \%dir2, 1);

=cut

sub get_only
{
    my ($ls_dir1_ref, $ls_dir2_ref, $verbose) = @_;

    if (ref ($ls_dir1_ref) ne "HASH" ||
            ref ($ls_dir2_ref) ne "HASH") {
        croak "bad inputs";
    }
    my %only;

    # d1e = directory one entry
    
    for my $d1e (keys %$ls_dir1_ref) {
        if (! $ls_dir2_ref->{$d1e}) {
            $only{$d1e} = 1;
            if ($verbose) {
                print "$d1e is only in first directory.\n";
            }
        }
    }
    if (! wantarray) {
        croak "bad call";
    }
    return %only;
}

=head2 get_diff

     my %diff = get_diff ("dir1", \%dir1_ls, "dir2", \%dir2_ls);

Get a list of files which are in both C<dir1> and C<dir2>, but which
are different. This uses L<File::Compare> to test the files for
differences. It searches subdirectories. Usually the hashes
C<%dir1_ls> and C<%dir2_ls> are those output by L<ls_dir>.

=cut

sub get_diff
{
    my ($dir1, $ls_dir1_ref, $dir2, $ls_dir2_ref, $verbose) = @_;
    if (ref ($ls_dir1_ref) ne "HASH" ||
            ref ($ls_dir2_ref) ne "HASH") {
        croak "bad inputs";
    }
    my %different;
    for my $file (keys %$ls_dir1_ref) {
        my $d1file = "$dir1/$file";
        if ($ls_dir2_ref->{$file}) {
            if (! -f $d1file) {
#                croak "Bad file / directory combination $d1file";
                next;
            }
            my $d2file = "$dir2/$file";
            if (0) {
                my $dodiff = "diff --brief $d1file $d2file";
                my $diff = `$dodiff`;
                if ($verbose) {
                    print $dodiff;
                    print "\n";
                    print $diff;
                    print "\n";
                }
                if ($diff) {
                    $different{$file} = 1;
                }
            }
            else {
                if (compare ($d1file, $d2file) != 0) {
                    $different{$file} = 1;
                }
            }
        }
    }
    if (! wantarray) {
        croak "Bad call";
    }
    return %different;
}

=head2 directory_diff

     directory_diff ("dir1", "dir2", 
                     {dir1_only => \&dir1_only,
                      diff => \& diff});

Given two directories "dir1" and "dir2", this calls back a
user-supplied routine for each of three cases:

=over

=item A file is only in the first directory

In this case a callback specified by C<dir1_only> is called.

     &{$third_arg->{dir1_only}} ($third_arg->{data}, "dir1", $file);

for each file C<$file> which is in directory one but not in directory
two, including files in subdirectories.

=item A file is only in the second directory

In this case a callback specified by C<dir2_only> is called.

     &{$third_arg->{dir2_only}} ($third_arg->{data}, "dir2", $file);

for each file C<$file> which is in directory two but not in directory
one, including files in subdirectories.

=item A file with the same name but different contents is in both directories

In this case a callback specified by C<diff> is called.

     &{$third_arg->{diff}} ($third_arg->{data}, "dir1", "dir2", $file);

for each file name C<$file> which is in both directory one and in
directory two, including files in subdirectories.

=back

The first argument to each of the callback functions is specified by
C<data>. The second argument to C<dir1_only> and C<dir2_only> is the
directory's name. The third argument is the file name, which includes
the subdirectory part. The second and third arguments to C<diff> are
the two directories, and the fourth argument is the file name
including the subdirectory part.

If the user does not supply a callback, no action is taken even if a
file is found.

The routine does not return a meaningful value. It does not check the
return values of the callbacks. Therefore if it is necessary to stop
midway, the user must use something like C<eval { }> and C<die>.

A fourth argument, if set to any true value, causes directory_diff to
print messages about what it finds and what it does.

=cut

sub directory_diff
{
    my ($dir1, $dir2, $callback_ref, $verbose) = @_;
    if (! $dir1 || ! -d $dir1 || ! $dir2 || ! -d $dir2) {
        croak "bad inputs";
    }
    if ($verbose) {
        print "Directory diff of $dir1 and $dir2 in progress ...\n";
    }
    if (! $callback_ref || ref $callback_ref ne "HASH") {
        croak "bad callback input";
    }
    my %ls_dir1 = ls_dir ($dir1);
    my %ls_dir2 = ls_dir ($dir2);
    # Data to pass to called back functions.
    my $data = $callback_ref->{data};
    # Call back a function on each file which is only in directory 1.
    my $d1cb = $callback_ref->{dir1_only};
    if ($d1cb) {
        # Files which are only in directory 1.
        my %dir1_only = get_only (\%ls_dir1, \%ls_dir2, $verbose);
        for my $file (keys %dir1_only) {
            &{$d1cb} ($data, $dir1, $file, $verbose);
        }
    }
    # Call back a function on each file which is only in directory 2.
    my $d2cb = $callback_ref->{dir2_only};
    if ($d2cb) {
        # Files which are only in directory 2.
        my %dir2_only = get_only (\%ls_dir2, \%ls_dir1, $verbose);
        for my $file (keys %dir2_only) {
            &{$d2cb} ($data, $dir2, $file, $verbose);
        }
    }
    # Call back a function on each file which is in both directories
    # but different.
    my $diff_cb = $callback_ref->{diff};
    if ($diff_cb) {
        # Files which are in both directories but are different.
        my %diff_files = get_diff ($dir1, \%ls_dir1, $dir2, \%ls_dir2, $verbose);
        for my $file (keys %diff_files) {
            &{$diff_cb} ($data, $dir1, $dir2, $file, $verbose);
        }
    }
    if (defined wantarray) {
        carp "directory_diff does not return a meaningful value";
    }
    return;
}

=head2 default_dir_only

     use Directory::Diff qw/directory_diff default_dir_only/;
     directory_diff ('old', 'new', {dir1_only => \&default_dir_only});

A simple routine to print out when a file is only in one of the
directories. This is for testing the C<Directory::Diff> module.

=cut

sub default_dir_only
{
    my ($data, $dir, $file) = @_;
    print "File '$file' is only in '$dir'.\n";
}

=head2 default_diff

     use Directory::Diff qw/directory_diff default_diff/;
     directory_diff ('old', 'new', {dir1_only => \&default_diff});

A simple routine to print out when a file is different between the
directories. This is for testing the C<Directory::Diff> module.

=cut

sub default_diff
{
    my ($data, $dir1, $dir2, $file) = @_;
    print "File '$file' is different between '$dir1' and '$dir2'.\n";
}

1;

=head1 AUTHOR

Ben Bullock bkb@cpan.org

=head1 MOTIVATION

The reason I wrote this module is because C<< `diff --recursive` >>
stops when it finds a subdirectory which is in one directory and not
the other, without descending into the subdirectory. For example, if
one has a file like C<dir1/subdir/file>,

     diff -r dir1 dir2

will tell you "Only in dir1: subdir" but it won't tell you anything
about the files under "subdir".

I needed to go down into the subdirectory and find all the files which
were in all the subdirectories, so I wrote this.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
