use Session::Token;

## The point of this test is to verify that the kernel seeding interface
## (ie /dev/urandom or Crypt::Random::Source::Strong::Win32) is working
## and gives us a different stream each time. Note that this test is
## technically non-deterministic but a failure is very unlikely.

use strict;

use Test::More tests => 1;

my $tokens = {};
my $token_count = 0;


for (1..2) {
  my $ctx = Session::Token->new;

  for my $i (1..2000) {
    $tokens->{$ctx->get} = 1;
    $token_count++;
  }
}

is(scalar keys %$tokens, $token_count, "no uniques");
