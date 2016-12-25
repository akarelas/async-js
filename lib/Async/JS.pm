package Async::JS;

use v5.10;
use warnings;

use Mojo::IOLoop;
use Async::JS::Promise;
use Async::JS::Exception;
use Async::JS::Observable;
eval "use Async::JS::AsyncAwait;";

use Exporter 'import';
our @EXPORT_OK = qw/ setTimeout clearTimeout setInterval clearInterval Promise Observable throw async_sub await /;


sub setTimeout {
	my ($func, $interval) = @_;
	$interval //= 0;
	my $id = Mojo::IOLoop->timer($interval / 1_000, $func);
	return $id;
}

sub clearTimeout {
	my ($id) = @_;
	Mojo::IOLoop->remove($id);
}

sub setInterval {
	my ($func, $interval) = @_;
	my $id = Mojo::IOLoop->recurring($interval / 1_000, $func);
	return $id;
}

sub clearInterval {
	my ($id) = @_;
	Mojo::IOLoop->remove($id);
}

sub Promise { 'Async::JS::Promise' }

sub Observable { 'Async::JS::Observable::Class' }

*throw = \&Async::JS::Exception::throw;


*async_sub = \&Async::JS::AsyncAwait::async_sub;
*await = \&Async::JS::AsyncAwait::await;


1;
