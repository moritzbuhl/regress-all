#!/usr/bin/perl

use strict;
use warnings;
use Cwd;
use File::Basename;
use Getopt::Std;
use POSIX;

use lib dirname($0);
use Logcmd;

my $scriptname = "$0 @ARGV";

my %opts;
getopts('h:sv', \%opts) or do {
    print STDERR <<"EOF";
usage: $0 [-sv] -h host
    -h host	optional user and host for make regress, user defaults to root
    -s		skip setup, host must already be installed
    -v		verbose
EOF
    exit(2);
};
$opts{h} or die "No -h specified";

# create directory for this test run with timestamp 2016-07-13T12:30:42Z
my $date = strftime("%FT%TZ", gmtime);

my $dir = dirname($0). "/..";
chdir($dir)
    or die "Chdir to '$dir' failed: $!";
my $regressdir = getcwd();
$dir = "results";
-d $dir || mkdir $dir
    or die "Make result directory '$dir' failed: $!";
$dir .= "/$date";
mkdir $dir
    or die "Make directory '$dir' failed: $!";
unlink("results/current");
symlink($date, "results/current")
    or die "Make symlink 'results/current' failed: $!";

createlog(file => "$dir/run.log", verbose => $opts{v});
logmsg("script '$scriptname' started at $date\n");

# setup remote machines

my ($user, $host) = split('@', $opts{h}, 2);
($user, $host) = ("root", $user) unless $host;
my $firsthost = $host;

unless ($opts{s}) {
    my @setupcmd = ("bin/setup.pl", '-h', "$user\@$host", '-d', $date);
    push @setupcmd, '-v' if $opts{v};
    runcmd(@setupcmd);
    if ($host++) {
	@setupcmd = ("bin/setup.pl", '-h', "$user\@$host", '-d', $date);
	push @setupcmd, '-v' if $opts{v};
	runcmd(@setupcmd);
    }
}

for ($host = $firsthost; $host; $host++) {
    my $h = "$user\@$host";
    my $version = "$dir/version-$host.txt";
    eval { logcmd({
	cmd => ['ssh', $h, 'sysctl', 'kern.version', 'hw.machine', 'hw.ncpu'],
	outfile => $version,
    })};
    if ($@) {
	unlink $version;
	last;
    }
    my $dmesg = "$dir/dmesg-boot-$host.txt";
    eval { logcmd({
	cmd => ['ssh', $h, 'cat', '/var/run/dmesg.boot'],
	outfile => $dmesg,
    })};
    if ($@) {
	unlink $dmesg;
    }
}

# run regress there

($host = $opts{h}) =~ s/.*\@//;
my @sshcmd = ('ssh', $opts{h}, 'perl', '/root/regress/regress.pl',
    '-e', "/root/regress/env-$host.sh", '-v');
logcmd(@sshcmd);

# get result and logs

my @scpcmd = ('scp');
push @scpcmd, '-q' unless $opts{v};
push @scpcmd, ("$opts{h}:/root/regress/test.*", $dir);
runcmd(@scpcmd);

open(my $tr, '<', "$dir/test.result")
    or die "Open '$dir/test.result' for reading failed: $!";
mkdir "$dir/logs"
    or die "Make directory '$dir/logs' failed: $!";
chdir("$dir/logs")
    or die "Chdir to '$dir/logs' failed: $!";
my @paxcmd = ('pax', '-rzf', "../test.log.tgz");
open(my $pax, '|-', @paxcmd)
    or die "Open pipe to '@paxcmd' failed: $!";
while (<$tr>) {
    my ($status, $test, $message) = split(" ", $_, 3);
    print $pax "$test/make.log" unless $test =~ m,[^\w/],;
}
close($pax) or die $! ?
    "Close pipe to '@paxcmd' failed: $!" :
    "Command '@paxcmd' failed: $?";
close($tr)
    or die "Close '$dir/test.result' after reading failed: $!";

chdir($regressdir)
    or die "Chdir to '$regressdir' failed: $!";

for ($host = $firsthost; $host; $host++) {
    my $h = "$user\@$host";
    my $dmesg = "$dir/dmesg-$host.txt";
    eval { logcmd({
	cmd => ['ssh', $h, 'dmesg'],
	outfile => $dmesg,
    })};
    if ($@) {
	unlink $dmesg;
	last;
    }
}

# create html output

runcmd("bin/setup-html.pl");
runcmd("bin/regress-html.pl", "-h", $firsthost);

unlink("results/latest");
symlink($date, "results/latest")
    or die "Make symlink 'results/latest' failed: $!";
runcmd("bin/regress-html.pl", "-h", $firsthost, "-l");

$date = strftime("%FT%TZ", gmtime);
logmsg("script '$scriptname' finished at $date\n");
