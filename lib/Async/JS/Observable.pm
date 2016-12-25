package Async::JS::Observable;

use v5.10;
use warnings;

use Mojo::Base -base;

has 'func';

sub new {
	my ($class, $func) = @_;
	return $class->SUPER::new(
		func => $func,
	);
}

sub subscribe {
	my ($self, $next, $error, $complete) = @_;
	my $observer = Async::JS::Observable::Observer->new(
		_next => $next // sub {},
		_error => $error // sub {},
		_complete => $complete // sub {},
	);

	return $self->func->($observer);
}

sub map {
	my ($self, $transformation) = @_;
	return __PACKAGE__->new(sub {
		my ($observer) = @_;
		$self->subscribe(
			sub {
				my ($data) = @_;
				$observer->next( $transformation->($data) );
			},
			sub {
				my ($error) = @_;
				$observer->error($error);
			},
			sub () {
				$observer->complete;
			},
		);
	});
}

sub merge_map {
	my ($self, $generator) = @_;
	return __PACKAGE__->new(sub {
		my ($observer) = @_;
		$self->subscribe(
			sub {
				my ($data) = @_;
				$generator->($data)->subscribe(
					sub {
						my ($data) = @_;
						$observer->next($data);
					},
					sub {
						my ($error) = @_;
						$observer->error($error);
					},
					sub {
						$observer->complete;
					}
				);
			},
			sub {
				my ($error) = @_;
				$observer->error($error);
			},
			sub {
				$observer->complete;
			}
		);
	});
}


package Async::JS::Observable::Class;

use v5.10;
use warnings;

sub Observable { 'Async::JS::Observable' }

sub new {
	my ($class, $func) = @_;
	return Observable->new($func);
}

sub from_event {
	my ($class, $element, $event) = @_;
	return Observable->new(sub {
		my ($observer) = @_;
		my $cb = sub {
			my @params = @_;
			$observer->next(\@params);
		};
		$element->on($event, $cb);

		return sub {
			$element->unsubscribe($event, $cb);
		};
	});
}

sub from_array {
	my ($class, $array) = @_;
	return Observable->new(sub {
		my ($observer) = @_;
		foreach my $item (@$array) {
			$observer->next($item);
		}
		$observer->complete;
	});
}


package Async::JS::Observable::Observer;

use v5.10;
use warnings;

use Mojo::Base -base;

has '_next';
has '_error';
has '_complete';

sub next {
	my ($self, $data) = @_;
	$self->_next->($data);
}

sub error {
	my ($self, $error) = @_;
	$self->_error->($error);
}

sub complete {
	my ($self) = @_;
	$self->_complete->();
}


1;
