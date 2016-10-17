package LibRank::Demonstrator::API::Services;
use Moose;

use Bread::Board;
use Iterator::Simple qw(list);

extends 'Bread::Board::Container';

has 'config_local' => (is => 'ro', default => './conf/services.pl');

sub BUILD {
  my $self = shift;

  container $self => as {

	service tasks    => './data/tasks.json';
	service features => './data/features.json';
	service rankings => './data/rankings.json';

	container 'ranker' => as {
	  require LibRank::Ranker::TaskRanker::PDL;
	  require LibRank::Ranker::TaskRanker::PP;
	  service 'pOWAv1' => (
		dependencies =>  {
		  'task_manager' => depends_on('../task_manager'),
		  'text_scorer' => depends_on('../text_scorer'),
		},
		block => sub {
		  my $s = shift;
		  my $features_idx = $s->param('task_manager')->features_idx;
		  my $text_scorer = $s->param('text_scorer');

		  require LibRank::Ranker::Model::pOWAv1::PDL;
		  my $model = LibRank::Ranker::Model::pOWAv1::PDL->new( features_idx => $features_idx );
		  my $ranker = LibRank::Ranker::TaskRanker::PDL->new(
			text_scorer => $text_scorer,
			model => $model,
		  );
		  return $ranker;
		}
	  );
	  service 'EconBiz' => (
		dependencies =>  {
		  'text_scorer' => depends_on('../text_scorer'),
		},
		block => sub {
		  my $s = shift;

		  require LibRank::Ranker::Model::EconBiz;
		  my $model = LibRank::Ranker::Model::EconBiz->new( );
		  my $ranker = LibRank::Ranker::TaskRanker::PP->new(
			text_scorer => $s->param('text_scorer'),
			model => $model,
		  );
		  return $ranker;
		}
	  );
	};

	service 'ua' => (
	  block => sub {
		require LWP::UserAgent::Cached;
		my $ua = LWP::UserAgent::Cached->new(cache_dir => '.lwp-cache');
		$ua->nocache_if(sub {
			  my ($response) = @_;
			  return $response->code != 200;
		});
		return $ua;
	  }
	);


	service 'rankers' => (
	  block => sub {
		my $s = shift;
		my $ranker = $s->parent->get_sub_container('ranker');
		
		my %r;
		foreach($ranker->get_service_list()) {
		  $r{$_} = $ranker->resolve(service => $_);
		}
		return \%r;
	  }
	);


	service 'WebService::Solr' => (
	  dependencies => [ 'ua' ],
	  block => sub {
		my $s = shift;
		my $ua = $s->param('ua');

		require WebService::Solr;
		my $solr = WebService::Solr->new(
		  'http://localhost:8983/solr', {
			agent => $ua
		  }
		);
		return $solr;
	  }
	);


	service 'text_scorer' => (
	  dependencies => { 'solr' => 'WebService::Solr' },
	  lifecycle => 'Singleton',
	  block => sub {
		my $s = shift;
		my $solr = $s->param('solr');
		require LibRank::Ranker::TextScorer::Solr;
		my $text_scorer = LibRank::Ranker::TextScorer::Solr
		  ->with_traits('Cached')
		  ->with_traits('PDL')
		  ->new( solr => $solr, custom_params => {
			  defType => 'edismax',
			  lowercaseOperators => 'false',
			  mm => '100%',
			});
		return $text_scorer;
	  }
	);

	service 'task_data' => (
	  block => sub {

		die "Please configure the 'task_data' in your local config (./conf/services.pl).";
		# e.g.:
		# require aliased 'LibRank::Task::JSONReader';
		# my @tasks;
		# my $file = 'data/task_data/run1.json';
		# my $iter = JSONReader->from_file($file);
		# my $tasks = JSONReader->tasks($iter);
		# push @tasks, { run => 1, tasks => $tasks };
		# return \@tasks;
	  }
	);

	service 'task_manager' => (
	  dependencies => [ 'task_data' ],
	  block => sub {
		my $s = shift;

		require LibRank::Demonstrator::API::TaskManager;
		my $tasks = $s->param('task_data');
		my $tm = LibRank::Demonstrator::API::TaskManager->new();

		foreach my $r (@$tasks) {
		  $tm->add_tasks($r->{run}, list($r->{tasks}) );
		}
		# init tasks (e.g. build feature matrices)
		$tm->init();

		return $tm;
	  }
	);

	# Scorer factory. Resolve the service with a task to create a scorer
	# object for this task.
	#	$s->resolve(service => 'scorer', parameters => { task => $task }).
	service 'scorer' => (
	  block => sub {
		my $s = shift;
		require LibRank::Measure::Scorer;
		require LibRank::Measure::nDCG;
		require LibRank::Measure::nERR;
		require LibRank::Measure::Precision;
		my $task = $s->param('task');
		my $docs = $task->docs;
		my $qrel_gradual = { map { $_->{record_id} => $_->{qrel}{gradual} } @$docs };
		my $qrel_binary  = { map { $_->{record_id} => $_->{qrel}{binary} } @$docs };

		my $scorer = LibRank::Measure::Scorer->new();
		$scorer->add('nDCG_10', LibRank::Measure::nDCG->new(
		  k => 10, qrel => $qrel_gradual
		) );
		$scorer->add('nERR_20', LibRank::Measure::nERR->new(
		  k => 20, qrel => $qrel_gradual
		) );
		$scorer->add('Prec_10', LibRank::Measure::Precision->new(
		  k => 10, qrel => $qrel_binary
		) );
		return $scorer;
	  },
	  parameters => [ 'task' ]
	);

	service 'RecordManager::Solr' => (
	  dependencies => { 'solr' => 'WebService::Solr' },
	  class => 'LibRank::Demonstrator::API::RecordManager::Solr'
	);

	alias 'record_manager' => 'RecordManager::Solr';

	# load local service config
	if(-e $self->config_local) {
	  include $self->config_local;
	}
  };

}

__PACKAGE__->meta->make_immutable;
