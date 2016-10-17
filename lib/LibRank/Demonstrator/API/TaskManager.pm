package LibRank::Demonstrator::API::TaskManager;
use Moose;
use namespace::autoclean;

has 'tasks' => (is => 'rw', default => sub { {} });
has 'features_idx' => (is => 'ro', lazy => 1, builder => '_build_features_idx');
has 'task_idx' => ( is => 'rw', default => sub { {} });

sub _build_features_idx {
  my $self = shift;


  my $feature_map = {};

  foreach my $t (@{ $self->all_tasks }) {
	my $d = $t->{task}->docs;
	foreach my $doc (@$d) {
	  $feature_map->{$_} = 1 for keys %{$doc->{features}};
	}
  }
  return [ keys %$feature_map ];
}

sub add_tasks {
  my $self = shift;
  my $run = shift;
  my $tasks = shift;


  $self->tasks->{$run} = [ map { { task => $_ } } @$tasks ];
  foreach my $t (@{$self->tasks->{$run}}) {
	my $sid = $t->{task}{sid}; 
	$self->task_idx->{$sid} = $t;
  }
}

sub all_tasks {
  my $self = shift;

  my @tasks;
  foreach my $run (values %{$self->tasks}) {
	push @tasks, @$run;
  }
  return \@tasks;
}

sub tasks_by_run {
  my $self = shift;
  my $run = shift;

  return $self->tasks->{$run};
}

sub get_task {
  my $self = shift;
  my $sid = shift;
  return $self->task_idx->{$sid};
}

use LibRank::Ranker::Util::PDL qw(create_feature_matrix);
sub init {
  my $self = shift;

  my $features_idx = $self->features_idx;

  foreach my $t (@{ $self->all_tasks }) {
	my $d = $t->{task}->docs;
	my $m = create_feature_matrix([ map { $_->{features} } @$d ], $features_idx);
	#warn Dumper($m);
	$t->{feature_matrix} = $m;
  }
}


__PACKAGE__->meta->make_immutable;
