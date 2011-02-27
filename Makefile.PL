use 5.008;
use ExtUtils::MakeMaker;
WriteMakefile
  (
   'NAME'		=> 'optimize',
   'VERSION_FROM'	=> 'lib/optimize.pm',
   'PREREQ_PM'	=>
   {
    'DynaLoader'  => 0,
    'B::Generate' => '1.34'
   },
   AUTHOR        => 'Arthur Bergman',
   ($ExtUtils::MakeMaker::VERSION gt '6.46' ?
    ('META_MERGE'  =>
     {
      resources =>
      {
       license     => 'http://dev.perl.org/licenses/',
       repository  => 'http://github.com/rurban/optimize',
      },
     }
    ) : ()),
  );

sub MY::depend { "README : lib/optimize.pm\n\tpod2text lib/optimize.pm > README\n"; }

