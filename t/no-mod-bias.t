use Session::Token;

## The point of this test is to verify that we aren't doing anything stupid
## like a naive "mod" over our alphabet which would introduce character bias.
## Set the NON_DETERMINISTIC environment variable to have it run with a
## random seed (will fail every now and again due to pure chance).

use strict;

use Test::More tests => 3;

my $total = 10000;
my $tolerance = 0.005;

my $ctx = Session::Token->new(
            alphabet => 'abc',
            length => $total,
            seed => $ENV{NON_DETERMINISTIC} ? undef : ("\x00" x 1024),
          );

my $token = $ctx->get;

my $counts = {};

$token =~ s/(.)/$counts->{$1}++/eg;


ok(within_tolerance($counts->{a}));
ok(within_tolerance($counts->{b}));
ok(within_tolerance($counts->{c}));


sub within_tolerance {
  my $c = shift;

  return (abs($counts->{a} - ($total / 3)) / $total) < $tolerance;
}
