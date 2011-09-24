package Test::Mock::LWP::Dispatch;

use strict;
use warnings;

# ABSTRACT: mocks LWP::UserAgent and dispatches your requests/responses

=head1 SYNOPSIS

  # in your *.t
  use Test::Mock::LWP::Dispatch;
  use HTTP::Response;

  # global mappings for requests and responses for LWP::UserAgent
  $mock_ua->map('http://example.com', HTTP::Response->new(...));
  # or
  $mock_ua->map(qr!^http://example.com/page!, sub { my $request = shift;
                                                    # ... create $response
                                                    return $response; });

  # or make local mappings
  my $ua = LWP::UserAgent->new;
  $ua->map(...);

=head1 DESCRIPTION

This module intends for testing a code that heavily uses LWP::UserAgent.

Assume that function you want to test makes three different request to the server
and expects to get some content from the server. To test this function you should
setup request/response mappings for mocked UserAgent and test it.

For doing something with mappings, here are methods C<map>, C<unmap> and C<unmap_all>. For controlling context of these mappings (is it applies for all created in your
code LWP::UserAgent's or only to one specific?) you should call these functions
for exported C<$mock_ua> object (global mapping) or for newly created LWP::UserAgent (local mappings).

See also on L<Test::Mock::LWP>, it provides mocked LWP objects for you, so probably
you can solve your problems with this module too.

=cut

use base qw(Exporter Test::MockObject);

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

=item simple_request($req)

This is only method of LWP::UserAgent that mocked. When you make $ua->get(...)
or $ua->head(...) or just get() from LWP::Simple, at some point calls
C<simple_request()> method. So for controlling responses to your requests it is
only method needed to mock.

In this module C<simple_request()> loops through your local and global mappings
(in this order) and returns response on a first matched mapping. If no matched
C<simple_request()> returns HTTP::Response with 404 code.

Be accurate: method loops through mappings in order of adding these mappings.

=cut

    sub simple_request {
        my $mo = shift;
        my $in_req = shift;

        my $global_maps = $mock_ua->{_maps} || [];
        my $local_maps = $mo->{_maps} || [];
        my $matched_resp = $default_resp;
        foreach my $map (@{$local_maps}, @{$global_maps}) {
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

=item map($req_descr, $resp_descr)

Using this method you can say what response should be on what request.

If you call this method for exported C<$mock_ua> it will make global mappings
applied for all newly created LWP::UserAgent's. If you call this method for
separate LWP::UserAgent you created, then this mapping will work only for
this object.

Request description C<$req_descr> can be:

=over 4

=item string

Uri for exact matching with incoming request uri in C<request()>.

=item regexp

Regexp on what incoming request uri will match.

=item code

You can pass arbitrary coderef, that takes incoming HTTP::Request and returns
true if this request matched.

=item HTTP::Request object

If you pass such object, then request will compare that incoming request
exactly the same that you passed in C<map()> (this means, that all query
parameters, all headers and so on must be identical).

=back

Response description C<$resp_descr>, that will be returned if incoming request
to C<request()> matches with C<$req_descr>, can be:

=over 4

=item HTTP::Response object

Ready to return HTTP::Response object.

=item code

Arbitrary coderef, that takes incoming request as parameter and returns
HTTP::Response object.

=back

Method returns index of your mapping. You can use it in C<unmap>.

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

=item unmap($map_index)

Deletes some mapping by index.

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

Deletes all mappings.

=back

=cut

    sub unmap_all {
        my $mo = shift;
        $mo->{_maps} = [];
        return 1;
    }

    my %mock_methods = (
         simple_request => \&simple_request,
         map            => \&map,
         unmap          => \&unmap,
         unmap_all      => \&unmap_all,
    );

    $mock_ua = Test::MockObject->new();
    $mock_ua->set_isa('LWP::UserAgent');

    $mock_ua->fake_module('LWP::UserAgent', %mock_methods);
    while (my ($method, $handler) = each %mock_methods) {
        $mock_ua->mock($method, $handler);
    }
}

1;

__END__

=head1 MISCELLANEOUS

This mock object doesn't call C<fake_new()>. So when you prepare response using
coderef, you can be sure, that "User-Agent" header will be untouched and so on.

=head1 ACKNOWLEDGEMENTS

Mike Doherty

=head1 SEE ALSO

L<http://github.com/tadam/Test-Mock-LWP-Dispatch>
L<Test::Mock::LWP>
L<LWP::UserAgent>

=cut

