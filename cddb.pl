#!/usr/bin/perl
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

use CDDB;
use strict vars;

my %config;

# following variables just need to be declared if different from defaults

$config{CDDB_HOST}="cddb.cddb.com";	# set cddb host
$config{CDDB_PORT}=888;			# set cddb port
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
