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

use Utilities;
use DbUtil;

use DBI;
use MIME::Base64;



my $base = "https://xxgege.net";
#my @arts = qw/artyz artzp artkt artjq artkt artwm artmt artyd/;

my %map = (
   "artyz" => "测试",
   "artzp" => "图片",
);
my @arts = keys(%map);

my $dbh  = DbUtil::connectDb();

# check if t_category being initilized
my $category_query = "select * from t_category;";
my @result = DbUtil::query($dbh, $category_query);

if (scalar(@result) == 0) {
   init_category();
}

foreach my $art (@arts) {
   my $category_id = get_category_id($art);
   my $url = $base . '/' . $art;
   my $html = Utilities::grab_html_by_sque($url, 1);
   my %info  = Utilities::parse_items($html);

   while (my ($link, $name) = each %info) {
      next if $link =~ /(google|baidu|\.xml)/;
      my $now       = time();
      my $subj_name = basename($link);
      my $subj_id   = get_subj_id($subj_name);
      my $subj_sql  = 
            "insert into t_subject (F_name, F_url, F_title, F_category_id, F_state, " . 
            "F_created_at, F_updated_at) values ($subj_name, $link, $name, $category_id, 0, $now, $now);";

      DbUtil::execute($dbh, $subj_sql);

      my @links = grab_links($base, $link);

      foreach my $link (@links) {
         $now = time();
         my $img_name = basename($link);
         my $img_sql  = 
               "insert into t_image (F_name, F_url, F_subject_id, F_category_id, F_created_at, " .
               "F_updated_at) values ($img_name, $link, $subj_id, $category_id, $now, $now);";

         DbUtil::execute($dbh, $img_sql);
      }
   }
}

DbUtil::closeDb($dbh);

sub init_category {
   foreach my $art (@arts) {
      my $now = time();
      my $init_category_sql = 
            "insert into t_category (F_name, F_url, F_title, F_state, F_created_at, F_updated_at) ".
            "values('$art', '/$art/', '$map{$art}', 0, $now, $now)";

      DbUtil::execute($dbh, $init_category_sql);
   }
}

sub get_subj_id {
   my $subj = shift;
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

sub grab_links{
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