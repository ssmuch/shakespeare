use lib './lib';

use DbUtil;
use Operation;
use Setup;

my $db_file = shift;

die "Please provide the path for the database to be accessed.\n" .
    "Sample: perl $0 db\\test.db\n" if (not defined $db_file);

Setup::export_env();
my $dbh = DbUtil::connectDb($db_file);
Operation::restore($dbh);