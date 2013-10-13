#!/usr/bin/perl -w
# ttslh - generate total time spent listening as hourly graph
use DBI;
our $DBI;
use strict;
use GD::Graph::lines;
die("Usage: $0 database host port day\n") unless $#ARGV == 3;
my($database, $host, $port, $day) = @ARGV;
die("Error: Database $database doesn't exist\n") unless (-f $database);
my $dbh = DBI->connect("DBI:SQLite:dbname=" . $database,"","", {RaiseError => 1, AutoCommit => 0 }) or die "Error connecting to DB. " . $DBI->errstr;
my $sthl = $dbh->prepare("select sum(time) from listeners where host = ? and port = ? and starttime >= ? and starttime <= ?");
my $line;
my ($startyear, $startmonth, $startday);
if ($day =~ /^(\d\d\d\d)(\d\d)(\d\d)$/) {
$startyear = $1;
$startmonth = $2;
$startday = $3;
}
else { die("Error: Day is not in correct format (YYYYMMDD)\n"); }
my $hour=0;
my @hours;
my @values;
print("Gathering data for $host:$port.\n");
until ($hour > 23) {
my $starttime = sprintf("%04d%02d%02d%s0000", $startyear, $startmonth, $startday, $hour);
my $endtime = sprintf("%04d%02d%02d%s5959", $startyear, $startmonth,
$startday, $hour);
$sthl->execute($host, $port, $starttime, $endtime);
my $ttsl;
$ttsl = $sthl->fetchrow_array or $ttsl = 0;
$ttsl = $ttsl/60 unless $ttsl == 0;
push(@hours, "$hour:00");
push(@values, $ttsl);
$hour+=1;
}
$sthl->finish;
$dbh->disconnect;
print("Generating graph.\n");
my @data;
push(@data, \@hours);
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
x_label => 'Hour',
y_label => 'TTSL in Minutes * ' . $scale,
title => "TTSL for $host port $port on $startmonth/$startday/$startyear",
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
my $fname = sprintf("ttslh_%s_%s_%02d-%02d-%04d_%s.png", $hostdash, $port, $startmonth, $startday, $startyear, $scale);
open(IMG, ">$fname") or die $!;
binmode IMG;
print IMG $gd->png;
close IMG;
print("Finished...\n");

