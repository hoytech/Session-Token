package Session::Token;

use strict;

use Carp qw/croak/;
use POSIX qw/ceil/;


our $VERSION = '0.1';

require XSLoader;
XSLoader::load('Session::Token', $VERSION);


my $default_alphabet = join('', ('0'..'9', 'a'..'z', 'A'..'Z',));
my $default_entropy = 128;


sub new {
  my ($class, %args) = @_;

  my $self = {};
  bless $self, $class;

  ## Init seed

  my $seed;

  if (defined $args{seed}) {
    croak "seed argument should be a 1024 byte long bytestring"
      unless length($args{seed}) == 1024;
     $seed = $args{seed};
  }

  if (!defined $seed) {
    my ($fh, $err1, $err2);

    open($fh, '<', '/dev/urandom') || ($err1 = $!);
    open($fh, '<', '/dev/arandom') || ($err2 = $!)
      unless defined $fh;

    if (!defined $fh) {
      croak "unable to open /dev/urandom ($err1) or /dev/arandom ($err2)";
    }

    sysread($fh, $seed, 1024) == 1024 || croak "unable to read from random device: $!";
  }

  ## Init alphabet

  $self->{alphabet} = defined $args{alphabet} ? $args{alphabet} : $default_alphabet;
  $self->{alphabet} = join('', @{$self->{alphabet}}) if ref $self->{alphabet} eq 'ARRAY';
  croak "alphabet must be between 2 and 256 bytes long" if length($self->{alphabet}) < 2 || length($self->{alphabet}) > 256;

  ## Init token length

  croak "you can't specify both length and entropy"
    if defined $args{length} && defined $args{entropy};

  if (defined $args{length}) {
    croak "bad value for length" unless $args{length} =~ m/^\d+$/ && $args{length} > 0;
    $self->{length} = $args{length};
  } else {
    my $entropy = $args{entropy} || $default_entropy;
    croak "bad value for entropy" unless $entropy > 0;
    my $alphabet_entropy = log(length($self->{alphabet})) / log(2);
    $self->{length} = ceil($entropy / $alphabet_entropy);
  }

  ## Create the ISAAC context
  $self->{ctx} = _get_isaac_context($seed) || die "Bad seed (incorrect length?)";

  return $self;
}


sub get {
  my ($self) = @_;

  my $output = "\x00" x $self->{length};

  _get_token($self->{ctx}, $self->{alphabet}, $output);

  return $output;
}


sub DESTROY {
  my ($self) = @_;

  _destroy_isaac_context($self->{ctx});
}


1;



__END__


=encoding utf-8

=head1 NAME

Session::Token - Secure, efficient, simple random session token generation


=head1 SYNOPSIS

=head2 Simple session token

    my $token = Session::Token->new->get;
    ## 74da9DABOqgoipxqQDdygw

=head2 Keep generator around

    my $token_generator = Session::Token->new;
    my $token = $token_generator->get;
    ## bu4EXqWt5nEeDjTAZcbTKY

=head2 Custom alphabet

    my $token = Session::Token->new(alphabet => 'ACTG', length => 100000)->get;
    ## AGTACTTAGCAATCAGCTGGTTCATGGTTGCCCCCATAG...



=head1 DESCRIPTION

This module provides a secure, efficient, and simple interface for creating session tokens, password reset codes, temporary passwords, random identifiers, and anything else you can think of.

When a Session::Token object is created, 1024 bytes will be read from C</dev/urandom> (Linux, Solaris, most BSDs) or C</dev/arandom> (some BSDs). These bytes will be used to seed the L<ISAAC-32|http://www.burtleburtle.net/bob/rand/isaacafa.html> pseudo random number generator. ISAAC is a cryptographically secure PRNG that improves on the well known L<RC4|http://en.wikipedia.org/wiki/RC4> algorithm in some important areas. Notably, it doesn't have short cycles like RC4 does. A theoretical shortest possible cycle in ISAAC is C<2**40>, although no cycles this short have ever been found (and may not exist at all). On average, ISAAC cycles are a ridiculous C<2**8295>.

Once a context is created, you call the C<get> method on that context and it will return you a new token as a string. After the context is created, no system calls are used to generate tokens. This is one way that C<Session::Token> helps with efficiency, although this is only important for certain use cases (generally not web sessions).

