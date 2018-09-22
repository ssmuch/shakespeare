use lib './lib';

use DbUtil;
use Operation;
use Setup;

my $db_file = shift;
Setup::export_env();

if (not defined $db_file) {
    $db_file = "db/" . $ENV{'DB_NAME'} . ".db";
}
die "Please provide the path for the database to be accessed.\n" .
    "The default db [db/" . $ENV{'DB_NAME'} . ".db] does not exist.\n" .
    "Sample: perl $0 db\\test.db\n" if (not -e $db_file);

my $dbh = DbUtil::connectDb($db_file);
Operation::restore($dbh);
DbUtil::closeDb($dbh);