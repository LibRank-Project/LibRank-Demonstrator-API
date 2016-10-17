package LibRank::Demonstrator::API;
use strict;
use warnings;
use utf8;

use Raisin::API;
use Types::Standard qw(Any Int Str);
use JSON;

api_format 'json';

# setup environment
use aliased 'LibRank::Demonstrator::API::Services';
my $services = Services->new( name => 'app', config_local => 'conf/services.pl' );

my $rankers = $services->resolve(service => 'rankers');
my $text_scorer = $services->resolve( service => 'text_scorer' );
my $task_manager = $services->resolve( service => 'task_manager' );
my $record_manager = $services->resolve( service => 'record_manager' );
foreach my $t ( @{ $task_manager->all_tasks }) {
  my $scorer = $services->resolve( service => 'scorer', parameters => { task => $t->{task} } );
  $t->{scorer} = $scorer;
}
my $solr = $services->resolve(service => 'WebService::Solr');


sub serve_file {
  my $file = shift;
  my $res = shift;

  my $fh = IO::File->new($file, '<:raw');
  # disable automatic JSON serialization
  $res->rendered(1);
  # manually set needed headers
  $res->status(200);
  $res->content_type('application/json; charset=utf-8');
  return $fh;
}

resource tasks => sub {
  get sub {
	my $file = $services->resolve(service => 'tasks');
	return serve_file($file, res());
  };
};

resource features => sub {
  get sub {
	my $file = $services->resolve(service => 'features');
	return serve_file($file, res());
  };
};

resource rankings => sub {
  get sub {
	my $file = $services->resolve(service => 'rankings');
	return serve_file($file, res());
  };
};

# routes

resource rank => sub {
  post sub {
	my $params = from_json(req->raw_body);
	my $run = $params->{run};
	my $normalize_weights = $params->{normalize_weights};
	$normalize_weights = 1 if not defined $normalize_weights;
	my $model = $params->{model} || 'pOWAv1';
	#REFACTOR
	my $w = { qi => { map { $_->{key} => $_->{value} } @{ $params->{weights} } } };
	$w->{w_qi} = delete $w->{qi}{lr_w_qi};
	# set default for missing weight
	$w->{solr}{ps} = 2;
	foreach my $p (@{$params->{solr} }) {
	  my @k = split('/', $p->{key});
	  my $x = $w;
	  my $k = pop @k;
	  foreach(@k) {
		$x->{$_} //= {};
		$x = $x->{$_};
	  }
	  $x->{$k} = $p->{value};
	}

	my $tasks = $task_manager->tasks_by_run($run);
	my $r = $rankers->{$model};
	if($model ne 'EconBiz') {
	  $r->model->normalize_weights($normalize_weights);
	  $r->set_weights($w);
	} else {
	  $r->text_scorer->reset_weights();
	}

	# stream results to reduce latency
	# Note: the response is a single JSON array (i.e. instead of
	#       one JSON object per line) due to browser limitations.
	return sub {
		my $respond = shift;
		my $w = $respond->([200, [ 'Content-Type' => 'application/json']]);
		$w->write('[');

        my $i=@$tasks;
		foreach my $t (@$tasks) {
		  my $task = $t->{task};
		  my $sid = $task->{sid};

		  my $scorer = $t->{scorer};

		  my $docs = $r->rank_task($t);
		  my @docs = @$docs;

		  my $rl = [ map { $_->{record_id} } @docs ];
		  my $s = $scorer->score($rl);

		  my $data = { ranked_list => \@docs, score => $s };

		  $w->write(to_json({ task => $sid, res => $data}));
		  $i -= 1;
		  if($i>0) { $w->write(','); }
		}
		$w->write(']');
		$w->close();
	};
  };
};


resource task => sub {
  params required => { name => 'sid', type => Int, desc => 'SearchTask ID' };
  route_param 'sid' => sub {

	resource records => sub {
	  get sub {
		my $params = shift;
		my $sid = $params->{sid};

		my $task = $task_manager->get_task($sid)->{task};
		return $record_manager->get_record_data($task);
	  };
	};
  };
};

run;
