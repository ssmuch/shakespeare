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
my $image_sql = "select F_id from t_download where F_image_id=";

my @rows = DbUtil::query($dbh, $query_sql);

foreach $row_ref (@rows) {
    $sql = $image_sql . $row_ref->[0] . ";";
    next if scalar(DbUtil::query($dbh, $query_sql)) > 0;
    Operation::fetch_img($dbh, $row_ref);
}