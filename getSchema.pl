use strict;
use warnings;

use lib './lib';
use Data::Dumper;
use Encode;
use File::Basename;

use Utilities;
use DbUtil;

use DBI;
use MIME::Base64;

my $base = "https://xxgege.net";
my @arts = qw/artyz artzp/;

my $dbh  = DbUtil::connectDb();
Operation::init_db($dbh);

# check if t_category being initilized
my $category_query = "select F_name from t_category;";
my @result = DbUtil::query($dbh, $category_query);

if (scalar(@result) == 0) {
   Operation::init_category(@arts);
}

Operation::init_subject($dbh);
Operation::init_image($dbh);

DbUtil::closeDb($dbh);
