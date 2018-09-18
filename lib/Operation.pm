package Operation;
use strict;
use warnings;

use LWP::Simple;
use MIME::Base64;
use Data::Dumper;
use File::Fetch;
use File::Basename;
use Encode;

use lib './lib';

use Utilities;
use DbUtil;

use Setup;

my $BASE = "https://xxgege.net";
my %MAP = (
   "artga" => "同性",
   "artjq" => "激情",
   "artkt" => "卡通", 
   "artmt" => "美腿",
   "artmx" => "明星",
   "artsm" => "SM",
   "artwm" => "唯美",
   "artyz" => "艳照",
   "artzp" => "自拍",
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
           F_updated_at INT,
           F_enable INT DEFAULT 0
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
   my $index_img  = "create index if not exists imgIndex on t_image(F_subject_id,F_category_id, F_enable, F_state);";
   my $index_subj = "create index if not exists subIndex on t_subject(F_category_id, F_name, F_enable, F_state);";
   my $index_cate = "create index if not exists catIndex on t_category(F_name, F_enable, F_state);";
   
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
         print "DB initialization completes successfully\n";
   }
}

sub init_category {
   my $dbh  = shift;
   my @arts  = keys %MAP;
   foreach my $art (sort @arts) { 
      my $sql = "select * from t_category where F_name='$art';";
      my @results = DbUtil::query($dbh, $sql);
      next if scalar(@results) > 0;

      my $now = time();
      my $init_category_sql = 
            "insert into t_category (F_name, F_url, F_title, F_state, F_created_at, F_updated_at) ".
            "values('$art', '$BASE/$art/', '$MAP{$art}', 0, $now, $now);"; 
      DbUtil::execute($dbh, $init_category_sql);
   }
}

sub init_subject {
   my $dbh = shift;
   my @arts = DbUtil::query($dbh, "select F_name from t_category where F_state=0;");

   foreach my $art (@arts) {
      my $category_id = get_category_id($dbh, $art);
      print "reaping category: $art - $category_id\n";
      my $url         = $BASE . '/' . $art . '/';
      my $last_index  = Utilities::get_last_index_by_href($url);
      my $html;

      if (defined $ENV{'PAGE_LIMIT'}) {
          $html = Utilities::grab_html_by_sque($url, $ENV{'PAGE_LIMIT'});
      }
      else {
        my $split_num   = 50; 
        my $flag        = int($last_index / $split_num);

        if ($flag > 0) {
            $html  = Utilities::grab_html_by_sque($url, $split_num);

            for(my $i=1; $i <= $flag; $i++) {
                $html .= Utilities::grab_html_by_sque($url . "index" . $i * $split_num . ".html");
            }
        } else {
            $html  = Utilities::grab_html_by_sque($url);
        }
      }

      my %info     = Utilities::parse_items($html);

      while (my ($link, $name) = each %info) {
         print "reaping subject: $BASE$link\n";
         my $subj_name = basename($link);
         next if $link =~ /(google|baidu|\.xml)/ or get_subj_id($dbh, $subj_name);

         my $now       = time();
         my $title     = $name;
         my $subj_sql  = 
            "insert into t_subject (F_name, F_url, F_title, F_category_id, F_state, " . 
            "F_created_at, F_updated_at) values ('$subj_name', '$BASE$link', '$title', $category_id, 0, $now, $now);";
      
         DbUtil::execute($dbh, $subj_sql);
      }

      my $cate_update = "update t_category set F_state=1 where F_id=$category_id;";
      DbUtil::execute($dbh, $cate_update);
   }
}

sub init_image {
   my $dbh = shift;
   my $subj_query = "select F_id, F_category_id, F_url from t_subject where F_state !=1;";
   my @arts = DbUtil::query($dbh, $subj_query);

   foreach my $subj_ref (@arts) {
       my $subj_id     = $subj_ref->[0];
       my $category_id = $subj_ref->[1];
       print "reaping image links: (subj)$subj_id - $category_id\n";

       my @links       = grab_links($subj_ref->[2]);
       foreach my $link (@links) {
           my $now      = time();
           my $img_name = basename($link);
           my $img_url  = "http:" . $link;
           my $img_sql  = 
              "insert into t_image (F_name, F_url, F_subject_id, F_category_id, F_created_at, " .
              "F_updated_at) values ('$img_name', '$img_url', $subj_id, $category_id, $now, $now);";

           DbUtil::execute($dbh, $img_sql);
       }

       my $subj_update = "update t_subject set F_state=1 where F_id=$subj_id;";
       DbUtil::execute($dbh, $subj_update);
   }
}

