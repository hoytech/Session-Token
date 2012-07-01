use Session::Token;

## The point of this test is to verify that we aren't doing anything stupid
## like a naive "mod" over our alphabet which would introduce character bias.

=pod

This test isn't so much a unit-test as a simple tool for verifying that
generated values fall within a certain acceptable range of bias. However,
this test is distributed to use the null seed because there is a chance
that some short-term run of random values would trigger a failure (they
are random numbers after all).

Of course, as the total number of values generated increases, we get more
confident that the values generated are unbiased. Because Session::Token
extracts bytes from the PRNG, any bias in our characters will be fairly
pronounced. The most difficult alphabet to detect bias in would be
something like this:

    [ map { chr } (0, 0 .. 254) ]

Note how the 0 is repeated twice.

    P(0)   = 2/256
    P(1)   = 1/256
    ...
    P(254) = 1/256

Algorithms that extract entire words from the PRNG and use these words
in the modulus computation will have more difficult to detect bias.

For further investigation, set the S_T_NON_DETERMINISTIC environment
variable to have it run with a random seed (will fail every now and
again due to pure chance).

The default alphabet, total number of characters to generate, and
tolerance threshold can be controlled with S_T_ALPHABET, S_T_TOTAL,
and S_T_TOLERANCE.

Example: To see this test fail with the example used in L<Session::Token>'s
mod bias example, run the tests with the alphabet set to "aabc":

    $ S_T_ALPHABET=aabc make test
    ...
    t/no-mod-bias.t .... Not within tolerance: a (97): 0.99636 > 0.01 at t/no-mod-bias.t line 95.

=cut



use strict;

use Test::More tests => 1;

my $seed = $ENV{S_T_NON_DETERMINISTIC} ? undef : ("\x00" x 1024),
my $alphabet = $ENV{S_T_ALPHABET} || 'abc',
#my $alphabet = $ENV{S_T_ALPHABET} || (join "", ( map { chr } (255, 0 .. 254) ));
my $total = $ENV{S_T_TOTAL} || 100000;
my $tolerance = $ENV{S_T_TOLERANCE} || 0.01;

my $ideal_per_bucket = $total / length($alphabet);

my $ctx = Session::Token->new(
            alphabet => $alphabet,
            length => $total,
            seed => $seed,
          );

my $token = $ctx->get;

my $counts = {};

$token =~ s/(.)/$counts->{$1}++/seg;

my $total_verification = 0;

foreach my $c (split //, $alphabet) {
  $total_verification += $counts->{$c};
  verify_tolerance($c);
}

is($total_verification, $total, 'no bias detected');

done_testing();



sub verify_tolerance {
  my $c = shift;

  my $deviation = abs(1 - ($counts->{$c} / $ideal_per_bucket));

  my $printable_c = (ord($c) >= 32 && ord($c) <= 126) ? $c : '*unprintable*';

  print "Deviation of $printable_c (" . ord($c) . "): $deviation\n";

  die "Not within tolerance: $printable_c (" . ord($c) . "): $deviation > $tolerance"
    if $deviation > $tolerance;
}
