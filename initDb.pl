use strict;
use warnings;

use lib './lib';

use DbUtil;
use Operation;
use Setup;

Setup::export_env();

my $dbh  = DbUtil::connectDb();

Operation::init_db($dbh);

print "Init t_category table starts\n";
Operation::init_category($dbh);

print "Init t_subject table starts\n";
Operation::init_subject($dbh);

print "Init t_image table starts\n";
Operation::init_image($dbh);

print "Init t_download table starts\n";
Operation::init_download($dbh);

DbUtil::closeDb($dbh);
