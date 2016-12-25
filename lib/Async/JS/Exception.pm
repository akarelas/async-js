package Async::JS::Exception;

use v5.10;
use warnings;

use Mojo::Base -base;

use Scalar::Util qw/ blessed /;

use Exporter 'import';
our @EXPORT_OK = qw/ throw /;


has 'error';


sub throw {
	my ($error) = @_;
	my $exception = __PACKAGE__->new(
		error => $error,
	);
	die $exception;
}

sub decode_maybe {
	my ($class, $exception) = @_;
	if (blessed($exception) and $exception->isa('Async::JS::Exception')) {
		return $exception->error;
	} else {
		return $exception;
	}
}


1;