After a context is created, generating a new token will not fail due to a full descriptor table like a routine that opens C</dev/urandom> on every request might. In a server, this is the most important reason you should use the "keep generator around" mode instead of creating Session::Token objects every time you need a token. Programs that don't do this are also difficult to run inside C<chroot>s and are less efficient.

If your application C<fork>s, make sure that the generators are created after the fork (or are re-created), as forking will also duplicate the generator state.

Aside: Some crappy (usually C) programs that assume opening C</dev/urandom> will always succeed have been known to return session tokens based only on the contents of uninitialised memory! Unix really ought to provide a system call for random data instead of just C</dev/urandom>.



=head1 CUSTOM ALPHABETS

Being able to choose exactly which characters appear in your token is very useful. This set of characters is called the alphabet. B<The default alphabet is 62 characters: uppercase letters, lowercase letters, and digits.> For some purposes, this is somewhat of a sweet spot. It is much more compact than hexadecimal encoding which helps with efficiency because session tokens are usually transfered over the network many times during a session. Also, base-62 doesn't use "wacky" characters like base-64 encodings do. These characters sometimes cause encoding/escaping problems (ie when embedded in URLs) and are annoying because often you can't select tokens with double-clicks.

Although the default is base-62, there are all kinds of reasons you might like to use another alphabet. One example is if your users are reading tokens from a print-out or SMS or whatever, you may choose to omit characters like C<o>, C<O>, and C<0> that can easily be confused.

To set a custom alphabet, just pass in either a string or an array of characters to the C<alphabet> parameter of the constructor:

    Session::Token->new(alphabet => '01')->get;
    Session::Token->new(alphabet => ['0', '1'])->get; # same thing
    Session::Token->new(alphabet => ['a'..'z'])->get; # character range



=head1 ENTROPY

There are two ways to specify the length of tokens. The first is directly:

    print Session::Token->new(length => 5)->get;
    ## -> wpLH4

The second way is to specify their minimum entropy in terms of bits:

    print Session::Token->new(entropy => 24)->get;
    ## -> Fo5SX

In the above example, the resulting token is guaranteed to have at least 24 bits of entropy. Since we are using the default base-62 alphabet, and we observe that the token is 5 characters long, we can compute the exact entropy as follows:

    $ perl -E 'say 5 * log(62)/log(2)'
    29.7709815519344

So these tokens have about 29.8 bits of entropy. Note that if we removed one character from this token, it would knock it down to less than our desired 24 bits of entropy:

    $ perl -E 'say 4 * log(62)/log(2)'
    23.8167852415475

B<The default minimum entropy is 128 bits.> Default tokens (that use the default base-62 alphabet) are 22 characters long and therefore have about 131 bits of entropy:

    $ perl -E 'say 22 * log(62)/log(2)'
    130.992318828511



=head1 MOD BIAS

Many token generation libraries, especially ones that implement custom alphabets, make the mistake of generating a random value, computing its modulus over the size of the alphabet, and then using this modulus to index into an alphabet to retrieve an output character.

Why is this bad? Consider the alphabet C<"abc">. This is the ideal output probability distribution which is required for tokens to maintain their specified minimum entropy:

    P(a) = 1/3
    P(b) = 1/3
    P(c) = 1/3

Assume we have a uniform random number source that generates values in the set C<[0,1,2,3]>. If we use the naïve modulus algorithm described above, C<0> maps to C<a>, C<1> maps to C<b>, C<2> maps to C<c>, C<3> I<also maps> to C<a>. So instead of the even distribution above, we have the following biased distribution:

    P(a) = 2/4 = 1/2
    P(b) = 1/4
    P(c) = 1/4

L<Session::Token> eliminates this bias in the above case by only using C<0>, C<1>, and C<2>, and throwing out all C<3>s.

If this interests you, you should also check out the C<t/no-mod-bias.t> test included with Session::Token.

Of course throwing out a portion of our random data is slightly inefficient. Specifically, in the worst case scenario of an alphabet with 129 characters, on average for each output byte we consume C<1.9845> bytes from our random number generator.

