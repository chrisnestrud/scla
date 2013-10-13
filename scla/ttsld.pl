#!/usr/bin/perl -w
# ttsld - generate total time spend listening as daily graph
use DBI;
our $DBI;
use strict;
use GD::Graph::lines;
die("Usage: $0 database host port start end\n") unless $#ARGV == 4;
my($database, $host, $port, $start, $end) = @ARGV;
die("Error: Database $database doesn't exist\n") unless (-f $database);
my $dbh = DBI->connect("DBI:SQLite:dbname=" . $database,"","", {RaiseError => 1, AutoCommit => 0 }) or die "Error connecting to DB. " . $DBI->errstr;
my $sthl = $dbh->prepare("select sum(time) from listeners where host = ? and port = ? and starttime >= ? and starttime <= ?");
my $line;
my ($startyear, $startmonth, $startday, $endyear, $endmonth, $endday);
if ($start =~ /^(\d\d\d\d)(\d\d)(\d\d)$/) {
$startyear = $1;
$startmonth = $2;
$startday = $3;
}
else { die("Error: Start time is not in correct format (YYYYMMDD)\n"); }
if ($end =~ /^(\d\d\d\d)(\d\d)(\d\d)$/) {
$endyear = $1;
$endmonth = $2;
$endday = $3;
}
else { die("\nError: End time is not in correct format (YYYYMMDD)\n"); }
my $y = $startyear;
my $m = $startmonth;
my $d = $startday;
my @days;
my @values;
my $finish=0;
print("Gathering data for $host:$port.\n");
until ($finish == 1) {
my $starttime = sprintf("%04d%02d%02d000000", $y, $m, $d);
my $endtime = sprintf("%04d%02d%02d235959", $y, $m, $d);
$sthl->execute($host, $port, $starttime, $endtime);
my $ttsl;
$ttsl = $sthl->fetchrow_array or $ttsl = 0;
$ttsl = $ttsl/60/60 unless $ttsl == 0;
push(@days, "$m/$d");
push(@values, $ttsl);
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
my $total=0;
my $count = 0;
for(@values) {
$total += $_;
$count += 1;
}
my $avg = 0;
$avg = $total/$count unless $total == 0;
my $scale;
$scale = 100000 if $avg > 100000;
$scale = 10000 if $avg > 10000 && $avg <= 100000;
$scale = 1000 if $avg > 1000 && $avg <= 10000;
$scale = 100 if $avg > 100 and $avg <= 1000;
$scale = 10 if $avg > 10 and $avg <= 100;
$scale = 1 if $avg <= 10;
$scale*=2;
print("Total is $total. Average is $avg. Scale is $scale.\n");
my $graph = GD::Graph::lines->new(800, 600);
$graph->set (
x_label => 'Day',
y_label => 'TTSL in Hours * ' . $scale,
title => "TTSL for $host port $port between $startmonth/$startday/$startyear and $endmonth/$endday/$endyear ",
line_width=>3,
y_tick_number => 10,
y_min_value => 0,
y_max_value => $scale*10,
x_label_skip => 2
);
my $gd = $graph->plot(\@data)  or die $graph->error;
print("Writing graph.\n");
my $hostdash = $host;
$hostdash =~ s/\./-/g;
my $fname = sprintf("ttsld_%s_%s_%02d-%02d-%04d_%02d-%02d-%04d_%s.png", $hostdash, $port, $startmonth, $startday, $startyear, $endmonth, $endday, $endyear, $scale);
open(IMG, ">$fname") or die $!;
binmode IMG;
print IMG $gd->png;
close IMG;
print("Finished...\n");

