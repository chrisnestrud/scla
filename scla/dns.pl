#!/usr/bin/perl -w
# dns - add hostnames for ips that lack them
use strict;
use DBI;
use Net::DNS;
die("Usage: $0 dns.db\n") unless $#ARGV == 0;
my ($current) = @ARGV;
die("Error: Database $current not found.\n") unless ( -f $current);
my $st = time();
our $DBI;
my $dbhc = DBI->connect("DBI:SQLite:dbname=" . $current,"","", {AutoCommit => 0, RaiseError => 1 }) or die ("Error connecting to DB: $!\n");
debug("Connected.\n");
my $sthg = $dbhc->prepare("select distinct ip from ips where ip not in (select ip from hosts) and ip > ? order by ip");
my $sthi = $dbhc->prepare("insert into hosts (ip, hostname, lastcheck) values (?, ?, ?)");
my $sthlast = $dbhc->prepare("select ip from lastip");
my $numrecords=0;
my $res = Net::DNS::Resolver->new;
$res->persistent_udp(1);
my $sthc = $dbhc->prepare('select name from sqlite_master where type = "table"');
$sthc->execute;
my $counter=0;
while(my($table) = $sthc->fetchrow_array()) {
$counter+=1 if ($table eq 'ips' or $table eq 'hosts' or $table eq 'lastip');
}
die("Error: not all tables exist in $current: Was this created by dnsexport.pl?\n") unless $counter == 3;
$counter=0;
$sthlast->execute;
my $lastip = $sthlast->fetchrow_array;
die("This database has already been processed.\n") if $lastip eq '999.999.999.999';
debug("Last IP is $lastip");
$sthc = $dbhc->prepare("select count(ip) from ips where ip > ?");
$sthc->execute($lastip);
my $total = $sthc->fetchrow_array;
debug("A total of $total ips need to be processed.");
$sthg->execute($lastip);
debug("Received list of ips.\n");
my $ip;
while ($ip = $sthg->fetchrow_array) {
my $packet = $res->query($ip);
my $hostname = 'Unknown';
if (defined($packet)) {
for($packet->answer) { $hostname = $_->ptrdname if $_->type eq 'PTR'; }
}
# debug("inserting ip $ip hostname $hostname time $st");
$sthi->execute($ip, $hostname, $st);
$numrecords+=1;
if ($numrecords%100 == 0) {
updatelastip($ip);
$dbhc->commit;
my $percentage = sprintf("%.2f", ($numrecords/$total*100));
debug("Processed $numrecords records ($percentage%). Last IP was $ip.");
}
}
debug("Processed $numrecords records. Committing.");
updatelastip('999.999.999.999');
$dbhc->commit;
$sthc->finish;
$sthg->finish;
$sthi->finish;
$sthlast->finish;
$dbhc->disconnect;
$dbhc->disconnect;
debug("Processing complete. Import $current to add records.");

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

sub updatelastip {
my $lastip = shift;
my $sth = $dbhc->prepare("update lastip set ip = ?");
$sth->execute($lastip);
$sth->finish;
}

