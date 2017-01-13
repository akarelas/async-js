use v5.10;
use warnings;

BEGIN {
	my $has_coro = eval "use Coro; 1";
	if (! $has_coro) {
		eval "use Test::More skip_all => 'Coro not installed';";
		exit;
	}
}

use Test::More tests => 9;
use Test::Warnings;

use Async::JS qw/ Promise setTimeout async_sub await throw /;

use EV;

my $sleep = sub {
	my ($n) = @_;
	return Promise->new(sub {
		my ($resolve, $reject) = @_;
		setTimeout(sub {
			$resolve->(100);
		}, $n * 1e3);
	});
};

# await promise
my @events_1;
my $async_fn_1 = async_sub {
	my ($array) = @_;
	push @$array, 'start';
	push @$array, await $sleep->(0.01);
	push @$array, 'done';
	return 123;
};
$async_fn_1->(\@events_1);
is_deeply \@events_1, ['start'], 'sleep started ok';
setTimeout(sub {
	is_deeply \@events_1, ['start', 100, 'done'], 'sleep ended ok';
}, 20);

# await async_sub
my @events_2;
async_sub {
	push @events_2, 'started';
	push @events_2, await $async_fn_1->(\@events_2);
	push @events_2, 'done';
}->();
is $events_2[0], 'started', 'await_fn started ok';
is $events_2[2], undef, 'await_fn started ok 2';
setTimeout(sub {
	is_deeply \@events_2, ['started', 'start', 100, 'done', 123, 'done'], 'await_fn ended ok';
}, 20);

# order of execution
my @events_3;
setTimeout(sub {
	push @events_3, 3;
});
async_sub {
	push @events_3, 1;
}->();
push @events_3, 2;
setTimeout(sub {
	is_deeply \@events_3, [1, 2, 3], 'correct order of execution';
}, 10);

# die in async_sub
my @events_4;
async_sub {
	push @events_4, 'start';
	await async_sub {
		push @events_4, 'middle';
		throw 'peter';
	}->();
	push @events_4, 'end';
}->()->then(undef, sub {
	my ($err) = @_;
	push @events_4, $err;
});
setTimeout(sub {
	is_deeply \@events_4, ['start', 'middle', 'peter'], 'die in async_sub';
}, 10);

# await rejection
my @events_5;
async_sub {
	push @events_5, 'start';
	await Promise->reject(123);
	push @events_5, 'end';
}->()->then(undef, sub {
	push @events_5, $_[0];
});
setTimeout(sub {
	is_deeply \@events_5, ['start', 123], 'await rejection';
}, 10);

EV::run;
