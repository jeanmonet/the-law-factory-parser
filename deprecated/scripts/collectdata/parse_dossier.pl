#!/usr/bin/perl

use WWW::Mechanize;
use HTML::TokeParser;
use Data::Dumper;
use utf8;

$dossier_url = shift;
$debug = shift;
if ($dossier_url =~ /\/([^\/]+)\.html$/) {
	$dossiersenat = $1;
}

if (!$dossier_url) {
	print STDERR "USAGE: perl parse_dossier.pl <url dossier senat> <include header>\n";
	print STDERR "\n";
	print STDERR "Transforme les dossiers du sénat en un CSV qui contient les url des textes aux différentes étapes\n";
	exit 1;
}

%mois = ('janvier'=>'01', 'fvrier'=>'02', 'mars'=>'03', 'avril'=>'04', 'mai'=>'05', 'juin'=>'06', 'juillet'=>'07', 'aot'=>'08', 'septembre'=>'09','octobre'=>'10','novembre'=>'11','dcembre'=>'12');
$a = WWW::Mechanize->new();
$a->get($dossier_url);
print STDERR "Dossier $dossier_url downloaded\n" if($debug);
$content = $a->content;
$a2 = WWW::Mechanize->new(autocheck => 0);

$titrecourt = '';
$titrelong = '';
if ($content =~ /title>([^<]+)</) {
    $titrecourt = $1;
    $titrecourt =~ s/[-\s]*S[eé]nat(\.fr)?\s*$//i;
    utf8::encode($titrecourt);
}
if ($content =~ /Description" content="([^"]+)"/) {
    $titrelong = $1;
    utf8::encode($titrelong);
}
print "Titre found: $titrelong\n" if ($debug);

#If no link to the texte or rapport provided, fake one
$content =~ s/<a name="[^"]*"><\/a>//g;
$content =~ s/<li>Texte/<li><a href="UNKNOWN">Texte<\/a>/g;
$content =~ s/<li>Rapport/<li><a href="UNKNOWN">Texte<\/a>/g;

$legislature = "13";
if ($content =~ /nationale\.fr\/(\d+)\/dossier/) {
    $legislature = $1;
}

my %missing_dossieran = ('pjl11-497' => '14;accord_Serbie_cooperation_policiere', 'pjl10-511' => '13;accord_fiscal_Costa_Rica', 'pjl10-512' => '13;accord_fiscal_Liberia', 'pjl10-513' => '13;accord_fiscal_Brunei', 'pjl10-514' => '13;accord_fiscal_Belize', 'pjl10-515' => '13;accord_fiscal_Dominique', 'pjl10-516' => '13;accord_fiscal_Anguilla');
if ($missing_dossieran{$dossiersenat}) {
my @detailsan = split(/;/, $missing_dossieran{$dossiersenat});
    $legislature = $detailsan[0];
    $dossieran = $detailsan[1];
}

if ($content =~ /timeline-1[^>]*<em>(\d{2})\/(\d{2})\/(\d{2})<\/em>/) {
	print "date : $1/$2/$3\n";
}
@date=();
$p = HTML::TokeParser->new(\$content);
print STDERR "Begin caroussel\n" if ($debug);
while ($t = $p->get_tag('div')) {
    if ($t->[1]{id} =~ /block-timeline/) {
        $p->get_tag('ul');
	while (($t = $p->get_tag('li', '/ul')) &&  $t->[0] eq 'li') {
	    $t = $p->get_tag('a', '/ul');
	    print "a or /ul tag found: ".$t->[0]."\n" if ($debug);
            if ($t->[0] eq '/ul') {
                print STDERR "</ul> found : end of caroussel\n" if ($debug);
                last;
            }
	    if ($t->[1]{href} =~ /timeline-(\d+)/) {
		$id = $1;
		print STDERR "an id found: $id\n" if ($debug);
	    }
	    $t = $p->get_tag('em', '/ul');
	    if ($t->[0] eq '/ul') {
		print STDERR "</ul> found : end of caroussel\n" if ($debug);
		last;
	    }
	    $txt = $p->get_text('/em');
	    print "em txt found: $txt\n" if ($debug);
	    if ($txt =~ /(\d{2})\/(\d{2})\/(\d{2})/) {
		$date[$id] = '20'.$3.'-'.$2.'-'.$1;
		print STDERR "date found: ".$date[$id]."\n" if ($debug);
	    }
	}
    }
    if ($t->[1]{id} =~ /^timeline-(\d+)/) {
	print STDERR "an id found: $id\n" if ($debug);
	$id = $1;
	last;
    }
}

print STDERR "Step id DONE\n" if ($debug);

$date = $date[1];
$oldstade = "";
$ok = 1;
@lines = ();
while ($ok) {
    $t = $p->get_tag('em', 'img', 'a', 'div', 'h3');
    print STDERR "tag found: ".$t->[0]."\n" if ($debug);
    if($t->[0] eq 'em') {
	$etape = $p->get_text('/em');
	utf8::encode($etape);
	$etape =~ s/dfiniti/definiti/;
    }elsif($t->[0] eq 'img' && $t->[1]{src} =~ /picto_timeline_0([1234])_on.png/) {
	$img = $1;
	if ($img == 3) {
	    $stade = "commission";
	}elsif($img == 4) {
	    $stade = "hemicycle";
	}elsif ($img == 2) {
	    $chambre = "senat";
	    $stade = 'depot';
	}elsif($img == 1) {
	    $chambre = "assemblee";
	    $stade = 'depot';
	}
	print STDERR "step: $chambre $stade\n" if ($debug);
    }elsif($t->[0] eq 'a' && $t->[1]{href} !~ /^\#/) {
	if ($t->[1]{href} =~ /\/(\d+)\/dossiers\/([^\.]+)\./) {
		if ($1 !~ /_scr$/) {
			$dossieran = $2;
			$legislature = $1;
		}
	}
    $name = $p->get_text('/a');
    $url = $t->[1]{href};
    print STDERR "link detail: $name $url\n" if ($debug);
    if ($url !~ /\/motion/ && ($url =~ /\/leg\/p/ || $name =~ /Texte/ || ($name =~ /Rapport/ && ($url =~ /^\/rap\// || $url =~ /le.fr\/\d+\/rapports\/r\d+(-a0)?\./)) || $url =~ /(conseil-constitutionnel|legifrance)/)) {
	    $url = "http://www.senat.fr".$url if ($url =~ /^\//);
	    $url = "UNKNOWN" if ($url !~ /^http/);
	    $texte = $p->get_text('/li');
	    utf8::encode($texte);
        if ($name =~ /Rapport/ && $url =~ /\/rap\// && $texte !~ /commission mixte paritaire/i) {
            next;
        }
	    $enddate='';
	    if ($texte =~ / (\d+)e?r? (janvier|f..vrier|mars|avril|mai|juin|juillet|ao..t|septembre|octobre|novembre|d..cembre) (\d{4})/) {
		$jour=$1;$mois = $2;$annee=$3;$mois=~s/[^a-z]//g;
		$enddate = sprintf('%04d-%02d-%02d', $annee, $mois{$mois}, $jour);
		$enddate = '' if ($enddate !~ /^[12]\d{3}-[01]\d-[0123]\d/);
	    }
	    print STDERR "$dossier_url : ENDDATE NOT FOUND in $url : '$texte'\n" if (!$enddate && $texte);

        if ($texte =~ /par l'Assembl..?e nationale/) {
            $chambre = "assemblee";
        }
            $idtext = '';
	    $printid = $id;
	    if ($url =~ /legifrance/) {
		$url =~ s/;jsessionid=[^\?]*//;
		$url =~ s/&.*//;
		$etape = "promulgation";
		$chambre = 'gouvernement';
		$stade = 'JO';
		$printid = 'EXTRA';
		$enddate = $date[$id];
	    }elsif ($url =~ /conseil-constitutionnel/) {
		$url =~ s/#.*//;
		$etape = "constitutionnalité";
		utf8::encode($etape);
		$chambre = 'conseil constitutionnel';
		$stade = 'conforme';
		if ($texte =~ /\((.*)\)/) {
		    $stade = $1;
		}
		$printid = 'EXTRA';
		$enddate = $date[$id];
	    }elsif ($url =~ /assemblee-nationale/) {

		$chambre = 'assemblee' if ($stade eq 'hemicycle');
		if ($url =~ /fr\/(\d+)\/.*[^0-9]0*([1-9][0-9]*)(-a\d)?\.asp$/) {
			$legislature = $1;
			$idtext = $2;
		} elsif ($url =~ /\/dossiers\//) {
            $url = "UNKNOWN";
        }
            }elsif ($url =~ /senat.fr/) {
		$chambre = 'senat' if ($stade eq 'hemicycle');
		if ($url =~ /(\d{2})-(\d+)\.html$/) {
			$idtext='20'.$1.'20'.($1+1).'-'.$2;
            if ($url =~ /\/rap\// && $texte =~ /commission mixte paritaire/i) {
                $ct = 3;
                while ($ct > 0) {
                    $url2 = $url;
                    $url2 =~ s/\.htm/$ct.htm/;
                    $a2->get($url2);
                    if ($a2->success()) {
                        $url = $url2;
                        $ct = 0;
                    }
                    $ct--;
                }
            }
		}
            }
            if ($url eq 'UNKNOWN') {
		if ($texte =~ /n..\s*(\d+) / && $chambre eq 'assemblee') {
		    $num = $1;
		    if ($stade eq 'commission') {
			$url = sprintf("http://www.assemblee-nationale.fr/$legislature/ta-commission/r%04d-a0.asp", $num);
		    }elsif($stade eq 'depot'){
			$type = ppl;
			$type = pl if ($dossier_url =~ /pjl/);
			$url = sprintf("http://www.assemblee-nationale.fr/$legislature/projets/%s%04d.asp", $type, $num);
		    }else{
			$url = sprintf("http://www.assemblee-nationale.fr/$legislature/ta/ta%04d.asp", $num);
		    }
		} elsif ($texte =~ / renvo[iy].?.? en commission/) {
            $url = "renvoi en commission";
		} elsif ($texte =~ / retir..? par le/) {
            $url = "texte retire";
        } else {
            next;
        }
	    }
	    if ($chambre eq 'assemblee') {
		$date[$id] = '';
		if ($url =~ /\/rapports\/r/ && $enddate gt "2009-05-28") {
		    $url2 = $url;
		    $url2 =~ s/rapports(\/r\d+)\./ta-commission$1-a0\./;
		    $a2->get($url2);
		    if ($a2->success()) {
			$url = $url2;
		    }
            if ($etape =~ /l\.\s*d..?finitive/) {
                next;
            }
		} elsif ($url =~ /\/ta-commission\/r/) {
		    $a2->get($url);
		    if (!$a2->success() || $a2->content =~ />Cette division n'est pas encore distribuée</ || length($a2->content) < 15500) {
			$url2 = $url;
			$url2 =~ s/ta-commission(\/r\d+)-a0/rapports$1/;
			$a2->get($url2);
			if ($a2->success()) {
			    $url = $url2;
			}
		    }
		}
	    }
        if ($stade eq $oldstade and ($stade eq "commission" or ($idtext eq $oldidtext && $url eq $oldurl))) {
            pop(@lines);
        }
        $oldstade = $stade;
        $oldidtext = $idtext;
        $oldurl = $url;
	    $lines[$#lines+1] =  "$printid;$etape;$chambre;$stade;$url;$idtext;".$date[$id].";".$enddate;
	    $url = '';
	}
	if ($t->[1]{href} =~ /^mailto:/) {
	    last;
	}
    }elsif($t->[0] eq 'div' && $t->[1]{id} =~  /^timeline-(\d+)/) {
	$id = $1;
    }elsif($t->[0] eq 'h3' && $t->[1]{class} =~ /title/) {
	if ($p->get_text('/h3') =~ /mixte paritaire/) {
	    $chambre = 'CMP';
            $etape = 'CMP';
	}
    }elsif(!$t->[0]) {
	print STDERR "WARN: stopped (unrecognize tag '".$t->[0]."')\n";
	last;
    }
}

$cpt = 0;
print "dossier begining ; dossier title ; dossier title summarised ; an's legislature ; an's dossier id ; senat's dossier id ; line id ; senat's step id ; stage ; chamber ; step ; bill url ; bill id ; date depot text; text date\n" if (shift);
foreach $l (@lines) {
        $idline = sprintf("%02d", $cpt);
	print "$date;$titrelong;$titrecourt;$legislature;$dossieran;$dossiersenat;$idline;$l\n";
	$cpt++;
}

if ($content =~ /Proc\S+dure acc\S+l\S+r\S+e/) {
    if ($content =~ /engag\S+e par le Gouvernement le (\d+) (\w+) (\d+)/) {
	$annee = $3 ; $jour = sprintf('%02d', $1); $mois = $2;
	$mois=~s/[^a-z]//g;
	print "$date;$titrelong;$titrecourt;$legislature;$dossieran;$dossiersenat;XX;EXTRA;URGENCE;Gouvernement;URGENCE;;;$annee-".$mois{$mois}."-$jour;$annee-".$mois{$mois}."-$jour;\n";
    }
}
exit;
