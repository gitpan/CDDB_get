#!/usr/bin/perl -I.
#
#  CDDB - Read the CDDB entry for an audio CD in your drive
#
#  This module/script gets the CDDB info for an audio cd. You need
#  LINUX, a cdrom drive and an active internet connection in order
#  to do that.
#
#  (c) 2000 Armin Obersteiner <armin@xos.net>
#
#  LICENSE
#
#  This library is released under the same conditions as Perl, that
#  is, either of the following:
#
#  a) the GNU General Public License as published by the Free
#  Software Foundation; either version 1, or (at your option) any
#  later version.
#
#  b) the Artistic License.
#

use CDDB_get;
use Data::Dumper;

use strict vars;

use Getopt::Std;
my %option = ();
getopts("oghd", \%option);

if($option{h}) {
  print "$0: gets CDDB info of a CD\n";
  print "  no argument - gets CDDB info of CD in your drive\n";
  print "  -o  offline mode - just stores CD info\n";
  print "  -d  output in disc-cover/cdda2wav format\n";
  print "  -g  get CCDB info for stored CDs\n";
  exit;
}

my %config;

my $diskid;
my $total;
my $toc;
my $savedir="/tmp/cddb";

# following variables just need to be declared if different from defaults

$config{CDDB_HOST}="cddb.cddb.com";	# set cddb host
$config{CDDB_PORT}=888;			# set cddb port
$config{CD_DEVICE}="/dev/cdrom";	# set cd device

# user interaction welcome?

$config{input}=1;   # 1: ask user if more than one possibility
                    # 0: no user interaction

if($option{o}) {
  my $ids=get_discids($config{CD_DEVICE});

  unless(-e $savedir) {
    mkdir $savedir,0755 || die "cannot create $savedir";
  }

  open OUT,">$savedir/$ids->[0]\_$$" || die "cannot open outfile";
  print OUT Data::Dumper->Dump($ids,["diskid","total","toc"]);
  close OUT;

  exit;
}

if($option{g}) {
  print STDERR "retrieving stored cds ...\n";

  opendir(DIR, $savedir) || die "cannot opendir $savedir";
  while (defined(my $file = readdir(DIR))) {
    next if($file =~ /^\./);
    print "\n";

    my $in=`/bin/cat $savedir/$file`;
    my $exit  = $? >> 8; 

    if($exit>0) {
      die "error reading file";
    }
    unlink "$savedir/$file";

    eval $in; 

    my %cd=get_cddb(\%config,[$diskid,$total,$toc]);

    unless(defined $cd{title}) {
      print "no cddb entry found: $savedir/$file\n";
    }

    if($option{d}) {
      print_cover(\%cd);
    } else {
      print_cd(\%cd);
    }
  }
  closedir(DIR);
  exit;
}

# get it on

my %cd=get_cddb(\%config);

unless(defined $cd{title}) {
  die "no cddb entry found";
}

# do somthing with the results

if($option{d}) {
  print_cover(\%cd);
} else {
  print_cd(\%cd);
}


exit;



# subroutines

sub print_cd {
  my $cd=shift;

  print "artist: $cd->{artist}\n";
  print "title: $cd->{title}\n";
  print "category: $cd->{cat}\n";
  print "cddbid: $cd->{id}\n";
  print "trackno: $cd->{tno}\n";

  my $n=1;
  foreach my $i ( @{$cd->{track}} ) {
    print "track $n: $i\n";
    $n++;
  }  
}

sub print_cover {
  my $cd=shift;

  print "DISCID=$cd->{id}\n";
  print "DTITLE=$cd->{artist} / $cd->{title}\n";

  my $n=0;
  foreach my $i ( @{$cd->{track}} ) {
    print "TITLE$n=$i\n";
    $n++;
  }
  print "EXTD=\n";
  my $n=0;
  foreach my $i ( @{$cd->{track}} ) {
    print "EXTT$n=\n";
    $n++;
  }
  print "PLAYORDER=\n";
}   
