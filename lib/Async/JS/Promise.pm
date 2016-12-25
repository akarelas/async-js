package Async::JS::Promise;

use v5.10;
use warnings;

use Mojo::Base -base;
use Mojo::IOLoop;

use Async::JS::Exception qw/ throw /;

use Scalar::Util qw/ blessed /;
use Data::Dumper;

my %registry;
my $counter = 'a';

has 'index';
has 'thens' => sub { [] };
has 'state' => 'pending';
has 'value';
has 'reason';

sub new {
	my ($class, $func) = @_;
	my $index = $counter++;

	my $self = $class->SUPER::new(
		index => $index,
	);

	$registry{ $index } = $self;

	eval {
		$func->(
			# resolve
			sub {
				my ($value) = @_;
				$self->_resolve($value);
			},
			# reject
			sub {
				my ($reason) = @_;
				$self->_reject($reason);
			}
		);
	};
	if (my $e = $@) {
		$self->_reject($@);
	}

	return $self;
}

sub new_from_then {
	my ($class) = @_;
	my $index = $counter++;

	my $self = $class->SUPER::new(
		index => $index,
	);

	$registry{ $index } = $self;

	return $self;
}

sub _resolve {
	my ($self, $value) = @_;
	if (blessed($value) and $value->can('then')) {
		$value->then(
			sub {
				my ($new_value) = @_;
				$self->_resolve($new_value);
				return undef;
			},
			sub {
				my ($new_reason) = @_;
				$self->_reject($new_reason);
				return undef;
			},
		);
	}
	else {
		foreach my $then (@{ $self->thens }) {
			Mojo::IOLoop->next_tick(sub {
				my $new_p = $registry{ $then->{index} };
				my $ret = eval { $then->{onFulfilled}->($value) };
				if ($@) {
					$new_p->_reject($@);
				} else {
					$new_p->_resolve($ret);
				}
			});
		}
		$self->state('fulfilled');
		$self->value($value);
		delete $registry{ $self->index };
	}
}

sub _reject {
	my ($self, $reason) = @_;
	my $r = Async::JS::Exception->decode_maybe($reason);
	foreach my $then (@{ $self->thens }) {
		Mojo::IOLoop->next_tick(sub {
			my $new_p = $registry{ $then->{index} };
			my $ret = eval { $then->{onRejected}->($r) };
			if ($@) {
				$new_p->_reject($@);
			} else {
				$new_p->_resolve($ret);
			}
		});
	}
	$self->state('rejected');
	$self->reason($reason);
	delete $registry{ $self->index };
	Mojo::IOLoop->next_tick(sub {
		if (! @{ $self->thens }) {
			warn "Uncaught promise rejection. Reason: ", ref $r ? Dumper($r) : $r;
		}
	});
}

sub then {
	my ($self, $on_fulfilled, $on_rejected) = @_;
	my $new_p = __PACKAGE__->new_from_then;

	my $new_then = {
		onFulfilled => $on_fulfilled,
		onRejected => $on_rejected,
		index => $new_p->index,
	};
	ref $new_then->{onFulfilled} eq 'CODE'	or $new_then->{onFulfilled} = sub { $_[0] };
	ref $new_then->{onRejected} eq 'CODE'	or $new_then->{onRejected} = sub { throw($_[0]) };
	push @{ $self->thens }, $new_then;
	if ($self->state eq 'fulfilled') {
		Mojo::IOLoop->next_tick(sub {
			my $ret = eval { $new_then->{onFulfilled}->($self->value) };
			if (my $e = $@) {
				$new_p->_reject($e);
			} else {
				$new_p->_resolve($ret);
			}
		});
	} elsif ($self->state eq 'rejected') {
		Mojo::IOLoop->next_tick(sub {
			my $reason = Async::JS::Exception->decode_maybe($self->reason);
			my $ret = eval { $new_then->{onRejected}->($reason) };
			if (my $e = $@) {
				$new_p->_reject($e);
			} else {
				$new_p->_resolve($ret);
			}
		});
	}

	return $new_p;
}

sub catch {
	my ($self, $on_rejected) = @_;
	return $self->then(undef, $on_rejected);
}

sub reject {
	my ($class, $reason) = @_;

	return $class->new(sub {
		my ($resolve, $reject) = @_;
		$reject->($reason);
	});
}


1;
