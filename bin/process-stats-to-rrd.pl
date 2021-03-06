#!/bin/perl

=head1 NAME

process-stats-to-rrd.pl - Will start a process and print stats to rrd file

=head1 DESCRIPTION

This script will start a given program and wait for it to end. When the
program ends, this script will print statistics to an RRD file. The RRD
file will have these data sources:

usertime, systemtime, maxrss, ixrss, idrss, isrss, minflt, majflt, nswap
inblock, oublock, msgsnd, msgrcv, nsignals, nvcsw, nivcsw and time.

All of these names are defined in the L<BSD::Resource> perl module, except
from "time" which is the actual time spent running the application.

=head1 USAGE

To generate statistics:

 $ process-stats-to-rrd.pl <program> [arguments];

The filename of the output RRD will be all of the arguments combined,
seperated by "," and special characters will be replaced with "_".

To generate image from statistics:

 $ process-stats-to-rrd.pl -g some_file.rrd

NOTE: The output image format will be changed.

=head1 REQUIREMENTS

 $ cpan -i BSD::Resource;
 $ aptitude install rrdtool;

=cut

use strict;
use warnings;
use BSD::Resource;

BEGIN {
    no warnings;
    *DEBUG = $ENV{'DEBUG'} ? sub { print STDERR "$$> @_\n" }
           :                 sub {}
           ;
}

my $STEP = 300;
my @COLORS = qw/
                ff0000 0000ff 00ff00 ffffff ffffff
                ffffff ffffff ffffff 005500 ffffff ffffff
                440000 000044 ffffff ffffff ffffff 000000
            /;
my @KEYS = qw/
                usertime systemtime maxrss ixrss idrss
                isrss minflt majflt nswap inblock oublock
                msgsnd msgrcv nsignals nvcsw nivcsw time
            /;
my $t0 = time;


if(@ARGV == 2 and $ARGV[0] eq '-g') {
    exit generate_graph($ARGV[1]);
}
elsif(@ARGV) {
    my $pid = fork;

    # parent process
    if($pid) {
        DEBUG "Waiting for $pid: '@ARGV'";
        local $SIG{'CHLD'} = \&reaper;
        waitpid $pid, 0;
        exit $?;
    }

    # child
    elsif(defined $pid) {
        run(@ARGV) and die $!;
        exit $?;
    }

    # could not fork
    else {
        die $!;
    }
}
else {
    die "Usage: $0 <command> [args]";
}

=head1 FUNCTIONS

=head2 reaper

 reaper();

Will print statistics to rrdfile, when child has completed its task.

=cut

sub reaper {
    my @stats = getrusage(RUSAGE_CHILDREN);
    my $file = rrdfile();
    my $i = 0;

    # don't want to run reaper() again
    local $SIG{'CHLD'} = 'IGNORE';

    # wait for child to exit
    wait; 

    # add stats
    push @stats, time - $t0;

    DEBUG "Child process reaped";

    for my $key (@KEYS) {
        DEBUG sprintf "%-10s %s", $key, $stats[$i++];
    }

    # update rrd file
    run(
        rrdtool => update => $file =>
        '--template' => join(':', @KEYS),
        'N:' .join(':', @stats),
    );
}

=head2 rrdfile

 $path = rrdfile();

Will create the rrdfile, unless it already exists.

=cut

sub rrdfile {
    my $file = join ',', map { s/\W/_/g; $_ } @ARGV;
    my $rows = 86400 / $STEP * 7;

    $file .= '.rrd';

    unless(-e $file) {
        run(
            rrdtool => create => $file => '--step' => $STEP =>
            ( map { "DS:$_:GAUGE:$STEP:0:U" } @KEYS ),
            "RRA:AVERAGE:0.5:$STEP:$rows",
        );
    }

    return $file;
}

=head2 run

 $exit_code = run(@args);

Same as C<system()>, but will also log when in debug mode.

=cut

sub run {
    DEBUG "system(@_)";
    return system @_;
}

=head2 generate_graph
 
 generate_graph($rrdfile);

Will create a png file from rrd.

=cut

sub generate_graph {
    my $file = shift;
    my $i = 0;

    run(
        rrdtool => graph => "$file.png" =>
        '--imgformat' => 'PNG',
        ( map { "DEF:$_=$file:$_:AVERAGE" } @KEYS ),
        (
            map {
                my $name = $_->[0];
                my $color = $_->[1];
                (
                    "VDEF:avg_$name=$name,AVERAGE",
                    "VDEF:max_$name=$name,MAXIMUM",
                    "VDEF:last_$name=$name,LAST",
                    "LINE2:$name#$color:$name",
                    "GPRINT:avg_$name:avg=%le ",
                    "GPRINT:max_$name:max=%le ",
                    "GPRINT:last_$name:last=%le\\n",
                )
            } grep {
                $_->[1] ne 'ffffff';
            } map {
                [ $_, shift @COLORS ];
            } @KEYS
        ),
    );

    return $?;
}

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Jan Henning Thorsen - jhthorsen -at- cpan.org

=cut
