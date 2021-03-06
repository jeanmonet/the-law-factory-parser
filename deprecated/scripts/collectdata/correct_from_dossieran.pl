#!/usr/bin/perl

use WWW::Mechanize;
use utf8;
use strict;

my $debug = shift();

my $procedure = {};
my $i = 0;
my @row;
my @STDIN = <STDIN>;
foreach my $stdin (@STDIN) {
	@row = split(/;/, $stdin);
	next unless ($#row > 10);
        chomp($row[$#row]);
	@{$procedure->{$row[6]}} = @row;
}

if (($#{$procedure->{'00'}} > -1) && (!$procedure->{'00'}[4] || !$procedure->{'00'}[3])) {
	print STDERR "WARNING: no dossier AN found, skipping corrector\n";
	print join('', @STDIN);
	exit(0);
}

my $url = "http://www.assemblee-nationale.fr/".$procedure->{'00'}[3]."/dossiers/".$procedure->{'00'}[4].".asp";
print STDERR "DEBUG: dossier an : $url\n" if ($debug);
my $a = WWW::Mechanize->new();
$a->get($url);
my $content = $a->content;
utf8::encode($content);

my %mois = ('janvier'=>'01', 'fvrier'=>'02', 'mars'=>'03', 'avril'=>'04', 'mai'=>'05', 'juin'=>'06', 'juillet'=>'07', 'aot'=>'08', 'septembre'=>'09','octobre'=>'10','novembre'=>'11','dcembre'=>'12');
my @steps = ();
my $section; my $chambre; my $stade; my $date; my $mindate = '99999999'; my $maxdate; my $hasetape = 0; my $canparse = 0;
foreach (split(/\n/, $content)) {
    s/\r//g;
    s/mis en ligne le \d+ \S+//;
    if (/<hr>.*Loi/) {
	$canparse = 0;
	if (/organique/i && $procedure->{'00'}[1] =~ /organique/i) {
	    $canparse = 1;
	}elsif (!/organique/i && $procedure->{'00'}[1] !~ /organique/i) {
	    $canparse = 1;
	}
    }
    unless ($canparse) {
	next;
    }
    if (s/.*<a name="(ETAPE[^"]+)">((<a[^>]+>|<i>|<\/i>|<br\/?>|<\/a>|<sup>|<\/sup>|<\/font>|<\/b>|[^>])+)<\/p>(.*)//) {
	print STDERR "DEBUG: Étape tag : $1\n" if ($debug);
	$section = $2;
	$hasetape = 1;
	$section =~ s/<[^>]+>//g;
	$date = '';
	$mindate = '99999999';
	$maxdate = '';
	if ($section =~ /assembl..?e nationale/i) {
	    $chambre = "assemblee";
	}elsif($section =~ /s..?nat/i) {
	    $chambre = "senat";
	}elsif($section =~ /(CMP|Commission Mixte Paritaire)/i) {
	    $chambre = 'CMP';
	}
	$stade = 'depot';
    }elsif(/<b>/) {
	if (/publique/i) {
	    $stade = "hemicycle";
	}elsif (/commission/i) {
	    $stade = "commission";
	}
    }elsif(!/nomm..? |nomination/i && / (\d+) (janvier|f..?vrier|mars|avril|mai|juin|juillet|ao..?t|septembre|octobre|novembre|d..?cembre) (20\d+)/ && $chambre && $stade && !$date) {
	my $annee = $3; my $mois = $2; my $jour = sprintf('%02d', $1);
	lc($mois);
	$mois =~ s/[^a-z]+//i;
	$date = "$annee-".$mois{$mois}."-$jour";
    }
    if($hasetape && / (\d+) (janvier|f..?vrier|mars|avril|mai|juin|juillet|ao..?t|septembre|octobre|novembre|d..?cembre) (20\d+)/) {
	my $annee = $3; my $mois = $2; my $jour = sprintf('%02d', $1);
	lc($mois);
	$mois =~ s/[^a-z]+//i;
	my $adate = "$annee-".$mois{$mois}."-$jour";
	$mindate = $adate if (join('', split(/-/, $mindate)) > join('', split(/-/, $adate)));
	$maxdate = $adate if (join('', split(/-/, $maxdate)) < join('', split(/-/, $adate)));
    }
    if(/"([^"]+\/(projets|ta-commission|ta)\/[^"\-]+(|-a0).asp)"/ || /"(http:\/\/www.senat.fr\/leg[^\"]+)"/ || (!/ta-commission/ && !$url && /"([^"]+\/(rapports)\/[^"\-]+(|-a0).asp)"/) || (!/"http:\/\/www.senat.fr\/leg/ && /"(http:\/\/www.senat.fr\/rap[^\"]+)"/)) {
	$url = $1;
	if ($url !~ /^http/) {
	    $url = 'http://www.assemblee-nationale.fr'.$url;
	}
	$mindate = '' if ($mindate eq '99999999');
	my $pchambre = $chambre;
	if ($chambre eq 'CMP') {
	    if ($stade eq 'hemicycle') {
		if ($url =~ /senat/) {
		    $pchambre = "senat";
		}else{
		    $pchambre = 'assemblee';
		}
	    }elsif($stade eq 'depot') {
		$stade = 'commission';
	    }
	    if ($stade eq 'commission') {
		$mindate =~ s/-//g;
		$maxdate =~ s/-//g;
		my $diff = $maxdate - $mindate;
		$mindate =~ s/(\d{4})(\d{2})(\d{2})/\1-\2-\3/;
		$maxdate =~ s/(\d{4})(\d{2})(\d{2})/\1-\2-\3/;
		if (($diff) > 1000 ) {
		    print STDERR "DEBUG: the period between mindate and maxdate is too long for a CMP, choose maxdate\n" if ($debug);
		    $date = $maxdate;
		    $mindate = $maxdate;
		}
	    }
	}
	push @steps, "$pchambre;$stade;$date;$mindate;$maxdate;$url;$chambre" if ($stade && $steps[$#steps] !~ /$pchambre;$stade/);
#	print STDERR  "INFO: $pchambre;$stade;$date;$mindate;$maxdate;$url\n" if ($stade);
	$stade = '';
	$date = '';
	$mindate = '99999999';
	$maxdate = '';
    }
}

if ($debug) {
    foreach my $s (@steps) {
	print STDERR "DEBUG: $s\n";
    }
}

my $i = 0;
my $stepadded = 0;
my @pkeys = keys %{$procedure};
my $lasty;
foreach my $y (sort  @pkeys) {
    my $stepfound = 0;
    my @step = split(/;/, $steps[$i]);
    print STDERR "DEBUG: ".$steps[$i]." =~ /".$procedure->{$y}[9].";".$procedure->{$y}[10]."\n" if ($debug);
    if ($steps[$i] =~ /$procedure->{$y}[9];$procedure->{$y}[10];/) {
	$stepfound = 1;
    }elsif ($steps[$i+1] =~ /$procedure->{$y}[9];$procedure->{$y}[10];/ &&
     !($procedure->{$lasty}[10] eq "commission" && $step[1] eq "commission" && $step[5] =~ /\/rap\//)) {
	print STDERR "WARNING: Step missing : $steps[$i] (1)\n";
	@{$procedure->{$lasty.$i}} = @{$procedure->{$lasty}};
	$procedure->{$lasty.$i}[13] = $step[3];
	$procedure->{$lasty.$i}[14] = $step[4];
	$procedure->{$lasty.$i}[9]  = $step[0];
	$procedure->{$lasty.$i}[10] = $step[1];
	$procedure->{$lasty.$i}[6] = $lasty.$i;
	$procedure->{$lasty.$i}[11] = $step[5];
	$stepadded = 1;
	$i++;
	$stepfound = 1;
    }
    if ($stepfound) {
	print STDERR "DEBUG: step found ($i)\n" if ($debug);
	my @step = split(/;/, $steps[$i]);
	$i++;
	$lasty = $y;
	if ($step[1] ne 'depot') {
	    if (!($procedure->{$y}[13]) && $step[2]) {
		$procedure->{$y}[13] = $step[2];
	    }
	    if (!($procedure->{$y}[13]) && $step[3]) {
		$procedure->{$y}[13] = $step[3];
	    }
	    if (!($procedure->{$y}[14]) && $step[4]) {
		$procedure->{$y}[14] = $step[4];
	    }
	    #If min date doesn't match the beginning one & if min date fits with the previous ones
	    if (($y+0) && ($step[3] ne $procedure->{$y}[13]) && (join('', split(/-/, $step[3])) >= join('', split(/-/, $procedure->{sprintf("%02d", $y-1)}[14])))) {
		$procedure->{$y}[13] = $step[3];
	    }

	    #if max date doesn't match the ending one & max date fits with the following one (if set)
	    if ($step[4] && ($step[4] ne $procedure->{$y}[14]) && (join('',split(/-/, $step[4])) >= join('',split(/-/,$procedure->{$y}[13]))) &&  (!$procedure->{sprintf('%02d', $y+1)}[13] || (join('',split(/-/, $step[4])) <= join('',split(/-/,$procedure->{sprintf('%02d', $y+1)}[13]))))) {
		$procedure->{$y}[14] = $step[4];
	    }
#	    my $diff = join('', split(/-/, $step[3])) - join('', split(/-/, $procedure->{$y}[13]));
#	    print STDERR "WARNING: diff begin: $diff ($step[3] / ". $procedure->{$y}[13]." / $step[2])".$procedure->{$y}[8].";".$procedure->{$y}[9].";".$procedure->{$y}[10]."\n";
#
#	    $diff = join('', split(/-/, $step[4])) - join('', split(/-/, $procedure->{$y}[14]));
#	    print STDERR "WARNING: diff end: $diff  ($step[4] / ". $procedure->{$y}[14].")".$procedure->{$y}[8].";".$procedure->{$y}[9].";".$procedure->{$y}[10]."\n";
	}
    }
    if (($procedure->{$y}[10] eq 'depot') && $procedure->{$y}[14]) {
	$procedure->{$y}[13] = $procedure->{$y}[14];
    }
    if (!($procedure->{$y}[13]) && $procedure->{$y}[14]) {
	print STDERR "WARNING: begining date missing ".$procedure->{$y}[8].";".$procedure->{$y}[9].";".$procedure->{$y}[10]." => use ending date\n" unless ($procedure->{$y}[13]);
	$procedure->{$y}[13] = $procedure->{$y}[14]
    }
    if ($y+0) {
	my $curbegdate = $procedure->{$y}[13]; $curbegdate =~ s/-//g;
	my $prevenddate = $procedure->{sprintf('%02d', $y-1)}[14]; $prevenddate =~ s/-//g;
	my $curenddate = $procedure->{$y}[14]; $curenddate =~ s/-//g;
	print STDERR "WARNING: begining date ($curbegdate) should not later than the ending date ($curenddate) ".$procedure->{$y}[8].";".$procedure->{$y}[9].";".$procedure->{$y}[10]."\n" if ($curbegdate > $curenddate && $curbegdate && $curenddate && ($procedure->{$y}[6]+0));
	if ($curbegdate < $prevenddate && $curbegdate && $prevenddate && ($procedure->{$y}[6]+0)) {
	    $procedure->{$y}[13] = $procedure->{sprintf('%02d', $y-1)}[14];
	    print STDERR "WARNING: begining date ($curbegdate) should not earlier than the ending date ($prevenddate) of the previous step ".$procedure->{$y}[8].";".$procedure->{$y}[9].";".$procedure->{$y}[10]." => REWRITE IT\n";
	}
    }
}

for (my $y = $i ; $y <= $#steps ; $y++) {
  my @step = split(/;/, $steps[$y]);
  if (!($procedure->{$lasty}[10] eq "commission" && $step[1] eq "commission" && $step[5] =~ /\/rap\//)) {
    print STDERR "WARNING: step missing : ".$steps[$y]." (2)\n";
    @{$procedure->{$lasty.$y}} = @{$procedure->{$lasty}};
    $procedure->{$lasty.$y}[13] = $step[3];
    $procedure->{$lasty.$y}[14] = $step[4];
    $procedure->{$lasty.$y}[9]  = $step[0];
    $procedure->{$lasty.$y}[10] = $step[1];
    $procedure->{$lasty.$y}[6] = $lasty.$y;
    $procedure->{$lasty.$y}[11] = $step[5];
    $stepadded = 1;
  }
}

my $nbstep = 0;
my $nbline = 0;
my %nbstep ;
my $cmpfirstpassed = 0;
foreach my $y (sort keys %{$procedure}) {
    #For "lecture definitive" in commission, no need of bill url
    if (($procedure->{$y}[8] =~ /finitive/) && ($procedure->{$y}[10] eq 'commission')) {
	next;
    }
    if ($stepadded) {
	$nbline++ unless ($procedure->{$y}[8] eq 'CMP' && $procedure->{$y}[10] eq 'hemicycle');
	if ($procedure->{$y}[8] eq 'CMP' && $procedure->{$y}[10] eq 'hemicycle' && !$cmpfirstpassed) {
	    $nbline++ ;
	    $cmpfirstpassed = 1;
	}
	$procedure->{$y}[6] = sprintf('%02d', $nbstep++) if ($procedure->{$y}[6] ne 'XX');
	$procedure->{$y}[7] = $nbline if ($procedure->{$y}[7] + 0);
    }
    #Hack grenel (pjl08-155)
    $procedure->{$y}[11] =~ s/l09-5672/l09-5671/;
    print join(';', @{$procedure->{$y}})."\n";
}
