
#use strict;
use Module::Build;


my $build = Module::Build->new
    (
     module_name => 'optimize',
     license => 'unknown',
     dynamic_config => 1,
     requires => 
     { 
	 Hook::Scope => '0.02',
	 'B::Generate' => '1.03',
	 'optimizer'   => '0.02',
	 'perl' => '5.8',
     }
     );
$build->create_build_script();
