#!/usr/bin/perl -w
use strict;
use DBI;
our $DBI;
use IP::Country::Fast;
my $reg = IP::Country::Fast->new();
use Geography::Countries;
my $st = time();
die("Usage: $0 database host port YYYYMM\n") unless $#ARGV == 3;
my ($database, $host, $port, $date) = @ARGV;
die("Error: database $database not found\n") unless (-f $database);
my $dbh = DBI->connect("DBI:SQLite:dbname=" . $database,"","", {AutoCommit => 1, RaiseError => 1 }) or die ("Error connecting to DB: $!\n");
my $sth; # statement handle
die("Error: date not in correct YYYYMM format\n") unless $date =~ /^\d{6}$/;
$date =~ /^(\d{4})(\d{2})$/;
my($year, $month) = ($1, int $2);
my $starttime = sprintf("%04d%02d00000000", $year, $month);
my $endtime = sprintf("%04d%02d31235959", $year, $month);
my %months = (1 => 'January', 2 => 'February', 3 => 'March', 4 => 'April', 5 => 'May', 6 => 'June', 7 => 'July', 8 => 'August', 9 => 'September', 10 => 'October', 11 => 'November', 12 => 'December');
debug("Generating statistics for $host:$port for the month of $months{$month} $year");
my $hostdash = $host;
$hostdash =~ s/\./-/g;
my $fname = sprintf("stats_%s_%s_%02d-%04d.html", $hostdash, $port, $month, $year);
open(FOUT, ">$fname") or die("Error: can not create stats file: $!\n");
print FOUT '<html><head><title>Stream Madness - statistics for ' .  $host . ':' . $port . ' for the month of ' . $months{$month} . ' ' .  $year . '</title>';
print FOUT '</head><body>';
print FOUT '<p>Following are statistics for your server on ' . $host . ' port ' . $port . ' for the month of ' . $months{$month} . ' ' . $year . '. If you have any questions, or would like to discuss the provision of additional statistics, please email <a href="mailto:support@streammadness.com">support@streammadness.com</a>.</p>';
print FOUT '<h1>Totals</h1><table summary="Monthly Totals"><th>Statistic</th><th>Value</th>';
# totals
debug("Calculating totals");
$sth = $dbh->prepare("select count(*) from listeners where host = ? and port = ? and starttime >= ? and endtime <= ?");
$sth->execute($host, $port, $starttime, $endtime);
my $listenertotal = $sth->fetchrow_array;
if ($listenertotal == 0) {
close FOUT;
debug("Listener total was 0. Removing stats file.");
unlink($fname) or die("Can't delete $fname: $!\n");
exit;
}
print FOUT '<tr><td>Total Individual Listeners</td><td>' . $listenertotal . '</td></tr>';
debug("Total listeners: $listenertotal");
unless ($listenertotal == 0) {
$sth = $dbh->prepare("select count(*) from listeners where time >= 300 and host = ? and port = ? and starttime >= ? and endtime <= ?");
$sth->execute($host, $port, $starttime, $endtime);
my $listenertotal5 = $sth->fetchrow_array;
print FOUT '<tr><td>Individual listeners connected for at least five minutes</td><td>' . $listenertotal5 . ' (' .  sprintf("%.2f", $listenertotal5/$listenertotal*100) . '%)</td></tr>';
debug('Five minutes: ' . $listenertotal5 . ' (' . sprintf("%.2f", ($listenertotal5/$listenertotal*100)) . '%)');
}
$sth = $dbh->prepare("select sum(bytes) from listeners where host = ? and port = ? and starttime >= ? and endtime <= ?");
$sth->execute($host, $port, $starttime, $endtime);
my $bytes = $sth->fetchrow_array;
my $bytesstr;
if ($bytes > 1000000000) { $bytesstr = sprintf("%0.3f gb", ($bytes/(1048576*1000))); }
elsif ($bytes > 1000000) { $bytesstr = sprintf("%0.2f mb", ($bytes/1048576)); }
else { $bytesstr = sprintf("%d bytes", $bytes); }
print FOUT '<tr><td>Bytes Transfered</td><td>' . $bytesstr . '</td></tr>';
debug("Bytes transfered: $bytesstr");
$sth = $dbh->prepare("select sum(time) from listeners where host = ? and port = ? and starttime >= ? and endtime <= ?");
$sth->execute($host, $port, $starttime, $endtime);
my $ttsl = $sth->fetchrow_array;
my $ttslstr = int($ttsl/60/60) . " hours (";
my $ttsly = int $ttsl/60/60/24/365;
$ttsl -= $ttsly*60*60*24*365;
my $ttsld = int $ttsl/60/60/24;
$ttsl -= $ttsld*24*60*60;
my $ttslh = int $ttsl/60/60;
$ttsl -= $ttslh*60*60;
my $ttslm = int $ttsl/60;
$ttsl -= $ttslm*60;
$ttslstr .= "$ttsly years, " unless $ttsly == 0;
$ttslstr .= "$ttsld days, " unless $ttsld == 0;
$ttslstr .= "$ttslh hours, " unless $ttslh == 0;
$ttslstr .= "$ttslm minutes, " unless $ttslm == 0;
$ttslstr .= "$ttsl seconds";
$ttslstr .= ')';
print FOUT '<tr><td>Total Time Spent Listening (TTSL)</td><td>' . $ttslstr . '</td></tr>';
debug("TTSL: $ttslstr");
print FOUT '</table>';
print FOUT '<h1>Agents</h1><table summary="Top Agents"><th>Agent</th><th>Individual Listeners</th><th>Percentage of Total</th>';
$sth = $dbh->prepare("select agents.agent, count(listeners.agentid) as c from agents, listeners where listeners.agentid = agents.rowid and listeners.host = ? and listeners.port = ? and listeners.starttime >= ? and listeners.endtime <= ? group by agents.agent order by c desc limit 20");
debug("Getting agents");
$sth->execute($host, $port, $starttime, $endtime);
debug("Processing agents");
while (my($a, $count) = $sth->fetchrow_array) { 
$a = 'Unspecified' if $a eq '';
my $p = sprintf("%0.2f", ($count/$listenertotal*100));
print FOUT '<tr><td>' . $a . '</td><td>' . $count . '</td><td>' . $p . '%</td></tr>';
debug('Agent ' . $a . ' with ' . $count . ' (' . $p . '%)');
}
print FOUT '</table>';
print FOUT '<h1>Countries</h1><table summary="Top Countries"><th>Country</th><th>Individual Listeners</th><th>Percentage</th>';
my %ccs;
$sth = $dbh->prepare("select ip from listeners where host = ? and port = ? and starttime >= ? and starttime <= ?");
my $cc; # country code
debug("Getting countries");
$sth->execute($host, $port, $starttime, $endtime);
while(my($ip) = $sth->fetchrow_array) {
$cc = $reg->inet_atocc($ip) or $cc = "**";
$ccs{$cc}+=1;
}
my @sorted = sort({ $ccs{$a} <=> $ccs{$b} } keys %ccs);
my $totalccs = $#sorted+1;
$totalccs = 20 if $totalccs > 20;
for(1..$totalccs) {
my $cc = pop(@sorted);
my $country;
$country =country($cc) or $country = 'Unknown (' . $cc . ')';
$country = "Unknown" if ($cc eq '**');
$country = 'European Union' if ($cc eq 'EU');
my $count = $ccs{$cc};
my $p = sprintf("%0.2f", ($count/$listenertotal*100));
print FOUT '<tr><td>' . $country . '</td><td>' . $count . '</td><td>' . $p . '%</td></tr>';
debug("Country $country had $count listeners ($p%)");
}
print FOUT '</table>';
print FOUT '<h1>Selected Domains</h1><table summary="Selected
Domains"><th>Domain</th><th>Individual Listeners</th><th>Percentage of
Total</th>';
my %domainnames = ('%.edu' => 'U.S. Educational', '%.gov' => 'U.S.  Government', '%.mil' => 'U.S. Military');
my %domains;
$sth = $dbh->prepare("select count(*) from listeners, hosts where listeners.host = ? and listeners.port = ? and listeners.starttime >= ?
and listeners.endtime <= ? and listeners.ip = hosts.ip and hosts.hostname like ?");
for(keys %domainnames) {
my $domain = $_;
$sth->execute($host, $port, $starttime, $endtime, $domain);
$domains{$domain} = $sth->fetchrow_array;
}
@sorted = sort({ $domains{$a} <=> $domains{$b} } keys %domains);
my $totaldomains = $#sorted+1;
$totaldomains = 20 if ($totaldomains > 20);
for(1..$totaldomains) {
my $dom = pop(@sorted);
my $count = $domains{$dom};
my $p = sprintf("%0.2f", ($count/$listenertotal*100));
print FOUT '<tr><td>' . $domainnames{$dom} . '</td><td>' . $count . '</td><td>' . $p . '%</td></tr>';
debug("Domain $domainnames{$dom} had $count listeners ($p%)");
}
print FOUT '</table>';
print FOUT '<p>These statistics are intended soally as a guide. Stream Madness does not warrant the validity of any information contained herein and disclaims all liability.</p>';
print FOUT '</body></html>';

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
