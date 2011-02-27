use strict;

package optimize;
use Carp; BEGIN { eval { croak "hi\n" }}
use B::Generate;
use B::Utils qw(walkallops_simple);
use B qw(OPf_KIDS OPf_MOD OPf_PARENS OPf_WANT_SCALAR OPf_STACKED);
use Attribute::Handlers;
use Hook::Scope qw(POST);
our $VERSION = "0.03_01";

our %pads;
our $state;
our $old_op;
our %loaded;
our $stash = '';
our %register;

use optimizer "extend-c" => sub {
    my $op = shift;
    POST(sub{$old_op = $op;()});
    return unless $op;
    if($op->name eq 'nextstate') {
	$state = $op;
	$stash = $state->stash->NAME;
        # print $state->file . ":" . $state->line . "-" . $state->stash->NAME . "\n";

        if($stash =~/^(optimize|B::|types$|float$|double$|int$|number$|^O$)/) {
            #	print "Don't optimize ourself\n";
            return;
        }
    }

    # print "$op - " . $op->name . " - " . $op->next . " - " . ($op->next->can('name') ? $op->next->name : "") . "\n";
    my $cv;
    eval {
	$cv = $op->find_cv;
    };
    if($@) {
	$@ =~s/\n//;
	print "$@ in " . $state->file . ":" . $state->line . "\n";;
	return;
    }
    if($op->name eq 'const' &&
       ref($op->sv) eq 'B::PV' && 
       $op->sv->sv eq 'attributes' &&
       $op->can('next') &&
       $op->next->can('next') &&
       $op->next->next->can('next') &&
       $op->next->next->next->can('next') &&
       $op->next->next->next->next->can('next') &&
       $op->next->next->next->next->next->can('next') &&
       $op->next->next->next->next->next->next &&
       $op->next->next->next->next->next->next->name eq 'method_named' &&
       $op->next->next->next->next->next->next->sv->sv eq 'import')
    {

        # Here we establish that this is an use of attributes on lexicals
        # however we want to establish what attribute it is
	
	my $attribute = $op->next->next->next->next->next->sv->sv;
	
	if($attribute =~/^optimize\(\s*(.*)\s*\)/) {
            # print "$attribute\n";
	    my @attributes = split /\s*,\s*/, $1;
            # print "GOT " . join("-", @attributes) . "\n";

	    if($op->next->next->name eq 'padsv') {
		my $sv = (($cv->PADLIST->ARRAY)[0]->ARRAY)[$op->next->next->targ];
		my $ref = $pads{$cv->ROOT->seq}->[$op->next->next->targ] = [$sv->sv(),{}];
		for(@attributes) {
		    $ref->[1]{$_}++;
		    unless($loaded{$_}) {
			require "optimize/$_.pm";			
			$loaded{$_} = "optimize::$_";
		    }
		}
	    }
	}
    }

    for (values %loaded) {	
        # print "Calling $_\n";
	$_->check($op);
        # print "Called $_\n";
    }
    # calling types
    if(exists($register{$stash})) {
	for my $callback (values %{$register{$stash}}) {
	    if($callback) {
		$callback->($op);
	    }
	}
    }

};

sub register {
    my $class = shift;
    my $callback = shift;
    my $package = shift;
    my ($name) = (caller)[0];
    $register{$package}->{$name} = $callback;
}

sub unregister {
    my $class = shift;
    my $package = shift;
    my ($name) = (caller)[0];
    $register{$package}->{$name} = 0;
}

sub UNIVERSAL::optimize : ATTR {
    ;
}

1;
__END__

=head1 NAME

optimize - Pragma for hinting optimizations on variables

=head1 SYNOPSIS

    use optimize;
    my $int : optimize(int);
    $int = 1.5;
    $int += 1;
    if($int == 2) { print "$int is integerized" }

    #Following will call this callback with the op
    #as the argument if you are in the specified package
    #see types.pm how it is used from import and unimport
    optimize->register(\&callback, $package);

    #and reverse it
    optimize->unregister($package);

=head1 DESCRIPTION

optimize allows you to use attributes to turn on optimizations.
It works as a framework for different optimizations.

=head1 BUGS

optimize usually rewrites the optree, weird and funky things can happen,
different optimizations will be in a different state of readyness

=head1 AUTHOR

Arthur Bergman E<lt>abergman at cpan.orgE<gt>

=head1 SEE ALSO

L<optimize::int> L<B::Generate>

=cut

# Local Variables:
#   mode: cperl
#   cperl-indent-level: 4
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4:
