use Session::Token;

## The point of this test is to verify that every byte of the seed is
## propogated to the ISAAC context and therefore impacts the token
## sequence.

use strict;

use Test::More tests => 1;

my $tokens = {};
my $token_count = 0;


foreach my $seed ("\x00" x 1024, "\x00" x 1023 . "\x01", "\x01" . "\x00" x 1023) {
  my $ctx = Session::Token->new( seed => $seed, );

  for my $i (1..2000) {
    $tokens->{$ctx->get} = 1;
    $token_count++;
  }
}

is(scalar keys %$tokens, $token_count, "no uniques");
