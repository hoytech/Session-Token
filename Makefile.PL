use ExtUtils::MakeMaker;

my $preop =
    'perldoc -uT $(VERSION_FROM) | tee $(DISTVNAME)/README.pod > README.pod;' .
    'pod2text README.pod | tee $(DISTVNAME)/README > README';

WriteMakefile(
    NAME              => 'Session::Token',
    VERSION_FROM      => 'lib/Session/Token.pm',
    PREREQ_PM         => {},
    LIBS              => [''],
    DEFINE            => '',
    INC               => '-I.',
    OBJECT            => 'Token.o randport.o',
    dist => {
      PREOP => $preop,
    },
);