sub init_download{
    my $dbh       = shift;
    my $query_sql = "select F_id, F_url, F_subject_id from t_image where F_state=0 and ".
                    "F_subject_id not in (select F_id from t_subject where F_enable=2);";
    my @rows      = DbUtil::query($dbh, $query_sql);

    foreach my $row_ref (@rows) {
        print "downloading: " . $row_ref->[1] ."\n";
        fetch_img($dbh, $row_ref);
        sleep(rand(10));
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
   my $content = Utilities::grab_html_href($link);
   my $index   = Utilities::get_last_index($content);

   # Looping to get all the links for the item
   if ($index > 1) {
      for(my $i=2; $i <= $index; ++$i) {
         my $next      = $link . "index$i" . ".html";
         my $html_href = Utilities::grab_html_href($next);

         if (defined $html_href and $html_href ne "") {
             $content .= $html_href;
         }
      }
   }
   
   return Utilities::parse_img_links($content);
}

# not work, use fetch instead
sub write_db {
    my $dbh = shift;
    my $ref = shift;
    my $image_id = $ref->[0];
    my $content  = get("http:" . $ref->[1]);

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

sub fetch_img {
    my $dbh = shift;
    my $ref = shift;
    my $image_id    = $ref->[0];
    my $url         = $ref->[1];
    my $subject_id  = $ref->[2];
    my $ff          = File::Fetch->new(uri => $url);
    my $retry       = 0;
    my $retry_limit = 3;
    my $sql         = "select F_title from t_subject where F_id=$subject_id and F_enable !=2;";
    my @result      = DbUtil::query($dbh, $sql);
    my $to_dir;

    if (scalar @result > 0) {
        $to_dir = "images/" . encode("gbk", decode('utf-8', $result[0])) . "/";
    }
    else {
        print "Skipping\n";
        return;
    }

    if (not -e $to_dir) {
        mkdir($to_dir);
    }

    my $image_file  = $to_dir . basename($ref->[1]);

    print "fetching: $url\n";

FETCH:
    eval {
        $ff->fetch(to => $to_dir);
    };

    if ($@) {
        if ($retry < $retry_limit) {
            $retry ++;
            goto FETCH;
        }
        else {
            print "Failed to retrieve img from: [" . $ref->[1] . "], $@\n";

            $sql = " Update t_subject set F_enable=2 where F_id=$subject_id;";
            DbUtil::execute($dbh, $sql);
        }
    }
    else {
        if ($retry == 3 and not -e $image_file) {
            $sql = " Update t_subject set F_enable=2 where F_id=$subject_id;";
            DbUtil::execute($dbh, $sql);
        }
        return 0 if not -e $image_file;

        open(FH, '<', $image_file) or warn "Failed to open file: $image_file\n";
        binmode(FH);

        my $c;
        while(my $line = <FH>) {
            $c .= $line;
        }
        my $encoded = encode_base64($c);
        close(FH);

        my $now = time();
        my $insert_sql = "insert into t_download (F_image_id, F_base64, F_created_at, F_updated_at) " .
            "values ($image_id, '$encoded', $now, $now);";
        my $update_sql = "update t_image set F_state=1 where F_id=$image_id;";
    
        DbUtil::execute($dbh, $insert_sql);
        DbUtil::execute($dbh, $update_sql);
    }
}

sub restore {
    my $dbh = shift;

    my $sql = "select t_image.f_name, t_subject.f_title, t_download.f_base64 from t_download left join " .
          "t_image on t_download.f_image_id = t_image.f_id left join t_subject on t_image.f_subject_id ".
          "= t_subject.f_id;";

    my @rows = DbUtil::query($dbh, $sql);

    my $image_dir = defined $ENV{'IMAGE_DIR'} ? encode('gbk', decode('utf-8', $ENV{'IMAGE_DIR'})) : "images/";
    mkdir($image_dir) if not -e $image_dir;

    foreach my $row_ref (@rows) {
        my $dir  = $image_dir . "/" . encode('gbk', decode('utf-8', $row_ref->[1]));
        my $file = $dir . "/" . $row_ref->[0];

        if (not -e $dir) {
            mkdir($dir);
        }

        write_file($file, $row_ref->[2]);
    }
}

sub write_file {
    my $file    = shift;
    my $encoded = shift;

    my $content = decode_base64($encoded);

    open(OUT, '>', $file);
    binmode(OUT);
    print OUT $content;
    close OUT;
}

1;