The inefficiency described above is actually OK because ISAAC is extremely fast. Depending on compiler/CPU/etc ISAAC uses as little as 18.5 machine instructions (according to Jenkins' site) to generate each ISAAC word, and every ISAAC word gives us four whole bytes.




=head1 INTRODUCING BIAS

If your alphabet contains the same character two or more times, this character will be more biased than any characters that only occur once. You should be very careful that your alphabets don't overlap if you are trying to create random session tokens.

However, if you wish to introduce bias this library doesn't try to stop you. (Maybe it should issue a warning?)

    Session::Token->new(alphabet => '0000001')->get; # don't do this
    ## -> 0000000000010000000110000000000000000000000100

Note that due to a limitation discussed below, alphabets larger than 256 aren't currently supported so your bias can't get very granular.



=head1 ALPHABET SIZE LIMITATION

Due to a limitation in this module's code, alphabets can't be larger than 256 characters. Everywhere the above manual says "characters" it actually means bytes. This isn't a Unicode limitation per se, just the maximum range of code points that can be included in a token. Remember you can easily map bytes to characters with L<tr>.

    use utf8; 
    $z = Session::Token->new(alphabet => '01', length => 10)->get;
    $z =~ tr/01/ λ/;
    ## -> λλ  λλλλ λ

However, to be really useful with higher numbered code points, a "sparse" alphabet data-structure would have to be created. And if you go this route there is no point in hard-coding a limitation on the size of Unicode or some arbitrary machine word. Instead, arbitrary precision "characters" should be supported with L<bigint>. Here's an example of kinda doing that in lisp: L<isaac.lisp|http://hcsw.org/downloads/isaac.lisp>.

This module is not designed to be the ultimate random number generator and at this time I think changing the design as described above would interfere with its goal of being secure, efficient, and simple.




=head1 SEEDING

This module is designed to always seed itself from C</dev/urandom> or C</dev/arandom>. You almost never need to seed it yourself.

However if you know what you're doing, you can pass in a custom seed as a 1024 byte long string. For example, here is how to create a "null seeded" generator:

    my $gen = Session::Token(seed => "\x00" x 1024);

This is done in several places in the test-suite, but obviously don't do this in regular applications because the tokens will always be the same.

One valid reason for seeding is if you have reason to believe that there isn't enough entropy in the kernel's randomness pool and therefore you don't trust C</dev/urandom>. In this case you should acquire your own seed data from somewhere trustworthy (maybe C</dev/random>).

There is currently no way to extract the seed from a Session::Token object.




=head1 BUGS

Windows isn't currently supported. Meh.




=head1 SEE ALSO

L<The Session::Token github repo|https://github.com/hoytech/Session-Token>

There are lots of different modules for generating random data.

There are cryptographic number generators like L<Crypt::URandom>, L<Math::Random::Secure::RNG>, &c, but they usually don't implement alphabets and some of them open C</dev/urandom> for every chunk of random bytes.

L<Data::Token> is the first thing I saw when I looked around on CPAN. It has an inflexible and unspecified (?) alphabet. Also it gets its source of unpredictability from UUIDs and then hashes them with SHA1. I think this is bad design because some UUID standards aren't designed to be unpredictable at all. Ideally knowing a target's MAC address, the rough time the token was issued, &c would not help you predict a reduced area of token-space to concentrate brute force guessing attacks on. I don't know if Data::Token uses these types of UUIDs or the (potentially secure) pure-random types, but because that this wasn't addressed in the documentation and because of an apparent misapplication of hash functions (if you really had a pure-random UUID type, there would be no reason to hash), I don't feel good about using this module.

L<String::Urandom> has alphabets, but it uses the flawed modulus algorithm described above and opens C</dev/urandom> on every token. The docs say "this module was intended to be used as a pseudorandom string generator for less secure applications where response timing may be an issue." I don't know what that means exactly... ?

L<String::Random> is a really cool module with a neat regexp-like language for specifying random tokens (more flexible than alphabets). However, briefly inspecting the code indicates that it uses rand() which I prefer to not use for important tokens. The lack of discussion of bias and security in general made me decide to not use this (otherwise very interesting) module.

L<Data::Random> is also a pretty nice looking library but it seems to use rand() and the docs don't discuss security.




=head1 AUTHOR

Doug Hoyte, C<< <doug@hcsw.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2012 Doug Hoyte.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut




__END__

TODO

* Write a full file descriptor table test

* Make the urandom/arandom checking code more readable/maintainable

* Seed extractor API
