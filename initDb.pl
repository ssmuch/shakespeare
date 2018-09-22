use strict;
use warnings;

use lib './lib';

use DbUtil;
use Operation;
use Setup;

Setup::export_env();

my $dbh  = DbUtil::connectDb();

Operation::init_db($dbh);
print "Init tables schema completes\n";

Operation::init_category($dbh);
print "Init t_category table data compeletes\n";

Operation::init_subject($dbh);
print "Init t_subject table data completes\n";

Operation::init_image($dbh);
print "Init t_image table data completes\n";

Operation::init_download($dbh);
print "Init t_image table content completes\n";

DbUtil::closeDb($dbh);
