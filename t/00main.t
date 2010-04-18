#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 39;
use Test::Exception;

BEGIN {
    use_ok('Test::Mock::LWP::Dispatch');
}

use HTTP::Request::Common;
use HTTP::Response;
use LWP::UserAgent;


# test that it is mock object with needed properties (4)
{
    my $ua = LWP::UserAgent->new;
    for (qw/map unmap unmap_all/) {
        ok($ua->can($_), "mocked ua have method $_");
    }
    ok($ua->isa('LWP::UserAgent'), 'check that we mocked LWP::UserAgent');
}

# check input errors (5)
{
    my $ua = LWP::UserAgent->new;
    dies_ok { $ua->map } 'no params';
    dies_ok { $ua->map('a') } 'one param';

    my $resp = HTTP::Response->new(200);

    dies_ok { $ua->map(undef, $resp) } 'only second param';
    dies_ok { $ua->map([], $resp) } 'improper type of first param';
    dies_ok { $ua->map('a', []) } 'improper type of second param';
}

# check various maps (16 = 8*2)
{
    my $treq = HTTP::Request->new('GET', 'http://a.ru');
    my $tresp = HTTP::Response->new(201);
    my $tresp_sub = sub {
        my $req = shift;
        my ($n) = $req->uri =~ /(\d+)$/;
        $n = "0" unless defined($n);
        return HTTP::Response->new("20" . $n);
    };

    my @tests = (
        [ 'http://a.ru', $tresp, 201, 'http://a.ru', 'http://b.ru',
          'check string $req and HTTP::Response $resp' ],
        [ qr/asdf/, $tresp, 201, 'http://asdf.ru', 'http://a.ru',
          'check regexp $req and HTTP::Response $resp' ],
        [ $treq, $tresp, 201, 'http://a.ru', 'http://b.ru',
          'check HTTP::Request $req and HTTP::Response $resp' ],
        [ sub { shift->uri =~ /a/ }, $tresp, 201, 'http://a.ru', 'http://b.ru',
          'check sub $req and HTTP::Response $resp' ],

        [ 'http://a.ru/1', $tresp_sub, 201, 'http://a.ru/1', 'http://b.ru',
          'check string $req and sub $resp' ],
        [ qr/asdf/, $tresp_sub, 202, 'http://asdf.ru/2', 'http://a.ru',
          'check regexp $req and sub $resp' ],
        [ $treq, $tresp_sub, 200, 'http://a.ru', 'http://b.ru',
          'check HTTP::Request $req and sub $resp' ],
        [ sub { shift->uri =~ /a/ }, $tresp_sub, 200, 'http://a.ru/0', 'http://b.ru',
          'check sub $req and sub $resp' ],
    );
    foreach my $test (@tests) {
        my ($req, $resp, $status, $get_url, $bad_url, $test_name) = @{$test};

        my $ua = LWP::UserAgent->new;
        $ua->map($req, $resp);

        my $good_resp = $ua->get($get_url);
        is($good_resp->code, $status, "$test_name, good");

        my $bad_resp = $ua->get($bad_url);
        is($bad_resp->code, '404', "$test_name, bad");
    }
}

# check unmap and unmap_all (6)
{
    my $ua = LWP::UserAgent->new;
    my $index1 = $ua->map('http://a.ru', HTTP::Response->new(200));
    my $index2 = $ua->map('http://b.ru', HTTP::Response->new(201));

    is($ua->get('http://a.ru')->code, 200, 'before unmap');
    is($ua->get('http://b.ru')->code, 201, 'before unmap');

    $ua->unmap($index1);
    is($ua->get('http://a.ru')->code, 404, 'unmap one mapping');
    is($ua->get('http://b.ru')->code, 201, 'unmap one mapping');

    $ua->unmap_all;
    is($ua->get('http://a.ru')->code, 404, 'unmap all');
    is($ua->get('http://b.ru')->code, 404, 'unmap all');
}

{
    is(ref($mock_ua), 'Test::Mock::LWP::Dispatch',
       'check, that $mock_ua exported and have a proper type');
}

# try a global mappings (4)
{
    $mock_ua->map('http://zzz.ru', HTTP::Response->new(400));
    # imitation of real life :-)
    my $f = sub {
        my $ua = LWP::UserAgent->new;
        my $resp = $ua->get('http://zzz.ru');
        return $resp;
    };
    my $resp = $f->();

    is($resp->code, 400, 'check only global mapping');

    my $ua = LWP::UserAgent->new;
    $ua->map('http://abc.ru', HTTP::Response->new(401));
    $resp = $ua->get('http://abc.ru');
    is($resp->code, 401, 'check local mapping works with global');

    $resp = $ua->get('http://zzz.ru');
    is($resp->code, 400, 'check global mapping works with local');

    my $index = $ua->map('http://zzz.ru', HTTP::Response->new(403));
    $resp = $ua->get('http://zzz.ru');
    is($resp->code, 403, 'check local mapping overrides global');

    $ua->unmap($index);
    $resp = $ua->get('http://zzz.ru');
    is($resp->code, 400, 'local unmap in existence of global');

    $mock_ua->unmap_all;
    $resp = $ua->get('http://zzz.ru');
    is($resp->code, 404, 'global unmap_all');
}
