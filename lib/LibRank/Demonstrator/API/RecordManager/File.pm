package LibRank::Demonstrator::API::RecordManager::File;
use Moose;
use namespace::autoclean;

use IO::File;
use JSON;

has 'dir' => (is => 'ro', required => 1);

sub get_record_data {
  my $self = shift;
  my $task = shift;
  my $ids = $task->doc_ids;
  my $sid = $task->sid;

  my $file = sprintf('%s/%s.json', $self->dir, $sid);
  my $fh = IO::File->new($file, '<:utf8');
  my $data = from_json(<$fh>);

  my $res = [];
  foreach my $d (@$data) {
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

__PACKAGE__->meta->make_immutable;
