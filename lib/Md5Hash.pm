package Md5Hash;
require Tie::Hash;

use YAML::Tiny;
use File::Slurp qw(read_file write_file);

@ISA = qw(Tie::StdHash);
our $file = 'test.yml';

sub TIEHASH {
   my $self    = shift;
   my $db_file = shift;

   if (not defined $db_file) {
      $db_file = $file;
   }
   else {
      $file = $db_file;
   }

   if (not -e $db_file) {
      # Create file incase does not exist
      write_file($db_file, '');
   }

   my $yaml_ref = YAML::Tiny->read($db_file);

   if (not @$yaml_ref) {
      return bless {}, $self;
   }
   else {
      return bless $yaml_ref->[0], $self;
   }
}

sub STORE {
   my $self = shift;
   my $key  = shift;
   my $val  = shift;

   my $yaml_ref = YAML::Tiny->read($file);
   $yaml_ref->[0]->{$key} = $val;

   $yaml_ref->write($file);
}

sub FETCH {
   my $self = shift;
   my $key  = shift;

   my $yaml_ref = YAML::Tiny->read($file);
   if (exists $yaml_ref->[0]->{$key}) {
      return $yaml_ref->[0]->{$key};
   }
   else {
      return undef;
   }
}

sub DELETE {
   my $self = shift;
   my $key  = shift;

   my $yaml_ref = YAML::Tiny->read($file);
   if (exists $yaml_ref->[0]->{$key}) {
      delete $yaml_ref->[0]->{$key};
      $yaml_ref->write($file);
   }
   else {
      return undef;
   }
}
1;