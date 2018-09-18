use lib './lib';
use DbUtil;
use Operation;
use Setup;

my $db_file = shift;
Setup::export_env();
my $dbh = DbUtil::connectDb($db_file);
Operation::restore($dbh);