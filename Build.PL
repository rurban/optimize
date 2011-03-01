
#use strict;
use Module::Build;


my $build = Module::Build->new
    (
     module_name => 'optimize',
     license => 'unknown',
     dynamic_config => 1,
     requires =>
     {
	 'perl'        => '5.008',
         'Attribute::Handlers' => 0,
	 'B::Generate' => '1.05',
         'B::Utils'    => 0,
	 'Hook::Scope' => '0.02',
	 'optimizer'   => '0.02',
     }
     );
$build->create_build_script();
