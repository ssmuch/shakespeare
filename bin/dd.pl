use lib './lib';

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
   my %dups = Utilities::locate_dups($yaml_ref->[0]);
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

   exit;
};

sub wanted {
   m/.*\.jpg-.*/i && unlink($_);
   m/.*\.php/i && unlink($_);
   m/.*\.jpg/i && -z && unlink($_);
}

my $file;
my $md5_f;

# Build the md5db every 60 s
while (1) {
   untie %imgdb;
   tie %imgdb,  'Md5Hash', 'db/imgdb.yml';
   my %reversed_db = reverse %{yaml_ref->[0]};

   foreach (keys %imgdb) {
      $file  = encode('gbk', $imgdb{$_});

      next if (exists $reversed_db{$_});

      if (-e $file) {
         $md5_f = Utilities::get_md5_by_file($file);
      }

      if (not exists $yaml_ref->[0]->{$md5_f}) {
         $yaml_ref->[0]->{$_} = $md5_f;
      }
   }
   sleep 60;
}