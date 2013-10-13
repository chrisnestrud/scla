#!/usr/bin/perl -w
# listenersd - generate graph of daily listeners
use DBI;
our $DBI;
use strict;
use GD::Graph::lines;
my %months = ( 1 => 'January', 2 => 'February', 3 => 'March', 4 => 'April', 5 => 'May', 6 => 'June', 7 => 'July', 8 => 'August', 9 => 'September', 10 => 'October', 11 => 'November', 12 => 'December');
my $database = "sc.db";
my $dbh = DBI->connect("DBI:SQLite:dbname=" . $database,"","", {RaiseError => 1, AutoCommit => 0 }) or die "Error connecting to DB. " . $DBI->errstr;
my $sthl = $dbh->prepare("select count(*) from listeners where port = ? and starttime >= ? and endtime <= ?");
my $line;
my ($startyear, $startmonth, $startday, $endyear, $endmonth, $endday);
my $max=0;
print("Port: ");
chomp(my $port = <STDIN>);
print("\nStart: ");
chomp($line = <STDIN>);
if ($line =~ /^(\d\d\d\d)(\d\d)(\d\d)$/) {
$startyear = $1;
$startmonth = $2;
$startday = $3;
}
else { die("\nError: Start time is not in correct format (YYYYMMDD)\n"); }
print("\nEnd: ");
chomp($line = <STDIN>);
if ($line =~ /^(\d\d\d\d)(\d\d)(\d\d)$/) {
$endyear = $1;
$endmonth = $2;
$endday = $3;
}
else { die("\nError: End time is not in correct format (YYYYMMDD)\n"); }
print("\nPlease wait...\n");
my $y = $startyear;
my $m = $startmonth;
my $d = $startday;
my @days;
my @values;
my $finish=0;
until ($finish == 1) {
my $starttime = sprintf("%04d%02d%02d000000", $y, $m, $d);
my $endtime = sprintf("%04d%02d%02d235959", $y, $m, $d);
print("Getting count of listeners for $m/$d/$y\n");
$sthl->execute($port, $starttime, $endtime);
my $listeners;
$listeners = $sthl->fetchrow_array or $listeners = 0;
$max = $listeners if $listeners > $max;
push(@days, "$m/$d");
push(@values, $listeners);
print("Listeners on $m/$d/$y: $listeners\n");
$finish = 1 if (($d == $endday) && ($m == $endmonth) && ($y == $endyear));
if ($d == 31) {
$m++;
$d = 1;
if ($m == 13) {
$m = 1;
$y++;
}
}
else { $d++; }
}
$sthl->finish;
$dbh->disconnect;
print("Generating graph.\n");
my @data;
push(@data, \@days);
push(@data, \@values);
my $scale;
$scale = 100000 if $max > 100000;
$scale = 10000 if $max > 10000 && $max <= 100000;
$scale = 1000 if $max > 1000 && $max <= 10000;
$scale = 100 if $max > 100 and $max <= 1000;
$scale = 10 if $max < 100;
my $graph = GD::Graph::lines->new(800, 600);
$graph->set (
x_label => 'Day',
y_label => 'No. of Listeners * ' . $scale,
title => "Listeners on fast.streammadness.com port $port between $startmonth/$startday/$startyear and $endday/$endmonth/$endyear ",
line_width=>3,
y_tick_number => 10,
y_max_value => $scale*10,
# y_label_skip => $scale,
x_ticks=>0
);
my $gd = $graph->plot(\@data)  or die $graph->error;
print("Writing graph.\n");
my $fname = sprintf("listeners_%s_%02d-%02d-%04d_%02d-%02d-%04d.png", $port, $startmonth, $startday, $startyear, $endmonth, $endday, $endyear);
open(IMG, ">$fname") or die $!;
binmode IMG;
print IMG $gd->png;
close IMG;
print("Finished...\n");

