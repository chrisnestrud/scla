#!/usr/bin/perl -w
use strict;
use warnings;
use DBI;
our $DBI;
use DateTime;
use Time::Local;
my $st = time();
die("Usage: $0 database logfile host port\n") unless $#ARGV == 3;
my $tz = $ENV{'TZ'};
die("Error: TZ environment variable must contain time zone used when logging\n") unless $tz;
debug("Using time zone $tz");
my ($database, $logfile, $host, $port) = @ARGV;
die("Error: Database $database not found\n") unless (-f $database);
die("Error: Log file $logfile not found\n") unless (-f $logfile);
my $dbh = DBI->connect("DBI:SQLite:dbname=" . $database,"","", {RaiseError => 1, AutoCommit => 0 }) or die "Error connecting to DB. " . $DBI->errstr;
my $sthli = $dbh->prepare("insert into listeners (host, port, starttime, time, endtime, agentid, ip, bytes) values (?, ?, ?, ?, ?, ?, ?, ?)");
my $sthac = $dbh->prepare("select rowid from agents where agent = ?");
my $sthai = $dbh->prepare("insert into agents (agent) values (?)");
my $sthbi = $dbh->prepare("insert into backups (host, port, ip, time, backupip, backupport) values (?, ?, ?, ?, ?, ?)");
my $sthui = $dbh->prepare("insert into unavailable (host, port, time, ip) values (?, ?, ?, ?)");
my $sthfi = $dbh->prepare("insert into full (host, port, time, ip) values (?, ?, ?, ?)");
my $sthyi = $dbh->prepare("insert into yp (host, port, time, yphost, action, status) values (?, ?, ?, ?, ?, ?)");
my $sthsi = $dbh->prepare("insert into streamsavers (host, port, time, ip) values (?, ?, ?, ?)");
my $numrecords=0;
my (%starttimes, %ips, %agents);
my %currentagents;
my $rslc=0; # records since last commit
my $sth = $dbh->prepare("select agent, rowid from agents");
$sth->execute;
while (my($a, $r) = $sth->fetchrow_array) { $currentagents{$a} = $r; }
$sth = $dbh->prepare("select line from lastlines where host = ? and port = ?");
$sth->execute($host, $port);
my $lastline = $sth->fetchrow_array;
my $process=0;
if (defined $lastline) {
my $lastlinefile = `tail -n 1 $logfile`;
chomp($lastlinefile);
if ($lastline eq $lastlinefile) {
debug("No entries to add.");
$sth->finish;
$dbh->disconnect;
exit;
}
else {
$process = 0;
debug("Continuing from previous run.\n");
}
}
else {
$process = 1;
}
open(FIN, "<$logfile") or die("Can't open log $logfile: $!\n");
open(FOUT, ">unmatched.txt") or die("Can't open unmatched.txt: $!");
while (<FIN>) {
my $line = $_;
chomp($line);
$lastline=$line if $process == 1;
if ($line =~ m/^.*starting stream.*$/) {
$line =~ /^<(\d\d)\/(\d\d)\/(\d\d)\@(\d\d):(\d\d):(\d\d).* (\d+\.\d+\.\d+\.\d+)\].*UID: (\d+)\).*\{A: (.*)\}/;
my ($mon, $day, $year, $hour, $min, $sec, $ip, $uid, $agent) = ($1, $2, $3, $4, $5, $6, $7, $8, $9);
$mon-=1; # months in log are 1-12 and function needs 0-11
$starttimes{$uid} = timelocal($sec, $min, $hour, $day, $mon, $year);
$ips{$uid} = $ip;
$agents{$uid} = $agent;
}
elsif ($line =~ /^.*connection closed.*UID:/) {
# we only need to process this line if we're adding records
if ($process == 1) {
$line =~ /^.*\((\d+) seconds\).*UID: (\d+)\).*Bytes: (\d+)\}/;
my ($consecs, $uid, $conbytes) = ($1, $2, $3);
if (not defined $starttimes{$uid}) {
debug("Start information for $uid not found. Skipping.");
}
else {
my $endtime = $starttimes{$uid}+$consecs;
my $agent = $agents{$uid};
my $agentid=$currentagents{$agent};
if (not defined $agentid) {
#debug("Inserting agent $agents{$uid} for UID $uid");
$sthai->execute($agents{$uid});
#debug("Insert successful.");
$numrecords+=1;
$rslc+=1;
$sthac->execute($agents{$uid});
$agentid = $sthac->fetchrow_array;
#debug("New ID for that agent is $agentid.");
$currentagents{$agent} = $agentid;
}
my $dtss = local_epoch_to_utc_string($starttimes{$uid});
my $dtes = local_epoch_to_utc_string($endtime);
$sthli->execute($host, $port, $dtss, $consecs, $dtes, $agentid, $ips{$uid}, $conbytes);
$numrecords+=1;
$rslc+=1;
} # else
} # process
} # if
elsif ($line =~ /^.*redirecting to backup.*$/) {
$line =~ /^<(\d\d)\/(\d\d)\/(\d\d)\@(\d\d):(\d\d):(\d\d).*dest: (.*)\].*backup (.*):(.*)$/;
my ($mon, $day, $year, $hour, $min, $sec, $ip, $backupip, $backupport) = ($1, $2, $3, $4, $5, $6, $7, $8, $9);
$year += 2000; # year must be four-digits and is two-digits in file
my $time = DateTime->new(second => $sec, minute => $min, hour => $hour, day => $day, month => $mon, year => $year, time_zone => 'US/Eastern');
$time->set_time_zone('UTC');
$time = sprintf("%04d%02d%02d%02d%02d%02d", $time->year, $time->month, $time->day, $time->hour, $time->minute, $time->second);
if ($process == 1) {
$sthbi->execute($host, $port, $ip, $time, $backupip, $backupport);
$numrecords+=1;
$rslc+=1;
}
}
elsif ($line =~ /Stream savers not allowed/) {
$line =~ /^<(\d\d)\/(\d\d)\/(\d\d)\@(\d\d):(\d\d):(\d\d).*\[dest: (.*)\]/;
my ($mon, $day, $year, $hour, $min, $sec, $ip) = ($1, $2, $3, $4, $5, $6, $7);
$year += 2000; # year must be four-digits and is two-digits in file
my $time = DateTime->new(second => $sec, minute => $min, hour => $hour, day => $day, month => $mon, year => $year, time_zone => 'US/Eastern');
$time->set_time_zone('UTC');
$time = sprintf("%04d%02d%02d%02d%02d%02d", $time->year, $time->month, $time->day, $time->hour, $time->minute, $time->second);
if ($process == 1) {
$sthsi->execute($host, $port, $time, $ip);
$numrecords+=1;
$rslc+=1;
}
}
elsif ($line =~ /\[(yp_add)|(yp_rem)|(yp_tch)\]/) {
$line =~ /^<(\d\d)\/(\d\d)\/(\d\d)\@(\d\d):(\d\d):(\d\d).*\[(.*)\] (.*)$/;
my ($mon, $day, $year, $hour, $min, $sec, $ypaction, $ypstatus) = ($1, $2, $3, $4, $5, $6, $7, $8, $9);
my $yphost = 'unknown';
$yphost = $1 if ($ypstatus =~ /^(.*?\..*?) /);
my $action = 'unknown';
$action = 'add' if $ypaction eq 'yp_add';
$action = 'remove' if $ypaction eq 'yp_rem';
$action = 'touch' if $ypaction eq 'yp_tch';
my $status = 'unknown';
$status = 'error' if $ypstatus =~ /error/;
$status = 'success' if $ypstatus =~ /touched/;
$status = 'success' if $ypaction eq 'yp_rem';
$status = 'success' if $ypstatus =~ /success/;
$year += 2000; # year must be four-digits and is two-digits in file
my $time = DateTime->new(second => $sec, minute => $min, hour => $hour, day => $day, month => $mon, year => $year, time_zone => 'US/Eastern');
$time->set_time_zone('UTC');
$time = sprintf("%04d%02d%02d%02d%02d%02d", $time->year, $time->month, $time->day, $time->hour, $time->minute, $time->second);
if ($process == 1) {
# add to database unless action and status are still unknown
$sthyi->execute($host, $port, $time, $yphost, $action, $status) unless $action eq 'unknown' and $status eq 'unknown';
$numrecords+=1;
$rslc+=1;
}
}
elsif ($line =~ /^.*service full\, disconnecting.*$/) {
$line =~ /^<(\d\d)\/(\d\d)\/(\d\d)\@(\d\d):(\d\d):(\d\d).*dest: (.*)\]/;
my ($mon, $day, $year, $hour, $min, $sec, $ip) = ($1, $2, $3, $4, $5, $6, $7);
$year += 2000; # year must be four-digits and is two-digits in file
my $time = DateTime->new(second => $sec, minute => $min, hour => $hour, day => $day, month => $mon, year => $year, time_zone => 'US/Eastern');
$time->set_time_zone('UTC');
$time = sprintf("%04d%02d%02d%02d%02d%02d", $time->year, $time->month, $time->day, $time->hour, $time->minute, $time->second);
if ($process == 1) {
$sthfi->execute($host, $port, $time, $ip);
$numrecords+=1;
$rslc+=1;
}
}
elsif ($line =~ /^.*server unavailable.*$/) {
$line =~ /^<(\d\d)\/(\d\d)\/(\d\d)\@(\d\d):(\d\d):(\d\d).*dest: (.*)\]/;
my ($mon, $day, $year, $hour, $min, $sec, $ip) = ($1, $2, $3, $4, $5, $6, $7);
$year += 2000; # year must be four-digits and is two-digits in file
my $time = DateTime->new(second => $sec, minute => $min, hour => $hour, day => $day, month => $mon, year => $year, time_zone => 'US/Eastern');
$time->set_time_zone('UTC');
$time = sprintf("%04d%02d%02d%02d%02d%02d", $time->year, $time->month, $time->day, $time->hour, $time->minute, $time->second);
if ($process == 1) {
$sthui->execute($host, $port, $time, $ip);
$numrecords+=1;
$rslc+=1;
}
}
else { print FOUT ("$line\n"); }
if ($rslc == 20000) {
debug("Records added so far: $numrecords. Commiting.\n");
$dbh->commit;
$sth = $dbh->prepare("select count(line) from lastlines where host = ? and port = ?");
$sth->execute($host, $port);
my $c = $sth->fetchrow_array;
if ($c == 0) {
$sth = $dbh->prepare("insert into lastlines (line, host, port) values (?, ?, ?)");
}
else {
$sth = $dbh->prepare("update lastlines set line = ? where host = ? and port = ?");
}
$sth->execute($lastline, $host, $port);
$dbh->commit;
$rslc=0;
}
if ($process == 0 && $line eq $lastline) {
debug("Found previous mark.\n");
$process = 1;
}
}
close FIN;
close FOUT;
$sth = $dbh->prepare("select count(line) from lastlines where host = ? and port = ?");
$sth->execute($host, $port);
my $c = $sth->fetchrow_array;
if ($c == 0) {
$sth = $dbh->prepare("insert into lastlines (line, host, port) values (?, ?, ?)");
}
else {
$sth = $dbh->prepare("update lastlines set line = ? where host = ? and port = ?");
}
$sth->execute($lastline, $host, $port);
$dbh->commit; # commit any pending records
$sth->finish;
$sthli->finish;
$sthac->finish;
$sthai->finish;
$sthbi->finish;
$sthui->finish;
$sthfi->finish;
$dbh->disconnect;
debug("Added $numrecords records to database.\n");

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

sub local_epoch_to_utc_string {
my $epoch = shift;
my $dt = DateTime->from_epoch(epoch => $epoch, time_zone => $tz);
$dt->set_time_zone("UTC");
return sprintf("%04d%02d%02d%02d%02d%02d", $dt->year, $dt->month, $dt->day, $dt->hour, $dt->minute, $dt->second);
}

