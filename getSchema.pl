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
#my @arts = qw/artyz artzp 

my %map = (
   "artyz" => "艳照",
   "artzp" => "自拍",
   "artkt" => "卡通", 
   "artjq" => "激情",
   "artwm" => "唯美",
   "artmt" => "美腿",
   "artyd" => "淫荡",
);

my @arts = keys(%map);

my $dbh  = DbUtil::connectDb();
init_db($dbh);

# check if t_category being initilized
my $category_query = "select F_name from t_category;";
my @result = DbUtil::query($dbh, $category_query);

if (scalar(@result) == 0) {
   init_category(@arts);
}

init_subject($dbh);
exit();

foreach my $art (@arts) {
   my $category_id = get_category_id($art);
   my $url         = $base . '/' . $art;
   my $html        = Utilities::grab_html_by_sque($url . "/");
   my %info        = Utilities::parse_items($html);

   while (my ($link, $name) = each %info) {
      next if $link =~ /(google|baidu|\.xml)/;
      my $now       = time();
      my $subj_name = basename($link);
      my $title     = decode('utf-8',$name);
      my $subj_sql  = 
            "insert into t_subject (F_name, F_url, F_title, F_category_id, F_state, " . 
            "F_created_at, F_updated_at) values ('$subj_name', '$link', '$title', $category_id, 0, $now, $now);";
      
      next if DbUtil::execute($dbh, $subj_sql);

      my @links     = grab_links($base, $link);
      my $subj_id   = get_subj_id($subj_name);

      foreach my $link (@links) {
         $now = time();
         my $img_name = basename($link);
         my $img_sql  = 
               "insert into t_image (F_name, F_url, F_subject_id, F_category_id, F_created_at, " .
               "F_updated_at) values ('$img_name', '$link', $subj_id, $category_id, $now, $now);";

         DbUtil::execute($dbh, $img_sql);
      }
   }
}

DbUtil::closeDb($dbh);

sub init_db {
   my  $dbh = shift;
   my $stmt_cate = qq /
       CREATE TABLE IF NOT EXISTS t_category (
           F_id INTEGER PRIMARY KEY AUTOINCREMENT,
           F_name TEXT UNIQUE, 
           F_title TEXT,
           F_url TEXT, 
           F_state INT,
           F_created_at INT, 
           F_updated_at INT
       );
       /;
   my $stmt_subj = qq /
       CREATE TABLE IF NOT EXISTS t_subject (
           F_id INTEGER PRIMARY KEY AUTOINCREMENT,
           F_name TEXT UNIQUE, 
           F_title TEXT,
           F_url TEXT, 
           F_category_id INT NOT NULL,
           F_state INT,
           F_created_at INT, 
           F_updated_at INT,
           FOREIGN KEY(F_category_id) REFERENCES t_category(F_id)
       );
       /;
   
   my $stmt_img = qq /
       CREATE TABLE IF NOT EXISTS t_image (
           F_id INTEGER PRIMARY KEY AUTOINCREMENT,
           F_name TEXT, 
           F_url TEXT, 
           F_content,
           F_subject_id INT NOT NULL,
           F_category_id INT NOT NULL,
           F_state INT,
           F_created_at INT, 
           F_updated_at INT,
           FOREIGN KEY(F_subject_id) REFERENCES t_subject(F_id),
           FOREIGN KEY(F_category_id) REFERENCES t_category(F_id)
       );
       /;
   
   # Create index
   my $index_img  = "create index if not exists imgIndex on t_image(F_subject_id,F_category_id);";
   my $index_subj = "create index if not exists subIndex on t_subject(F_category_id, F_name);";
   
   my $rv;
   my $flag = 1;
   my @stmts = ($stmt_cate, $stmt_img, $stmt_subj, $index_img, $index_subj);
   
   foreach my $stmt (@stmts) {
       $rv = DbUtil::execute($dbh, $stmt);
   
       if ($rv < 0) {
           $flag = 0;
           print "DB initialization failed\n";
           print $DBI::errstr;
       }
   }
   
   if ($flag) {
         print "Table created successfully\n";
   }
}

sub init_category {
   my @arts = @_;
   foreach my $art (@arts) {
      my $now = time();
      my $init_category_sql = 
            "insert into t_category (F_name, F_url, F_title, F_state, F_created_at, F_updated_at) ".
            "values('$art', '/$art/', '$map{$art}', 0, $now, $now);";

      DbUtil::execute($dbh, $init_category_sql);
   }
}

sub init_subject {
   my $dbh = shift;
   my @arts = DbUtil::query($dbh, "select F_name from t_category;");

   foreach my $art (@arts) {
      my $category_id = get_category_id($art);
      my $url         = $base . '/' . $art;
      my $html        = Utilities::grab_html_by_sque($url . "/");
      my %info        = Utilities::parse_items($html);

      while (my ($link, $name) = each %info) {
         my $subj_name = basename($link);
         next if $link =~ /(google|baidu|\.xml)/ or get_subj_id($subj_name);

         my $now       = time();
         my $title     = decode('utf-8',$name);
         my $subj_sql  = 
            "insert into t_subject (F_name, F_url, F_title, F_category_id, F_state, " . 
            "F_created_at, F_updated_at) values ('$subj_name', '$base$link', '$title', $category_id, 0, $now, $now);";
      
         DbUtil::execute($dbh, $subj_sql);
      }
   }
}

sub get_subj_id {
   my $subj = shift;
   my $sql  = "select F_id from t_subject where F_name='$subj';";

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
   my $content = Utilities::grab_html_href($base . $link);
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