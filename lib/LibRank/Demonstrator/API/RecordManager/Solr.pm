package LibRank::Demonstrator::API::RecordManager::Solr;
use Moose;
use namespace::autoclean;

has 'solr' => (is => 'ro', required => 1);

sub get_record_data {
  my $self = shift;
  my $task = shift;
  my $ids = $task->doc_ids;

  my $recs = $self->get_record_metadata($ids);
  my $res = [];
  foreach my $d (@$recs) {
	my $d2 = $task->get_doc($d->{'id'});
	my $x = {
	  metadata => $d,
	  features => $d2->{features},
	  qrel => $d2->{qrel},
	};
	push @$res, $x;
  }
  return $res;
}

sub get_record_metadata {
  my $self = shift;
  my $ids = shift;

  my $p = {
	rows => 200,
	fq => sprintf('id:(%s)',join(' OR ', @$ids)),
	fl => 'id,title,date,source,creator,contributor,type',
  };

  my $rsp = $self->solr->search('*:*', $p);
  return $rsp->content->{response}{docs};
}
__PACKAGE__->meta->make_immutable;
