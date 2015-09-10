use strict;

use Benchmark qw(:all);

use String::Random;
use Session::Token;



my $sr = String::Random->new;
$sr->{x} = [ 'A' .. 'F' ];
$sr->{y} = [ 'a' .. 'z' ];
$sr->{z} = [ '0' .. '9' ];



sub token_template {
  my (%m) = @_;

  %m = map { $_ => Session::Token->new(alphabet => $m{$_}, length => 1) }
           keys %m;

  return sub {
    my $v = shift;
    $v =~ s/(.)/exists $m{$1} ? $m{$1}->get : $1/eg;
    return $v;
  };
}

my $st = token_template(
           x => [ 'A' .. 'F' ],
           y => [ 'a' .. 'z' ],
           z => [ '0' .. '9' ],
         );



timethese(500_000, {
  'String::Random' => sub {
    $sr->randpattern('xxyyyzyyzzz');
  },
  'Session::Token' => sub {
    $st->('xxyyyzyyzzz');
  },
});
