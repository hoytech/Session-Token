use strict;

use ExtUtils::MakeMaker;

my $preop =
    'perldoc -uT $(VERSION_FROM) | tee $(DISTVNAME)/README.pod > README.pod;' .
    'pod2text README.pod | tee $(DISTVNAME)/README > README';

my $deps = {};

$deps->{'Crypt::Random::Source::Strong::Win32'} = 0
  if $^O =~ /mswin/i;

WriteMakefile(
    NAME              => 'Session::Token',
    VERSION_FROM      => 'lib/Session/Token.pm',
    PREREQ_PM         => $deps,
    LIBS              => [''],
    DEFINE            => '',
    INC               => '-I.',
    OBJECT            => 'Token.o randport.o',
    dist => {
      PREOP => $preop,
    },
);
