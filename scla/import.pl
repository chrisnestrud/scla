#!/user/bin/perl -w
# import - import external database into larger database
use strict;
die("Usage: $0 Current.db New.db\n") unless $#ARGV == 1;
my $st = time();
my($current, $new) = @ARGV;
die("Error: $current doesn't exist\n") unless (-f $current);
die("Error: $new doesn't exist\n") unless (-f $new);
use DBI;
our $DBI;
my $dbhc = DBI->connect("DBI:SQLite:dbname=" . $current,"","", {RaiseError => 1, AutoCommit => 0 }) or die "Error connecting to DB. " . $DBI->errstr;
my $dbhn = DBI->connect("DBI:SQLite:dbname=" . $new,"","", {RaiseError => 1, AutoCommit => 1 }) or die "Error connecting to DB. " . $DBI->errstr;
my $sthc;
my $sthn;
my $sthcAgentCount = $dbhc->prepare("select count(*) from agents");
my $sthnAgentCount = $dbhn->prepare("select count(*) from agents");
my $sthnGetNewAgents = $dbhn->prepare("select agent from agents where rowid > ? order by rowid");
my $sthcInsertNewAgents = $dbhc->prepare("insert into agents (agent) values (?)");
my $sthnTables = $dbhn->prepare('select name from sqlite_master where type = "table" order by name');
$sthnTables->execute;
while(my($table) = $sthnTables->fetchrow_array()) {
&add_hosts if $table eq 'hosts';
&add_agents if $table eq 'agents';
&add_listeners if $table eq 'listeners';
&add_unavailable if $table eq 'unavailable';
&add_full if $table eq 'full';
&add_backups if $table eq 'backups';
&add_yp if $table eq 'yp';
&add_streamsavers if $table eq 'streamsavers';
}
debug("Additions complete.");
$sthn->finish;
$sthc->finish;
debug("Committing additions to current database.");
$dbhc->commit;
debug("Commit complete. Disconnecting.");
$dbhc->disconnect;
$dbhn->disconnect;
debug("Import complete.\n");

sub add_agents {
$sthcAgentCount->execute;
my $cAgentCount = $sthcAgentCount->fetchrow_array;
$sthnAgentCount->execute;
my $nAgentCount = $sthnAgentCount->fetchrow_array;
if ($nAgentCount > $cAgentCount) {
$sthnGetNewAgents->execute($cAgentCount);
my $added=0;
while (my($agent) = $sthnGetNewAgents->fetchrow_array) {
$sthcInsertNewAgents->execute($agent);
$added+=1;
}
debug("Added $added agents.\n");
}
$sthcAgentCount->finish;
$sthnAgentCount->finish;
$sthnGetNewAgents->finish;
$sthcInsertNewAgents->finish;
}

sub add_backups {
$sthn = $dbhn->prepare("select count(*) from backups");
$sthn->execute;
my $counter = $sthn->fetchrow_array;
if ($counter > 0) {
$sthn = $dbhn->prepare("select host, port, time, ip, backupip, backupport from backups");
$sthc = $dbhc->prepare("insert into backups (host, port, time, ip, backupip, backupport) values(?, ?, ?, ?, ?, ?)");
$sthn->execute;
my $added=0;
while(my($host, $port, $time, $ip, $backupip, $backupport) = $sthn->fetchrow_array) {
$sthc->execute($host, $port, $time, $ip, $backupip, $backupport);
$added+=1;
debug("Added $added backups") if ($added%20000 == 0);
}
debug("Added $added backups.\n");
}
}

sub add_full {
$sthn = $dbhn->prepare("select count(*) from full");
$sthn->execute;
my $counter = $sthn->fetchrow_array;
if ($counter > 0) {
$sthn = $dbhn->prepare("select host, port, ip, time from full");
$sthc = $dbhc->prepare("insert into full (host, port, ip, time) values (?, ?, ?, ?)");
$sthn->execute;
my $added=0;
while (my($host, $port, $ip, $time) = $sthn->fetchrow_array) {
$sthc->execute($host, $port, $ip, $time);
$added+=1;
debug("Added $added full") if ($added%20000 == 0);
}
debug("Added $added full.\n");
}
}

