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

package CDDB_get;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA = qw(Exporter AutoLoader);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw(
  get_cddb
  get_discids
);
$VERSION = '1.10';

use Fcntl;
use IO::Socket;

# linux magic (from c headers)

my $CDROMREADTOCHDR=0x5305;
my $CDROMREADTOCENTRY=0x5306; 
my $CDROM_MSF=0x02;

# default config

my $CDDB_HOST = "cddb.cddb.com";
my $CDDB_PORT = 888;
my $CD_DEVICE = "/dev/cdrom";

sub read_toc {
  my $device=shift;
  my $tochdr;

  sysopen (CD,$device, O_RDONLY | O_NONBLOCK) or die "cannot open cdrom";
  ioctl(CD, $CDROMREADTOCHDR, $tochdr) or die "cannot read toc";
  my ($start,$end)=unpack "CC",$tochdr;

  my @tracks=();

  for (my $i=$start; $i<=$end;$i++) {
    push @tracks,$i;
  }
  push @tracks,0xAA;

  my @r=();

  foreach my $i (@tracks) {
    my $tocentry=pack "CCC", $i,0,$CDROM_MSF;
    ioctl(CD, $CDROMREADTOCENTRY, $tocentry) or die "cannot read track $i info";
    my ($d,$d,$d,$d,$min,$sec,$frame)=unpack "CCCCCCC", $tocentry;

    my %cdtoc=();
 
    $cdtoc{min}=$min;
    $cdtoc{sec}=$sec;
    $cdtoc{frame}=$frame;
    $cdtoc{frames}=$frame+$sec*75+$min*60*75;

    push @r,\%cdtoc;
  }   
  close(CD);
 
  return @r;
}                                      

sub cddb_sum {
  my $n=shift;
  my $ret=0;

  while ($n > 0) {
    $ret += ($n % 10);
    $n = int $n / 10;
  }
  return $ret;
}                       

sub cddb_discid {
  my $total=shift;
  my $toc=shift;

  my $i=0;
  my $t=0;
  my $n=0;
  
  while ($i < $total) {
    $n = $n + cddb_sum(($toc->[$i]->{min} * 60) + $toc->[$i]->{sec});
    $i++;
  }
  $t = (($toc->[$total]->{min} * 60) + $toc->[$total]->{sec}) -
      (($toc->[0]->{min} * 60) + $toc->[0]->{sec});
  return (($n % 0xff) << 24 | $t << 8 | $total);
}                                       

sub get_discids {
  my $cd=shift;
  $CD_DEVICE = $cd if (defined($cd));

  my @toc=read_toc($CD_DEVICE);
  my $total=$#toc;

  my $id=cddb_discid($total,\@toc);

  return [$id,$total,\@toc];
}

