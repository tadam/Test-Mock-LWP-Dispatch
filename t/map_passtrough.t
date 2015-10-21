#!perl
use strict;
use warnings;
use Test::More tests => 3;
use Test::Mock::LWP::Dispatch ();
use FindBin '$Bin';

my $ua = LWP::UserAgent->new;

is($ua->get("file://$Bin")->code, 404, 'before map');

my $index1 = $ua->map_passtrough(qr{^file://});

is($ua->get("file://$Bin")->code, 200, 'after map');

$ua->unmap($index1);
is($ua->get("file://$Bin")->code, 404, 'after unmap');
