use Session::Token;

## The point of this test is to test the various alphabet, length, and
## entropy interfaces are behaving according to the design.

use strict;

use Test::More tests => 9;

my $ctx;

## default entropy is 128 bits and default alphabet is length 62
$ctx = Session::Token->new;
is(length($ctx->get), 22);

## can specify length directly
$ctx = Session::Token->new( alphabet => '01', length => 30, );
is(length($ctx->get), 30);
ok($ctx->get =~ /^[01]+$/);

$ctx = Session::Token->new( alphabet => '01', length => 100000, );
is(length($ctx->get), 100000);

$ctx = Session::Token->new( alphabet => '01', entropy => 4, );
is(length($ctx->get), 4);

$ctx = Session::Token->new( alphabet => '01', entropy => 8, );
is(length($ctx->get), 8);

$ctx = Session::Token->new( alphabet => '01', entropy => 8.1, );
is(length($ctx->get), 9);

## alphabet has 1.585 bits of entropy, 10/1.585 = 6.309, round up to 7 chars
$ctx = Session::Token->new( alphabet => '012', entropy => 10, );
is(length($ctx->get), 7);

## alphabet has 4.700 bits of entropy, 256/4.700 = 54.463, round up to 55 chars
##   - also tests passing the alphabet in as an array ref instead of string
$ctx = Session::Token->new( alphabet => ['a' .. 'z'], entropy => 256, );
is(length($ctx->get), 55);
