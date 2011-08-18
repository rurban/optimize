use strict;

package optimize;
use Carp; BEGIN { eval { croak "hi\n" }}
use B::Generate;
use B::Utils qw(walkallops_simple);
use B qw(OPf_KIDS OPf_MOD OPf_PARENS OPf_WANT_SCALAR OPf_STACKED);
use Attribute::Handlers;
use B::Hooks::EndOfScope;

our $VERSION = "0.03_03";

our $DEBUG = 0;
our %pads;
our $state;
our $old_op;
our %loaded;
our $stash = '';
our %register;

sub dbgprint { print @_ if $DEBUG; }
use optimizer "extend-c" => sub {
    my $op = shift;
    on_scope_end {$old_op = $op;()};
    return unless $op;
    if ($op->name eq 'nextstate') {
	$state = $op;
	$stash = $state->stash->NAME;
        dbgprint $state->file . ":" . $state->line . "-" . $state->stash->NAME . "\n";
        if ($stash =~/^(optimize|B::|types$|float$|double$|int$|number$|^O$)/) {
            dbgprint "Don't optimize ourself\n";
            return;
        }
    }

    dbgprint ref($op)." - " . $op->name . " - " . ref($op->next) . " - " . 
             ($op->next->can('name') ? $op->next->name : "null") . "\n";
    my $cv;
    eval {
	$cv = $op->find_cv;
    };
    if ($@) {
	$@ =~s/\n//;
	print "$@ in " . $state->file . ":" . $state->line . "\n";;
	return;
    }
    if ($op->name eq 'const' &&
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
	
	if ($attribute =~/^optimize\(\s*(.*)\s*\)/) {
            #dbgprint "attr: $attribute\n";
	    my @attributes = split /\s*,\s*/, $1;
            dbgprint "GOT " . join("-", @attributes) . "\n";
	    my $opnn = $op->next->next;
	    if ($opnn->name eq 'padsv') {
		my $sv = (($cv->PADLIST->ARRAY)[0]->ARRAY)[$opnn->targ];
		my $ref = $pads{$cv->ROOT->seq}->[$opnn->targ] = [$sv->sv(),{}];
		for (@attributes) {
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
        dbgprint "Calling $_\n";
	$_->check($op);
        dbgprint "Called $_\n";
    }
    # calling types
    if (exists($register{$stash})) {
	for my $callback (values %{$register{$stash}}) {
	    if ($callback) {
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
    if ($int == 2) { print "$int is integerized" }

    # Following will call this callback with the op
    # as the argument if you are in the specified package.
    # See L<types> how it is used from import and unimport.
    optimize->register(\&callback, $package);

    # and reverse it
    optimize->unregister($package);

=head1 DESCRIPTION

B<optimize> allows you to use attributes to turn on optimizations.
It works as a framework for different optimizations.

=head1 BUGS

optimize usually rewrites the optree, weird and funky things can happen,
different optimizations will be in a different state of readyness

=head1 AUTHOR

Artur Bergman E<lt>abergman at cpan.orgE<gt>

=head1 SEE ALSO

L<optimize::int> L<B::Generate>

=cut

# Local Variables:
#   mode: cperl
#   cperl-indent-level: 4
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4:
