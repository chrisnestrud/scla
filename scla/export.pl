#!/user/bin/perl -w
# export - export necessary data into smaller database
# external database can be copied to system and used for data collection
# it can then be imported back into larger db using import.pl
use strict;
die("Usage: $0 Current.db New.db\n") unless $#ARGV == 1;
my($current, $new) = @ARGV;
die("Error: $current doesn't exist\n") unless (-f $current);
die("Error: $new is an existing file\n") if (-f $new);
use DBI;
our $DBI;
my $dbhc = DBI->connect("DBI:SQLite:dbname=" . $current,"","", {RaiseError => 1, AutoCommit => 0 }) or die "Error connecting to DB. " . $DBI->errstr;
my $dbhn = DBI->connect("DBI:SQLite:dbname=" . $new,"","", {RaiseError => 1, AutoCommit => 0 }) or die "Error connecting to DB. " . $DBI->errstr;
my $sthcag = $dbhc->prepare("select agent from agents order by rowid");
my $sthnai = $dbhn->prepare("insert into agents (agent) values (?)");
my @queries;
push(@queries, 'create table agents(agent);');
push(@queries, 'create table backups (host, port integer, time integer,ip,  backupip, backupport integer);');
push(@queries, 'create table full (host, port integer, ip, time integer);');
push(@queries, 'create table hosts (ip primary key, hostname, lastcheck integer);');
push(@queries, 'create table lastlines (host, port integer, line);');
push(@queries, 'create table listeners (host, port integer, starttime integer, time integer, endtime integer, agentid integer, ip, bytes integer);');
push(@queries, 'create table unavailable (host, port integer, ip, time integer);');
push(@queries, 'create table streamsavers (host, port integer, time integer, ip)');
push(@queries, 'create table yp (host, port integer, time integer,
action, yphost, status)');
for(@queries) {
my $query = $_;
my $sth = $dbhn->prepare($query);
$sth->execute;
}
$dbhn->commit;
# populate agents table
$sthcag->execute;
while (my($agent) = $sthcag->fetchrow_array) {
$sthnai->execute($agent);
}
$dbhn->commit;
$dbhn->commit;
$sthcag->finish;
$sthnai->finish;
$dbhc->disconnect;
$dbhn->disconnect;
print("New database generated as $new.\n");

