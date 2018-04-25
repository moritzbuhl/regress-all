#!/usr/bin/perl
# collect all os-test results and create a html table
# os-test package must be installed

# Copyright (c) 2018 Alexander Bluhm <bluhm@genua.de>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

use strict;
use warnings;
use Cwd;
use Getopt::Std;

my %opts;
getopts('h:l', \%opts) or do {
    print STDERR <<"EOF";
usage: $0 -p publish
    -t publish	directory where the test suite results are created
EOF
    exit(2);
};
my $publish = $opts{p} or die "No -p specified";
$publish = getcwd(). "/". $publish if substr($publish, 0, 1) ne "/";

my $dir = dirname($0). "/..";
chdir($dir)
    or die "Chdir to '$dir' failed: $!";
my $regressdir = getcwd();

my $latest = readlink "latest";
my @latesthost = map { readlink $_ or () } glob("latest-*");

my $testsuite = "os-test";

$dir = "$publish/$testsuite";
make_path("$dir/out") or die "make path '$dir/out' failed: $!";
chdir($dir)
    or die "Chdir to '$dir' failed: $!";

if ($latest) {
    my $obj = "$regressdir/$latest/test.obj.tgz";
    my @pax = ("pax", "-zrf", $obj, "-s,^/misc/$testsuite/,,",
	"/misc/$testsuite/");
    system(@pax)
	and die "Command '@pax' failed: $?";
}

foreach my $date (@latesthost) {
    my $obj = "$regressdir/$date/test.obj.tgz";
    my @pax = ("pax", "-zrf", $obj, "-s,^/misc/$testsuite/,out/$date/,",
	"/misc/$testsuite/");
    system(@pax)
	and die "Command '@pax' failed: $?";
}