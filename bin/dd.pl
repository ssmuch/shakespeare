use lib './lib';

use Data::Dumper;
use Encode;
use File::Find;
use File::Slurp qw(read_file write_file);
use YAML::Tiny;

use Md5Hash;
use Utilities;

use utf8;

my $md5_db_file = 'db/md5db.yml';

if (not -e $md5_db_file) {
   # Create file incase does not exist
   write_file($md5_db_file, '');
}
my $yaml_ref = YAML::Tiny->read($md5_db_file);
my %imgdb;

# Perform dedupe while receving terminated sig
# and perform the clean job

$SIG{INT} = sub {
   my %dups = locate_dups($yaml_ref->[0]);
   tie %imgdb,  'Md5Hash', 'db/imgdb.yml';

   foreach (keys %imgdb) {
      my $img = encode('gbk', $imgdb{$_});
      if (not -e $img or exists $dups{$_}) {
         delete $imgdb{$_};
         unlink $img . "*";
      }
   }

   my @dirs = glob "*";
   find(\&wanted, @dirs);
   finddepth(sub{rmdir},'.');

   $yaml_ref->write($md5_db_file);

   print "\n dedupe and clean completed\n";

   exit;
};

sub wanted {
   m/.*\.jpg-.*/i && unlink($_);
   m/.*\.php/i && unlink($_);
   m/.*\.jpg/i && -z && unlink($_);
}

my $file;
my $md5_f;

# Build the md5db
while (1) {
   untie %imgdb;
   tie %imgdb,  'Md5Hash', 'db/imgdb.yml';
   foreach (keys %imgdb) {
      $file  = encode('gbk', $imgdb{$_});

      if (-e $file) {
         $md5_f = Utilities::get_md5_by_file($file);
      }

      if (not exists $yaml_ref->[0]->{$md5_f}) {
         $yaml_ref->[0]->{$_} = $md5_f;
      }
   }
   sleep 60;
}

sub locate_dups {
   my $db_ref = shift;

   my @dups;
   my $dup_ref = {};

   foreach (keys %{$db_ref}) {
      push @{$dup_ref->{$db_ref->{$_}}}, $_;
   }

   foreach (keys %{$dup_ref}) {
      if (scalar @{$dup_ref->{$_}} >= 2) {
         pop @{$dup_ref->{$_}};

         push @dups, @{$dup_ref->{$_}};
      }
   }

   return map {$_ => 1} @dups;
}