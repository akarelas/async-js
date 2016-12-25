use v5.10;
use warnings;

use Test::More tests => 15;
use Test::Warnings;

use Async::JS qw/ setTimeout setInterval clearInterval Promise throw /;
use EV;


Promise->new(sub {
	my ($resolve, $reject) = @_;
	pass 'promise code executes';
});

Promise->new(sub {
	my ($resolve, $reject) = @_;
	$resolve->(100);
})->then(sub {
	my ($n) = @_;
	is $n, 100, 'simple resolve and then';
});

Promise->new(sub {
	my ($resolve, $reject) = @_;
	setTimeout(sub {
		$resolve->(100);
	}, 10);
})->then(sub {
	my ($n) = @_;
	is $n, 100, 'timeout resolve';
});

Promise->new(sub {
	my ($resolve, $reject) = @_;
	setTimeout(sub {
		$resolve->(100);
	}, 10);
})->then(sub {
	my ($n) = @_;
	return $n * 2;
})->then(sub {
	my ($n) = @_;
	is $n, 200, 'chained thens';
});

Promise->new(sub {
	my ($resolve, $reject) = @_;
	setTimeout(sub {
		$resolve->(100);
	}, 10);
})->then(
)->then(sub {
	my ($n) = @_;
	is $n, 100, 'behaves well with missing middle onFulfilled function';
});

Promise->new(sub {
	my ($resolve, $reject) = @_;
	throw 'alex';
})->then()->then(
	undef,
	sub {
		my ($r) = @_;
		is $r, "alex", 'throw in promise produces rejection';
	}
);

Promise->new(sub {
	my ($resolve, $reject) = @_;
	$resolve->(100);
})->then(
	sub {
		my ($val) = @_;
		throw 'john';
	}
)->then(
	undef,
	sub {
		my ($r) = @_;
		is $r, "john", 'throw in then produces rejection';
	}
);

Promise->new(sub {
	my ($resolve, $reject) = @_;
	die 'alex';
})->then()->then(
	undef,
	sub {
		my ($r) = @_;
		like $r, qr/\Aalex at \S+ line \d+\.\s\z/, 'die in promise produces correct reason';
	}
);

Promise->new(sub {
	my ($resolve, $reject) = @_;
	die {a => 1, b => 2};
})->then()->then(
	undef,
	sub {
		my ($r) = @_;
		is_deeply $r, {a => 1, b => 2}, 'die <object> in promise produces correct reason';
	}
);

Promise->new(sub {
	my ($resolve, $reject) = @_;
	my $new_p = Promise->new(sub {
		my ($resolve, $reject) = @_;
		$resolve->(123);
	});
	$resolve->($new_p);
})->then(sub {
	my ($val) = @_;
	is $val, 123, 'promise resolves to promise';
});

Promise->new(sub {
	my ($resolve, $reject) = @_;
	my $new_p = Promise->new(sub {
		my ($resolve, $reject) = @_;
		setTimeout(sub {
			$resolve->(123);
		}, 10);
	});
	$resolve->($new_p);
})->then(sub {
	my ($val) = @_;
	is $val, 123, 'promise resolves to promise async';
});

Promise->new(sub {
	my ($resolve, $reject) = @_;
	$resolve->(100);
})->then(sub {
	my ($val) = @_;
	return Promise->new(sub {
		my ($resolve, $reject) = @_;
		setTimeout(sub {
			$resolve->($val * 2);
		}, 10);
	});
})->then(sub {
	my ($val) = @_;
	is $val, 200, 'then returns promise async';
});

Promise->new(sub {
	my ($resolve, $reject) = @_;
	$reject->('peter');
})->then(
	undef,
	sub {
		my ($reason) = @_;
		is $reason, 'peter', 'a promise may simply reject';
	}
);

Promise->new(sub {
	my ($resolve, $reject) = @_;
	setTimeout(sub {
		$reject->('peter');
	}, 10);
})->then(
	undef,
	sub {
		my ($reason) = @_;
		is $reason, 'peter', 'a promise may simply reject async';
	}
);


EV::run;