sub get_cddb {
  my $config=shift;
  my $diskid=shift;
  my $id;
  my $toc;
  my $total;

  my $input=$config->{input};

  $CDDB_HOST = $config->{CDDB_HOST} if (defined($config->{CDDB_HOST}));
  $CDDB_PORT = $config->{CDDB_PORT} if (defined($config->{CDDB_PORT}));
  $CD_DEVICE = $config->{CD_DEVICE} if (defined($config->{CD_DEVICE}));

  if(defined($diskid)) {
    $id=$diskid->[0];
    $total=$diskid->[1];
    $toc=$diskid->[2];
  } else {
    my $diskid=get_discids($CD_DEVICE);
    $id=$diskid->[0];
    $total=$diskid->[1];
    $toc=$diskid->[2];
  }

  my $socket=IO::Socket::INET->new(PeerAddr=>$CDDB_HOST, PeerPort=>$CDDB_PORT,
      Proto=>"tcp",Type=>SOCK_STREAM) or die "cannot connect to cddb db: $CDDB_HOST:$CDDB_PORT";

  my $return=<$socket>;
  unless ($return =~ /^2\d\d\s+/) {
    die "not welcome at cddb db";
  }

  print $socket "cddb hello root nowhere.com fastrip 0.77\n";
  $return=<$socket>;
  unless ($return =~ /^2\d\d\s+/) {
    die "handshake error at cddb db: $CDDB_HOST:$CDDB_PORT";
  }

  my $id2= sprintf "%08x", $id;
  print $socket "cddb query $id2 $total";

  for (my $i=0; $i<$total ;$i++) {
    print $socket " $toc->[$i]->{frames}";
  }
  print $socket " ". int(($toc->[$total]->{frames}-$toc->[0]->{frames})/75) ."\n";

  $return=<$socket>;
  my ($err) = $return =~ /^(\d\d\d)\s+/;
  unless ($err =~ /^2/) {
    die "query error at cddb db: $CDDB_HOST:$CDDB_PORT";
  }

  #print "cddb: ret: $return\n";

  my @list=();
  if($err==202) {
    #die "cddb: no match";
    return undef;
  } elsif($err==211) {
    while(<$socket>) {
      last if(/^\./);
      push @list,$_;
    } 
 
    my $n1;
    if($input==1) {
      print "This CD could be:\n\n";
      my $i=1;
      foreach(@list) {
        my ($tit) = $_ =~ /^\S+\s+\S+\s+(.*)/;
        print "$i: $tit\n";
        $i++
      }
      print "\n0: none of the above\n\nChoose: ";
      my $n=<STDIN>;
      $n1=int($n);
    } else {
      $n1=1;
    } 
    if ($n1 == 0) {
      return;
    } else {
      $return="200 ".$list[$n1-1];
    }
  } elsif($err==200) {
    #print "exact\n";
  } else {
    die "cddb: unknown: $return";
  }

  #200 misc 0a01e802 Meredith Brooks / Bitch Single 
  my ($cat,$id,$at) = 
    $return =~ /^\d\d\d\s+(\S+)\s+(\S+)\s+(.*)/;

 
  my $artist;
  my $title;

  if($at =~ /\//) {
    ($artist,$title)= $at =~ /(.*?)\s*\/\s*(.*)/;
  } else {
    $artist=$at;
    $title=$at;
  }

  my %cd={};
  $cd{artist}=$artist;
  chop $title;
  $cd{title}=$title;
  $cd{cat}=$cat;
  $cd{id}=$id;

  #print "cddb: getting: cddb read $cat $id\n";
  print $socket "cddb read $cat $id\n";

  while(<$socket>) {
    last if(/^\./);
    next if(/^\d\d\d/);
    push @{$cd{raw}},$_;
    #TTITLE0=Bitch (Edit) 
    if(/^TTITLE(\d+)\=\s*(.*)/) {
      my $t= $2;
      chop $t;
      $cd{frames}[$1]=$toc->[$1]->{frames};
      unless (defined $cd{track}[$1]) {
        $cd{track}[$1]=$t;
      } else {
        $cd{track}[$1]=$cd{track}[$1].$t;
      }
    } 
  }

  print $socket "quit\n";

  $cd{tno}=$#{@cd{track}}+1;
  $cd{frames}[$cd{tno}]=$toc->[$cd{tno}]->{frames};
  return %cd;
}

1;
__END__
# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

CDDB - Read the CDDB entry for an audio CD in your drive

=head1 SYNOPSIS

 use CDDB;

 my %config;

 # following variables just need to be declared if different from defaults

 $config{CDDB_HOST}="cddb.cddb.com";	# set cddb host
 $config{CDDB_PORT}=888;		# set cddb port
 $config{CD_DEVICE}="/dev/cdrom";	# set cd device

 # user interaction welcome?

 $config{input}=1;   # 1: ask user if more than one possibility
        	    # 0: no user interaction

 # get it on

 my %cd=get_cddb(\%config);

 unless(defined $cd{title}) {
   die "no cddb entry found";
 }

 # do somthing with the results

 print "artist: $cd{artist}\n";
 print "title: $cd{title}\n";
 print "category: $cd{cat}\n";
 print "cddbid: $cd{id}\n";
 print "trackno: $cd{tno}\n";

 my $n=1;
 foreach my $i ( @{$cd{track}} ) {
   print "track $n: $i\n";
   $n++;
 }

=head1 DESCRIPTION

This module/script gets the CDDB info for an audio cd. You need
LINUX, a cdrom drive and an active internet connection in order
to do that.

=head1 LICENSE

This library is released under the same conditions as Perl, that
is, either of the following:

a) the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version.

b) the Artistic License.

If you use this library in a commercial enterprise, you are invited,
but not required, to pay what you feel is a reasonable fee to the
author, who can be contacted at armin@xos.net

=head1 AUTHOR

Armin Obersteiner, armin@xos.net

=head1 SEE ALSO

perl(1), <file:/usr/include/linux/cdrom.h>.

=cut
