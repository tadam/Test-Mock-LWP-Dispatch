package Test::Mock::LWP::Dispatch;

use strict;
use warnings;

=head1 NAME

Test::Mock::LWP::Dispatch - mocks LWP::UserAgent and dispatches your requests/responses

=head1 SYNOPSIS

  # in your *.t
  use Test::Mock::LWP::Dispatch;
  use LWP::UserAgent;

=head1 DESCRIPTION

=cut

use base qw(Exporter);

our $VERSION = 0.0.1;
our @EXPORT = qw($mock_ua);
our @EXPORT_OK = @EXPORT;

use Carp qw(croak);
use Data::Dumper;
use HTTP::Request;
use HTTP::Response;
use LWP::UserAgent;
use Test::MockObject;

our $mock_ua;
BEGIN {
    my $default_resp = HTTP::Response->new(404);


=head1 METHODS

=over 4

=item request

=cut

    sub request {
        my $mo = shift;
        my $in_req = shift;

        my $maps = $mo->{_maps} || [];
        my $matched_resp = $default_resp;
        foreach my $map (@{$maps}) {
            next unless (defined($map));
            my ($req, $resp) = @{$map};

            if (ref($req) eq 'HTTP::Request') {
                next unless (Dumper($in_req) eq Dumper($req));
            } elsif (ref($req) eq '') {
               next unless ($in_req->uri eq $req);
            } elsif (ref($req) eq 'Regexp') {
                next unless ($in_req->uri =~ $req);
            } elsif (ref($req) eq 'CODE') {
                next unless ($req->($in_req));
            } else {
                warn "Unknown type of predefined request: " . ref($req);
                next;
            }

            $matched_resp = $resp;
            last;
        }
        if (ref($matched_resp) eq 'HTTP::Response') {
            return $matched_resp;
        } elsif (ref($matched_resp) eq 'CODE') {
            return $matched_resp->($in_req);
        } else {
            warn "Unknown type of predefined response: " . ref($matched_resp);
            return $default_resp;
        }
    }

=item map

=cut

    sub map {
        my $mo = shift;
        my ($req, $resp) = @_;
        if (!defined($req) || !defined($resp)) {
            croak "You should pass 2 arguments in map()";
        }
        if (ref($req) !~ /^(HTTP::Request|Regexp|CODE|)$/) {
            croak "Type of request must be HTTP::Request, regexp, coderef or plain string\n";
        }
        if (ref($resp) !~ /^(HTTP::Response|CODE)$/) {
            croak "Type of response must be HTTP::Response or coderef\n";
        }

        my $map = [$req, $resp];
        push @{$mo->{_maps}}, $map;
        return scalar(@{$mo->{_maps}}) - 1;
    }

=item unmap

=cut

    sub unmap {
        my $mo = shift;
        my $index = shift;
        return if (!defined($index) || $index !~ /^\d+$/);
        unless ($mo->{_maps}) {
            warn "You call unmap() before any call of map()\n";
            return;
        }
        if ($index < 0 || $index > (scalar(@{$mo->{_maps}}) - 1)) {
            warn "Index $index is out of maps range\n";
            return;
        }
        delete $mo->{_maps}->[$index];
        return 1;
    }

=item unmap_all

=back

=cut

    sub unmap_all {
        my $mo = shift;
        $mo->{_maps} = [];
        return 1;
    }

    $mock_ua = Test::MockObject->new;
    $mock_ua->fake_module(
        'LWP::UserAgent',
         request   => \&request,
         map       => \&map,
         unmap     => \&unmap,
         unmap_all => \&unmap_all,
    );
}

1;

__END__

=head1 AUTHORS

Yury Zavarin C<yury.zavarin@gmail.com>.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<http://github.com/tadam/Test-Mock-LWP-Dispatch>
L<Test::Mock::LWP>

=cut

