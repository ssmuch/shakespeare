package Operation;
use strict;
use warnings;
use LWP::Simple;
use MIME::Base64;

use lib './lib';

use Utilities;
use DbUtil;

my $BASE = "https://xxgege.net";
my %MAP = (
   "artyz" => "艳照",
   "artzp" => "自拍",
   "artkt" => "卡通", 
   "artjq" => "激情",
   "artwm" => "唯美",
   "artmt" => "美腿",
);

sub init_db {
   my  $dbh = shift;
   my $stmt_cate = qq /
       CREATE TABLE IF NOT EXISTS t_category (
           F_id INTEGER PRIMARY KEY AUTOINCREMENT,
           F_name TEXT UNIQUE, 
           F_title TEXT,
           F_url TEXT, 
           F_state INT DEFAULT 0,
           F_created_at INT, 
           F_updated_at INT
           F_enable INT DEFAULT 0,
       );
       /;
   my $stmt_subj = qq /
       CREATE TABLE IF NOT EXISTS t_subject (
           F_id INTEGER PRIMARY KEY AUTOINCREMENT,
           F_name TEXT UNIQUE, 
           F_title TEXT,
           F_url TEXT, 
           F_category_id INT NOT NULL,
           F_state INT DEFAULT 0,
           F_created_at INT, 
           F_updated_at INT,
           F_enable INT DEFAULT 0,
           FOREIGN KEY(F_category_id) REFERENCES t_category(F_id)
       );
       /;
   
   my $stmt_img = qq /
       CREATE TABLE IF NOT EXISTS t_image (
           F_id INTEGER PRIMARY KEY AUTOINCREMENT,
           F_name TEXT, 
           F_url TEXT, 
           F_content TEXT,
           F_subject_id INT NOT NULL,
           F_category_id INT NOT NULL,
           F_state INT DEFAULT 0,
           F_created_at INT, 
           F_updated_at INT,
           F_enable INT DEFAULT 0,
           FOREIGN KEY(F_subject_id) REFERENCES t_subject(F_id),
           FOREIGN KEY(F_category_id) REFERENCES t_category(F_id)
       );
       /;
   
   my $stmt_download = qq /
       CREATE TABLE IF NOT EXISTS t_download (
           F_id INTEGER PRIMARY KEY AUTOINCREMENT,
           F_image_id INT NOT NULL,
           F_base64 TEXT NOT NULL,
           F_state INT DEFAULT 0,
           F_created_at INT, 
           F_updated_at INT,
           F_enable INT DEFAULT 0,
           FOREIGN KEY(F_image_id) REFERENCES t_image(F_id)
       );
       /;

   # Create index
   my $index_down = "create index if not exists dowIndex on t_download(F_image_id, F_enable);";
   my $index_img  = "create index if not exists imgIndex on t_image(F_subject_id,F_category_id, F_enable);";
   my $index_subj = "create index if not exists subIndex on t_subject(F_category_id, F_name, F_enable);";
   my $index_cate = "create index if not exists catIndex on t_category(F_name, F_enable);";
   
   my $rv;
   my $flag = 1;
   my @stmts = ($stmt_cate, $stmt_img, $stmt_subj, $stmt_download, $index_img, $index_subj, $index_cate, $index_down);
   
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
   my $dbh      = shift;
   my $arts_ref = shift;
   foreach my $art (@{$arts_ref}) {
      my $now = time();
      my $init_category_sql = 
            "insert into t_category (F_name, F_url, F_title, F_state, F_created_at, F_updated_at) ".
            "values('$art', '/$art/', '$MAP{$art}', 0, $now, $now);";

      DbUtil::execute($dbh, $init_category_sql);
   }
}

sub init_subject {
   my $dbh = shift;
   my @arts = DbUtil::query($dbh, "select F_name from t_category;");

   foreach my $art (@arts) {
      my $category_id = get_category_id($dbh, $art);
      my $url         = $BASE . '/' . $art;
      my $html        = Utilities::grab_html_by_sque($url . "/");
      my %info        = Utilities::parse_items($html);

      while (my ($link, $name) = each %info) {
         my $subj_name = basename($link);
         next if $link =~ /(google|baidu|\.xml)/ or get_subj_id($dbh, $subj_name);

         my $now       = time();
         my $title     = decode('utf-8',$name);
         my $subj_sql  = 
            "insert into t_subject (F_name, F_url, F_title, F_category_id, F_state, " . 
            "F_created_at, F_updated_at) values ('$subj_name', '$BASE$link', '$title', $category_id, 0, $now, $now);";
      
         DbUtil::execute($dbh, $subj_sql);
      }
   }
}

sub init_image {
   my $dbh = shift;
   my @arts = DbUtil::query($dbh, "select F_id, F_category_id, F_url from t_subject;");

   foreach my $subj_ref (@arts) {
       my $subj_id     = $subj_ref->[0];
       my $category_id = $subj_ref->[1];
       my @links       = grab_links($subj_ref->[3]);

       foreach my $link (@links) {
           my $now = time();
           my $img_name = basename($link);
           my $img_sql  = 
              "insert into t_image (F_name, F_url, F_subject_id, F_category_id, F_created_at, " .
              "F_updated_at) values ('$img_name', '$link', $subj_id, $category_id, $now, $now);";

           DbUtil::execute($dbh, $img_sql);
       }
   }
}

sub get_subj_id {
   my $dbh  = shift;
   my $subj = shift;
   my $sql  = "select F_id from t_subject where F_name='$subj';";

   my @row = DbUtil::query($dbh, $sql);
   if ((scalar @row) > 0) {
      return $row[0];
   }

   return 0;
}

sub get_category_id {
   my $dbh = shift;
   my $art = shift;
   my $sql = "select F_id from t_category where F_name='$art'";

   my @row = DbUtil::query($dbh, $sql);
   if ((scalar @row) > 0) {
      return $row[0];
   }

   return 0;
}

sub grab_links{
   my $link = shift;
   print "geting html: " . $link ."\n";
   my $content = Utilities::grab_html_href($link);
   my $index   = Utilities::get_last_index($content);

   # Looping to get all the links for the item
   if ($index > 1) {
      for(my $i=2; $i <= $index; ++$i) {
         my $next  = $BASE . $link . "index$i" . ".html";
         $content .= Utilities::grab_html($next);
      }
   }
   
   print "parsing links: " . $link ."\n";
   return Utilities::parse_img_links($content);
}

sub store_img {
    my $dbh = shift;
    my $ref = shift;
    my $image_id = $ref->[0];
    my $content  = get($ref->[1]);

    if (not defined $content) {
        print "Failed to get the image: " . $ref->[1] . "\n";
        return 0;
    }

    my $encoded = encode_base64($content);
    my $now = time();

    my $insert_sql = "insert into t_download (F_image_id, F_base64, F_created_at, F_updated_at) " .
        "values ($image_id, '$encoded', $now, $now);";
    
    DbUtil::execute($dbh, $insert_sql);

    write_disk($image_id, $content)
}

sub write_disk {
    my $name = shift;
    my $content = shift;

    open(FH, '>', "images/$name.jpg");
    binmode(FH);
    print FH $content;
    close FH;
}

1;