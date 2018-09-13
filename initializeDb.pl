# Crab imges from site xxgege.net/
# This is a study project, just for fun.
# Date: 2018/1/3
# Last Modified: 2018/1/31
# Author: Kyle Li
use strict;

use lib './lib';
use DbUtil;
use DBI;

my $stmt_cate = qq /
    CREATE TABLE IF NOT EXISTS t_category (
        F_id INTEGER PRIMARY KEY AUTOINCREMENT,
        F_name TEXT, 
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
        F_name TEXT, 
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
my $index_subj = "create index if not exists subIndex on t_subject(F_category_id);";

my $rv;
my $flag = 1;
my @stmts = ($stmt_cate, $stmt_img, $stmt_subj, $index_img, $index_subj);
my $dbh = DbUtil::connectDb();

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

DbUtil::closeDb($dbh);