sub add_listeners {
$sthn = $dbhn->prepare("select count(*) from listeners");
$sthn->execute;
my $counter = $sthn->fetchrow_array;
if ($counter > 0) {
$sthn = $dbhn->prepare("select host, port, starttime, time, endtime, agentid, ip, bytes from listeners");
$sthc = $dbhc->prepare("insert into listeners (host, port, starttime, time, endtime, agentid, ip, bytes) values (?, ?, ?, ?, ?, ?, ?, ?)");
$sthn->execute;
my $added=0;
while(my($host, $port, $starttime, $time, $endtime, $agentid, $ip, $bytes) = $sthn->fetchrow_array) {
$sthc->execute($host, $port, $starttime, $time, $endtime, $agentid, $ip, $bytes);
$added+=1;
debug("Added $added listeners") if ($added%20000 == 0);
}
debug("Added $added listeners.\n");
}
}

sub add_unavailable {
$sthn = $dbhn->prepare("select count(*) from unavailable");
$sthn->execute;
my $counter = $sthn->fetchrow_array;
if ($counter > 0) {
$sthn = $dbhn->prepare("select host, port, ip, time from unavailable");
$sthc = $dbhc->prepare("insert into unavailable (host, port, ip, time) values (?, ?, ?, ?)");
$sthn->execute;
my $added=0;
while (my($host, $port, $ip, $time) = $sthn->fetchrow_array) {
$sthc->execute($host, $port, $ip, $time);
$added+=1;
debug("Added $added unavailable") if ($added%20000 == 0);
}
debug("Added $added unavailable.\n");
}
}

sub add_yp {
$sthn = $dbhn->prepare("select count(*) from yp");
$sthn->execute;
my $counter = $sthn->fetchrow_array;
if ($counter > 0) {
$sthn = $dbhn->prepare("select host, port, time, status, yphost, action from yp");
$sthc = $dbhc->prepare("insert into yp (host, port, time, status, yphost, action) values(?, ?, ?, ?, ?, ?)");
$sthn->execute;
my $added=0;
while (my($host, $port, $time, $status, $yphost, $action) = $sthn->fetchrow_array) {
$sthc->execute($host, $port, $time, $status, $yphost, $action);
$added+=1;
debug("Added $added yp") if ($added%20000 == 0);
}
debug("Added $added YP.\n");
}
}

sub add_streamsavers {
$sthn = $dbhn->prepare("select count(*) from streamsavers");
$sthn->execute;
my $counter = $sthn->fetchrow_array;
if ($counter > 0) {
$sthn = $dbhn->prepare("select host, port, time, ip from streamsavers");
$sthc = $dbhc->prepare("insert into streamsavers (host, port, time, ip) values (?, ?, ?, ?)");
$sthn->execute;
my $added=0;
while (my($host, $port, $time, $ip) = $sthn->fetchrow_array) {
$sthc->execute($host, $port, $time, $ip);
$added+=1;
debug("Added $added streamsavers") if ($added%20000 == 0);
}
debug("Added $added stream savers.\n");
}
}

sub add_hosts {
$sthn = $dbhn->prepare("select count(ip) from hosts");
$sthn->execute;
my $counter = $sthn->fetchrow_array;
if ($counter > 0) {
my $newips = $counter;
debug("Importing new hosts");
$sthc = $dbhc->prepare("select ip, lastcheck from hosts");
debug("Executing query.");
$sthc->execute;
debug("Loading hash.");
my %ips;
my $counter=0;
while(my($ip, $lastcheck) = $sthc->fetchrow_array()) {
$ips{$ip} = $lastcheck;
$counter+=1;
}
debug("Loaded $counter old ips into hash");
$sthn = $dbhn->prepare("select ip, hostname, lastcheck from hosts");
debug("Executing query");
$sthn->execute;
debug("Importing IPs which don't exist or have more recent lastcheck");
$sthc = $dbhc->prepare("insert into hosts (ip, hostname, lastcheck) values (?, ?, ?)");
$counter=0;
while(my($ip, $host, $lastcheck) = $sthn->fetchrow_array()) {
my $add=0;
if (defined($ips{$ip})) {
$add=1 if $lastcheck > $ips{$ip};
}
else {
$add=1;
}
if ($add == 1) {
$sthc->execute($ip, $host, $lastcheck);
$counter+=1;
}
debug("Added $counter ips") if ($counter%20000 == 0);
}
debug("Added $counter of $newips new IPs");
}
}

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
