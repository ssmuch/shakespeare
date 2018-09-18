package Setup;

use strict;
use warnings;

use YAML::Tiny;
use Encode;

my $config = "conf/conf.yml";

sub export_env {
   my $ref  = YAML::Tiny->read($config);
   my $conf = $ref->[0];

   foreach my $key (keys %$conf) {
      $ENV{$key} = encode('utf-8', $conf->{$key});
   }
}

1;