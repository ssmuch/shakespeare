# Crab imges from site xxgege.net/
# This is a study project, just for fun.
# Date: 2018/1/3
# Last Modified: 2018/1/31
# Author: Kyle Li

use strict;
use warnings;

use lib './lib';
use Data::Dumper;
use Encode;
use File::Basename;

use Md5Hash;
use Utilities;
use DbUtil;

use DBI;
use MIME::Base64;



my $base = "https://xxgege.net";
my @arts = qw/artyz artzp artkt artjq artkt artwm artmt artyd/;

my $dbh  = DbUtil::connectDb();
my $html;
my $link;
my $name;

print(get_category_id("artzp"));
DbUtil::closeDb($dbh);

#   my $url = $base . '/' . $art;
#   $html = Utilities::grab_html_by_sque($url, 1);
#   my %info  = Utilities::parse_items($html);
#
#   while (($link, $name) = each %info) {
#      next if $link =~ /(google|baidu|\.xml)/;
#      my $key = basename($link);
#      $ref->{$art}->{'subj'}{$key} = $name;
#      $ref->{$art}->{'img'}{$name} = join('\n', grabLinks($base, $link));
#
#      last;
#   }

sub init_category {
   foreach my $art (@arts) {
      my $now = time();
      my $init_category_sql = "insert into t_category (F_name, F_url, F_state, F_created_at, F_updated_at) ".
                           "values('$art', '/$art/', 0, $now, $now)";

      DbUtil::execute($dbh, $init_category_sql);
   }
}


sub get_subj_id {
   my $sbuj = shift;
   my $sql  = "select F_id from t_category where F_name='$subj'";

   my @row = DbUtil::query($dbh, $sql);
   if ((scalar @row) > 0) {
      return $row[0];
   }

   return 0;
}

sub get_category_id {
   my $art = shift;
   my $sql = "select F_id from t_category where F_name='$art'";

   my @row = DbUtil::query($dbh, $sql);
   if ((scalar @row) > 0) {
      return $row[0];
   }

   return 0;
}

sub grabLinks{
   my $base = shift;
   my $link = shift;
   print "geting html: " . $link ."\n";
   my $content = Utilities::grab_html($base . $link);
   my $index   = Utilities::get_last_index($content);

   # Looping to get all the links for the item
   if ($index > 1) {
      for(my $i=2; $i <= $index; ++$i) {
         my $next  = $base . $link . "index$i" . ".html";
         $content .= Utilities::grab_html($next);
      }
   }

   
   print "parsing links: " . $link ."\n";
   return Utilities::parse_img_links($content);
}