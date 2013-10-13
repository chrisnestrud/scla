#!/usr/bin/perl -w
# dnsexport - create dns export database
use strict;
use warnings;
use DBI;
die("Usage: $0 current.db\n") unless $#ARGV == 0;
my ($current) = @ARGV;
my $dnsdb = 'dns-' . $current;
die("Error: Database $current not found.\n") unless ( -f $current);
die("Error: $dnsdb already exists.\n") if (-f $dnsdb);
my $st = time();
our $DBI;
debug("Attempting to create $dnsdb.");
my $dbhc = DBI->connect("DBI:SQLite:dbname=" . $current,"","", {AutoCommit => 0, RaiseError => 1 }) or die ("Error connecting to DB: $!\n");
my $dbhd = DBI->connect("DBI:SQLite:dbname=" . $dnsdb,"","", {AutoCommit => 0, RaiseError => 1 }) or die ("Error connecting to DB: $!\n");
die("Error: unable to connect to or create $dnsdb") unless -f $dnsdb;
debug("Connected.\n");
my $numrecords=0;
my $addedrecords=0;
debug("Creating temporary allips table.");
my $sthd = $dbhd->prepare("create temporary table allips(ip)");
$sthd->execute;
my @tables = qw/backups full listeners streamsavers unavailable/;
my $sthc = $dbhc->prepare("select distinct ip from ? where ip not in (select ip from hosts)");
$sthd = $dbhd->prepare("insert into allips values(?)");
for(@tables) {
my $numrecords=0;
my $table = $_;
debug("Getting ips from table $table");
$sthc->execute($table);
debug("Adding ips from table $table");
while (my($ip) = $sthc->fetchrow_array) {
$sthd->execute($ip);
$numrecords+=1;
debug("Added $numrecords records from table $table. Last IP was $ip.") if ($numrecords % 20000 == 0 && $numrecords > 0);
}
}
$sthc->finish;
debug("Creating ips table");
$sthd = $dbhd->prepare("create table ips(ip)");
$sthd->execute;
$sthd = $dbhd->prepare("create index ipsip on ips(ip)");
$sthd->execute;
debug("Adding ips to ips table");
$sthd = $dbhd->prepare("insert into ips select distinct ip from allips");
$sthd->execute;
debug("Adding other tables.");
$sthd = $dbhd->prepare("create table lastip(ip)");
$sthd->execute;
$sthd = $dbhd->prepare("insert into lastip values(?)");
$sthd->execute('0.0.0.0');
$sthd = $dbhd->prepare("create table hosts (ip, hostname, lastcheck integer)");
$sthd->execute;
debug("Commiting.");
$dbhd->commit;
debug("Commit complete.");
$sthc->finish;
$sthd->finish;
$dbhd->disconnect;
$dbhc->disconnect;
debug("Database $dnsdb is ready for dns processing.");

sub debug {
my $msg = shift;
my $total = time()-$st;
my $hours = int $total/60/60;
$total -= $hours*60*60;
my $minutes = int $total/60;
$total -= $minutes*60;
print($hours . "h") if ($hours > 0);
print($minutes . "m") if ($minutes > 0);
print($total . "s: $msg\n");
}

