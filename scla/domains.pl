#!/usr/bin/perl -w
use DBI;
our $DBI;
use strict;
use GD::Graph::bars;
my $y_tick_number = 10;
die("Usage: $0 database host port time\n") unless $#ARGV == 3;
my($database, $host, $port, $time) = @ARGV;
die("Error: Database $database doesn't exist\n") unless (-f $database);
my $dbh = DBI->connect("DBI:SQLite:dbname=" . $database,"","", {RaiseError => 1, AutoCommit => 0 }) or die "Error connecting to DB. " . $DBI->errstr;
my $sthl = $dbh->prepare("select count(*) from listeners, hosts where host = ? and port = ? and starttime >= ? and starttime <= ? and hosts.ip = listeners.ip and hosts.hostname like ?");
my %domainlist = ('%.com' => 'Commercial', '%.net' => 'Network', '%.edu' => 'Educational', '%.mil' => 'Military', '%.gov' => 'Government', '%.us' => 'US', '%.uk' => 'UK', '%.fr' => 'France', '%.de' => 'Germany', '%.au' => 'Australia');
my %graphdata;
my @domains;
my @values;
die("Error: Invalid time") unless $time =~ /^\d\d\d\d+$/;
my($year, $month, $day, $hour, $timedesc);
my ($starttime, $endtime);
my $totaldomains=0;
$year = substr($time, 0, 4);
$month = substr($time, 4, 2) if length($time) >= 6;
$day = substr($time, 6, 2) if length($time) >= 8;
$hour = substr($time, 8, 2) if length($time) >= 10;
$timedesc = $month . '-' if $month;
$timedesc .= $day . '-' if $day;
$timedesc .= $year;
$timedesc .= ' ' . $hour . ':00 to ' . $hour . ':59' if $hour;
$starttime = $year;
$endtime = $year;
$starttime .= $month if $month;
$starttime .= '01' unless $month;
$endtime .= $month if $month;
$endtime .= '12' unless $month;
$starttime .= $day if $day;
$starttime .= '01' unless $day;
$endtime .= $day if $day;
$endtime .= '31' unless $day;
$starttime .= $hour if $hour;
$starttime .= '00' unless $hour;
$endtime .= $hour if $hour;
$endtime .= '00' unless $hour;
$starttime .= '0000';
$endtime .= '5959';
while (my($k, $v) = each(%domainlist)) { $graphdata{$k} = 0; }
print("Gathering data for $host:$port.\n");
while(my($k, $v) = each(%domainlist)) {
$sthl->execute($host, $port, $starttime, $endtime, $k);
my $count;
$count = $sthl->fetchrow_array or $count = 0;
$graphdata{$k} = $count;
}
$sthl->finish;
$dbh->disconnect;
my @sorted = sort({ $graphdata{$a} <=> $graphdata{$b} } keys %graphdata);
my $max=0;
for(1..10) {
my $dom = pop(@sorted);
my $count = $graphdata{$dom};
push(@domains, $domainlist{$dom});
push(@values, $count);
$totaldomains += $count;
$max = $count if $count > $max;
print('Domain ' . $domainlist{$dom} . ' had ' . $count . " listeners.\n");
}
my $avg = $max;
my $scale;
for (qw/100000 90000 80000 70000 60000 50000 40000 30000 20000 10000 9000 8000 7000 6000 5000 4000 3000 2000 1000 900 800 700 600 500 400 300 200 100 90 80 70 60 50 40 30 20 10/) { $scale = $_ if $_ >= $max; }
print("Max is $max. Scale is $scale. Amount per tick is " . $scale/$y_tick_number. ".\n");
print("Total of $totaldomains domains in graph.\n");
print("Generating graph.\n");
my @data;
push(@data, \@domains);
push(@data, \@values);
my $graph = GD::Graph::bars->new(800, 600);
$graph->set (
title => 'Popularity of domains by listener count for ' . $host . ':' . $port . ' on ' . $timedesc,
x_label => 'Domain',
y_label => 'No. of Listeners * ' . $scale/$y_tick_number,
line_width => 3,
y_tick_number => $y_tick_number,
y_min_value => 0,
y_max_value => $scale,
);
my $gd = $graph->plot(\@data)  or die $graph->error;
print("Writing graph.\n");
my $hostdash = $host;
$hostdash =~ s/\./-/g;
my $fname = 'domains_' . $hostdash . '_' . $port . '_';
$fname .= $month . '-' if $month;
$fname .= $day . '-' if $day;
$fname .= $year;
$fname .= '_' . $hour if $hour;
$fname .= '_' . $scale . '.png';
open(IMG, ">$fname") or die $!;
binmode IMG;
print IMG $gd->png;
close IMG;
print("Finished...\n");

