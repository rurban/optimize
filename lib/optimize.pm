
use strict;

package optimize;
use Carp; BEGIN { eval { croak "hi\n" }}
use B::Generate;
use B::Utils qw(walkallops_simple);
use B qw(OPf_KIDS OPf_MOD OPf_PARENS OPf_WANT_SCALAR OPf_STACKED);
use Attribute::Handlers;
use Hook::Scope qw(POST);
our $VERSION = 0.01;

our %pads;
our $state;
our $old_op;
our %loaded;
our $stash;
use optimizer "extend-c" => sub { 
    my $op = shift;
    POST { $old_op = $op };
    if($op->name eq 'nextstate') {
	$state = $op;
	$stash = $state->stash->NAME;
#	print $state->file . ":" . $state->line . "-" . $state->stash->NAME . "\n";;
    }
    if($stash =~/^(optimize|B::)/) {
#	print "Don't optimize ourself\n";
	return;
    }

#    print "$op - " . $op->name . " - " . $op->next . " - " . ($op->next->can('name') ? $op->next->name : "") . "\n";
    my $cv;
    eval {
	$cv = $op->find_cv;
    };
    if($@) {
	$@ =~s/\n//;
#	print "$@ in " . $state->file . ":" . $state->line . "\n";;
	return;
    }

    if($op->name eq 'const' &&
       $op->sv->sv eq 'attributes') {
#	print $op->name . "-" . $op->seq . "\n";
#	my $oop = $op->next;
#	while(1) {
#	    print "$oop - " . $oop->name;
#	    if($oop->can('sv') && $oop->sv) {
#		print " - " . $oop->sv->sv;
#	    }
#	    print "\n";
#	    last if(ref($oop->next) eq 'B::NULL');
#	    $oop = $oop->next;
#	}
##	print $op->next->next->next->next->name ."\n";
    }

    if($op->name eq 'const' &&
       $op->sv->sv eq 'attributes' && 
       $op->can('next') &&
       $op->next->can('next') &&
       $op->next->next->can('next') &&
       $op->next->next->next->can('next') &&
       $op->next->next->next->next->can('next') &&
       $op->next->next->next->next->next->can('next') &&       
       $op->next->next->next->next->next->next->name eq 'method_named' &&
       $op->next->next->next->next->next->next->sv->sv eq 'import') {

	#Here we establish that this is an use of attributes on lexicals
	#however we want to establish what attribute it is

	
	my $attribute = $op->next->next->next->next->next->sv->sv;
	
	if($attribute =~/^optimize\(\s*(.*)\s*\)/) {
#	    print "$attribute\n";
	    my @attributes = split /\s*,\s*/, $1;
#	    print "GOT " . join("-", @attributes) . "\n";

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
#	print "Calling $_\n";
	$_->check($op);
#	print "Called $_\n";
    }


    if($op->name eq 'sassign') {
	my $dst = $state->next->next;
	my $src = $state->next;
	if($dst->name eq 'padsv' && $dst->next->name eq 'sassign') {
	    my $cv = $op->find_cv();
	    if(exists($pads{$cv->ROOT->seq}) && 
	       exists($pads{$cv->ROOT->seq}->[$dst->targ]) &&
	       $pads{$cv->ROOT->seq}->[$dst->targ]->[1]->{tied}
	       ) {
#		print "sassign tied optimization possible\n";


#		return;
		my $n = $op->next;
#		$op->next(0);
		$op->first(0);
		$op->null();
#		$op->dump();

		my $pushmark = B::OP->new("pushmark",2);
		$state->next($pushmark);
		$pushmark->next($dst);
		$pushmark->seq(optimizer::op_seqmax_inc());
		my $tied = B::UNOP->new('tied',38,$dst);
		$tied->seq(optimizer::op_seqmax_inc());
		$pushmark->sibling($tied);
#		$dst->flags(50);
		$dst->next($tied);
		$tied->next($src);
		$tied->sibling($src);
#		$src->flags(34);
		
		my $method_named = B::SVOP->new('method_named',0,"STORE");
		$method_named->seq(optimizer::op_seqmax_inc());
		$src->next($method_named);
		$src->sibling($method_named);


		my $entersub = B::UNOP->new('entersub',69,0);
		$entersub->seq(optimizer::op_seqmax_inc());
		$method_named->next($entersub);
		$entersub->next($n);		
		$entersub->first($pushmark);
		$state->sibling($entersub);

		if($n->flags & OPf_KIDS) {
		    my $no_sibling = 1;
		    for (my $kid = $n->first; $$kid; $kid = $kid->sibling) {
			if($kid->seq == $entersub->seq) {
			    $no_sibling = 0;
			    last;
			}
		    }
		    if($no_sibling) {
			$entersub->sibling($n);
		    }
		} else {
		    $entersub->sibling($n);
		}
#		print $tied->next->name . "\n";
#		print $src->next->name . "\n";
#		print $dst->next->name . "\n";

	    }
	}
    } elsif($op->name eq 'padsv' && !($op->flags & OPf_MOD)) {
	my $cv = $op->find_cv();
	if(exists($pads{$cv->ROOT->seq}) && 
	   exists($pads{$cv->ROOT->seq}->[$op->targ]) &&
	   $pads{$cv->ROOT->seq}->[$op->targ]->[1]->{tied}
	   ) {
#	    print $old_op->seq . " - " . $state->seq . "\n";
#	    $old_op->dump();
#	    $op->dump();
	    my $sibling = $op->sibling();

	    my $pushmark = B::OP->new("pushmark",2);
	    my $n = $op->next();
            $old_op->next($pushmark);
	    $pushmark->seq(optimizer::op_seqmax_inc());
	    $pushmark->next($op);
	    $op->sibling(0);
	    my $tied = B::UNOP->new('tied',38,$op);
	    $pushmark->sibling($tied);
	    $op->next($tied);
	    my $method_named = B::SVOP->new('method_named',OPf_WANT_SCALAR,"FETCH");
	    $tied->sibling($method_named);
#	    $tied->seq(optimizer::op_seqmax_inc());
	    $tied->next($method_named);
	    my $entersub = B::UNOP->new('entersub',OPf_WANT_SCALAR| OPf_PARENS | OPf_STACKED,0);
#	    $method_named->seq(optimizer::op_seqmax_inc());
	    $method_named->next($entersub);
	    $entersub->first($pushmark);
#	    $entersub->seq(optimizer::op_seqmax_inc());
	    $entersub->next($n);
	    $entersub->sibling($sibling);
	    $n->next->first($entersub);
#	    $old_op->sibling($entersub);
	}
    }

};



#CHECK {
#    push @B::Utils::bad_stashes, "optimize",'Attribute::Handlers','B::Generate','attributes','lib','constant','UNIVERSAL';
#    walkallops_simple(\&callback);
#}

#my %pads;
#my $state;


sub UNIVERSAL::optimize : ATTR {
    
}

=head1 NAME

optimize - Pragma for hinting optimizations on variables

=head1 SYNOPSIS

    use optimize;
    my $int : optimize(int);
    $int = 1.5;
    $int += 1;
    if($int == 2) { print "$int is integerized" }

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

1;
