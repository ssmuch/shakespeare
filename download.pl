use lib './lib';

use Utilities;
use Operation;
use DbUtil;
use Encode;
use Data::Dumper;

#   1. query image_id and link from t_image, 
#   2. get content, 
#   3. base64 encoded, 
#   4. insert into t_download
#   5. store to local?
#
# Notice: control frequency to avoid robot detection

my $dbh  = DbUtil::connectDb();
my $query_sql = "select F_id, F_url from t_image;";

my @rows = DbUtil::query($dbh, $query_sql);

foreach $row_ref (@rows) {
    Operation::write_db($dbh, $row_ref);
}